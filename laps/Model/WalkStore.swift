import Foundation
import Observation

/// Owns all of Richard's records. Every change is written to disk immediately.
@MainActor
@Observable
final class WalkStore {
    private(set) var data: AppData
    /// Set when the saved file couldn't be read, so nothing gets silently overwritten.
    private(set) var loadProblem: String?
    /// Set when an activity reminder is tapped, so the app opens on Activities. Not saved.
    var openActivities = false

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let scheduler: ReminderScheduling?

    init(fileURL: URL = WalkStore.defaultFileURL,
         calendar: Calendar = .current,
         scheduler: ReminderScheduling? = nil,
         now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.calendar = calendar
        self.scheduler = scheduler
        self.now = now
        self.data = AppData()

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let raw = try Data(contentsOf: fileURL)
                data = try JSONDecoder.walks.decode(AppData.self, from: raw)
            } catch {
                // Keep a copy of the unreadable file rather than overwriting it.
                let backup = fileURL.deletingPathExtension()
                    .appendingPathExtension("unreadable-\(Int(now().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: fileURL, to: backup)
                loadProblem = error.localizedDescription
            }
        }
        closeStaleSession()
    }

    nonisolated static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("walks.json")
    }

    private var dayKey: DayKey { DayKey(calendar: calendar) }
    var todayKey: String { dayKey.key(for: now()) }

    // MARK: - Reading

    func record(for key: String) -> DayRecord { data.days[key] ?? DayRecord(day: key) }
    var today: DayRecord { record(for: todayKey) }
    var lapsToday: Int { today.lapCount }
    var carWalksToday: Int { today.carWalks }
    var walkingCreditsToday: Int { today.walkingCredits }
    var active: ActiveSession? { data.active }
    var settings: Settings { data.settings }
    var remindersPausedToday: Bool { data.settings.remindersPausedOn == todayKey }

    var pendingLater: Date? {
        guard let d = data.settings.snoozeUntil, d > now() else { return nil }
        return d
    }

    /// Lap totals for the last 7 days including today, oldest first. Read from saved records.
    func lastSevenDays() -> [WeekDay] {
        dayKey.lastDays(7, endingAt: now()).map { key in
            let r = record(for: key)
            return WeekDay(key: key, date: dayKey.date(for: key) ?? now(), laps: r.lapCount, carWalks: r.carWalks,
                           standing: r.standingCredits, lotions: r.lotions)
        }
    }

    /// Every day with something recorded, newest first.
    var recordedDays: [DayRecord] {
        data.days.values
            .filter(\.hasAnything)
            .sorted { $0.day > $1.day }
    }

    func date(forKey key: String) -> Date? { dayKey.date(for: key) }

    // MARK: - Laps and sessions

    /// Records one lap and starts or resumes a session. Returns the new total for today.
    @discardableResult
    func recordLap() -> Int {
        closeStaleSession()
        let t = now(), key = todayKey
        mutateDay(key) { $0.laps.append(LapEntry(time: t)) }

        if data.active == nil {
            data.active = ActiveSession(day: key, start: t)
        }
        data.active?.state = .walking
        data.active?.lapCount += 1
        data.settings.snoozeUntil = nil
        save()
        return lapsToday
    }

    /// Removes today's most recent lap. Never goes below zero.
    func undoLastLap() {
        let key = todayKey
        guard !record(for: key).laps.isEmpty else { return }
        mutateDay(key) { day in
            if let last = day.laps.indices.max(by: { day.laps[$0].time < day.laps[$1].time }) {
                day.laps.remove(at: last)
            }
        }
        if let a = data.active, a.lapCount > 0 { data.active?.lapCount = a.lapCount - 1 }
        save()
    }

    func startSession() {
        closeStaleSession()
        if data.active == nil {
            data.active = ActiveSession(day: todayKey, start: now())
        }
        data.active?.state = .walking
        data.settings.snoozeUntil = nil
        save()
    }

    /// Ends the session. All laps stay recorded; he can start another later.
    func finishForNow() {
        endActiveSession(at: now())
        save()
    }

    // MARK: - Reminders

    func remindMeLater() {
        data.settings.snoozeUntil = now().addingTimeInterval(TimeInterval(ReminderPlanner.laterMinutes * 60))
        if data.settings.remindersPausedOn == todayKey { data.settings.remindersPausedOn = nil }
        save()
    }

    func cancelRemindLater() {
        data.settings.snoozeUntil = nil
        save()
    }

    func setRemindersPausedToday(_ paused: Bool) {
        data.settings.remindersPausedOn = paused ? todayKey : nil
        if paused { data.settings.snoozeUntil = nil }
        save()
    }

    func updateReminders(_ reminders: [ReminderTime]) {
        data.settings.reminders = reminders
        save()
    }

    func setSound(_ on: Bool) {
        data.settings.soundOn = on
        save()
    }

    func currentPlan() -> [PlannedReminder] {
        ReminderPlanner.plan(now: now(), calendar: calendar, settings: data.settings, creditsToday: walkingCreditsToday,
                             lotionDoneToday: lotionDoneToday, standUpsQuietUntil: standUpsQuietUntil)
    }

    /// While he's walking, hold stand-ups until 45 minutes after his latest lap.
    var standUpsQuietUntil: Date? {
        guard let a = data.active else { return nil }
        let lastLap = record(for: a.day).laps.map(\.time).max() ?? a.start
        return max(lastLap, a.start).addingTimeInterval(45 * 60)
    }

    func refreshReminders() {
        scheduler?.apply(currentPlan())
    }

    // MARK: - Stand-ups

    var standUpsDoneToday: Int { today.standUpsDone }
    var standingCreditsToday: Int { today.standingCredits }
    var standingGoal: Int { data.settings.standUp.goal }
    var lotionDoneToday: Bool { today.lotionDoneAt != nil }
    var standUpsPausedToday: Bool { data.settings.standUp.pausedOn == todayKey }

    /// Records one activity with a single tap and returns the entry, so it can be undone.
    /// There's no minimum gap: it's the honor system. A checkable one already done today is
    /// left as it is (returns nil), so a double tap never counts it twice.
    @discardableResult
    func record(_ activity: Activity) -> StandUpEntry? {
        if activity.isCheckable && isDone(activity) { return nil }
        let t = now()
        let entry = StandUpEntry(picked: t, choiceID: activity.id, title: activity.title, doneAt: t)
        mutateDay(todayKey) { day in
            if activity.id == Activities.morningLotion.id { day.lotionDoneAt = t }
            day.standUps.append(entry)
        }
        save()
        return entry
    }

    /// Takes back a recorded activity (from Undo or Completed today).
    func undo(_ entry: StandUpEntry) {
        mutateDay(todayKey) { day in
            day.standUps.removeAll { $0.id == entry.id }
            if entry.choiceID == Activities.morningLotion.id { day.lotionDoneAt = nil }
        }
        save()
    }

    func count(_ activity: Activity) -> Int { today.count(activity.id) }
    func isDone(_ activity: Activity) -> Bool { count(activity) > 0 }

    /// Daily activities to show in amber: the morning face wash from noon, and once the goal
    /// is reached, the exercises still to do. Extra accomplishments never turn amber.
    func needsAttention(_ activity: Activity) -> Bool {
        guard activity.kind == .daily, !isDone(activity) else { return false }
        if activity.id == Activities.morningLotion.id {
            return calendar.component(.hour, from: now()) >= Activities.morningDeadlineHour
        }
        return activity.amberAtGoal && standingCreditsToday >= standingGoal
    }

    /// Everything recorded today, newest first, for Completed today.
    var completedToday: [StandUpEntry] {
        var list = today.standUps.filter { $0.doneAt != nil }
        // Face washes ticked before one-tap recording only have the date.
        if let t = today.lotionDoneAt, !list.contains(where: { $0.choiceID == Activities.morningLotion.id }) {
            list.append(StandUpEntry(picked: t, choiceID: Activities.morningLotion.id,
                                     title: Activities.morningLotion.title, doneAt: t))
        }
        return list.sorted { ($0.doneAt ?? $0.picked) > ($1.doneAt ?? $1.picked) }
    }

    func setStandingGoal(_ goal: Int) {
        data.settings.standUp.goal = min(StandUpSettings.goalRange.upperBound, max(StandUpSettings.goalRange.lowerBound, goal))
        save()
    }

    func deleteStandUp(_ id: UUID, on key: String) {
        mutateDay(key) { day in
            if let e = day.standUps.first(where: { $0.id == id }), e.choiceID == Activities.morningLotion.id {
                day.lotionDoneAt = nil
            }
            day.standUps.removeAll { $0.id == id }
        }
        save()
    }

    func updateStandUpSettings(_ settings: StandUpSettings) {
        data.settings.standUp = settings
        save()
    }

    func setStandUpsPausedToday(_ paused: Bool) {
        data.settings.standUp.pausedOn = paused ? todayKey : nil
        save()
    }

    // MARK: - Everyday walking

    /// Saves an everyday note for today and returns it (so it can be undone), or nil if blank.
    @discardableResult
    func addEveryday(_ note: String) -> EverydayEntry? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let entry = EverydayEntry(time: now(), note: trimmed)
        mutateDay(todayKey) { $0.everyday.append(entry) }
        save()
        return entry
    }

    func deleteEveryday(_ id: UUID, on key: String) {
        mutateDay(key) { $0.everyday.removeAll { $0.id == id } }
        save()
    }

    // MARK: - Corrections

    /// Adds a forgotten lap to any day (today uses the current time, past days use noon).
    func addLap(on key: String) {
        if key == todayKey {
            recordLap()
            return
        }
        guard let start = dayKey.date(for: key),
              let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start) else { return }
        mutateDay(key) { $0.laps.append(LapEntry(time: noon)) }
        save()
    }

    func deleteLap(_ id: UUID, on key: String) {
        mutateDay(key) { $0.laps.removeAll { $0.id == id } }
        if key == todayKey, let a = data.active, a.lapCount > 0 { data.active?.lapCount = a.lapCount - 1 }
        save()
    }

    // MARK: - Day changes

    /// If a session was left open from an earlier day, close it into that day.
    func closeStaleSession() {
        guard let a = data.active, a.day != todayKey else { return }
        let lastLap = record(for: a.day).laps.map(\.time).max() ?? a.start
        endActiveSession(at: lastLap)
        save()
    }

    // MARK: - Private

    private func endActiveSession(at end: Date) {
        guard let a = data.active else { return }
        let session = WalkSession(id: a.id, start: a.start, end: max(end, a.start),
                                  lapCount: a.lapCount, breaks: a.breaks)
        mutateDay(a.day) { $0.sessions.append(session) }
        data.active = nil
    }

    private func mutateDay(_ key: String, _ change: (inout DayRecord) -> Void) {
        var day = data.days[key] ?? DayRecord(day: key)
        change(&day)
        data.days[key] = day
    }

    private func save() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let raw = try JSONEncoder.walks.encode(data)
            try raw.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("laps: failed to save – \(error)")
        }
        refreshReminders()
    }
}

extension JSONEncoder {
    static var walks: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var walks: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
