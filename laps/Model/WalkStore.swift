import Foundation
import Observation

/// Owns all of Richard's records. Every change is written to disk immediately.
@MainActor
@Observable
final class WalkStore {
    private(set) var data: AppData
    /// Set when the saved file couldn't be read, so nothing gets silently overwritten.
    private(set) var loadProblem: String?
    /// Stand-up choices waiting to be shown (from a notification tap or "Stand up now"). Not saved.
    var standUpPrompt: [StandUpChoice]?

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
    var active: ActiveSession? { data.active }
    var settings: Settings { data.settings }
    var remindersPausedToday: Bool { data.settings.remindersPausedOn == todayKey }

    var pendingLater: Date? {
        guard let d = data.settings.snoozeUntil, d > now() else { return nil }
        return d
    }

    /// Lap totals for the last 7 days including today, oldest first. Read from saved records.
    func lastSevenDays() -> [(key: String, date: Date, laps: Int)] {
        dayKey.lastDays(7, endingAt: now()).map { key in
            (key, dayKey.date(for: key) ?? now(), record(for: key).lapCount)
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
        data.settings.breakReminderAt = nil
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
        data.settings.breakReminderAt = nil
        data.settings.snoozeUntil = nil
        save()
    }

    /// Pauses the session, keeps every lap, and asks for a nudge in 10 minutes.
    func takeBathroomBreak() {
        if data.active == nil { data.active = ActiveSession(day: todayKey, start: now()) }
        data.active?.state = .onBreak
        data.active?.breaks += 1
        data.settings.snoozeUntil = nil
        data.settings.breakReminderAt = now().addingTimeInterval(TimeInterval(ReminderPlanner.breakMinutes * 60))
        save()
    }

    func resumeWalking() {
        data.active?.state = .walking
        data.settings.breakReminderAt = nil
        save()
    }

    /// Ends the session. All laps stay recorded; he can start another later.
    func finishForNow() {
        endActiveSession(at: now())
        data.settings.breakReminderAt = nil
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
        if paused {
            data.settings.snoozeUntil = nil
            data.settings.breakReminderAt = nil
        }
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
        ReminderPlanner.plan(now: now(), calendar: calendar, settings: data.settings, lapsToday: lapsToday,
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
    var lotionDoneToday: Bool { today.lotionDoneAt != nil }
    var standUpsPausedToday: Bool { data.settings.standUp.pausedOn == todayKey }

    /// The stand-up he picked but hasn't marked done yet.
    var pendingStandUp: StandUpEntry? { today.standUps.last { $0.doneAt == nil } }

    /// The three choices for right now.
    func standUpChoicesNow() -> [StandUpChoice] {
        let t = now()
        let slot = StandUps.currentSlot(now: t, calendar: calendar, settings: data.settings.standUp)
        return StandUps.choices(dayNumber: StandUps.dayNumber(t, calendar: calendar),
                                slot: slot, lotionDone: lotionDoneToday)
    }

    /// Opens the picker. Choices from a notification are used when given (minus the lotion if it's done).
    func showStandUpPicker(choiceIDs: [String]? = nil) {
        var choices = (choiceIDs ?? []).compactMap(StandUps.choice(id:))
        if choices.count != 3 || (lotionDoneToday && choices.contains(StandUps.lotion)) {
            choices = standUpChoicesNow()
        }
        standUpPrompt = choices
    }

    /// Picking one is his commitment to stand up for it.
    func pickStandUp(_ choice: StandUpChoice) {
        let t = now()
        mutateDay(todayKey) { day in
            day.standUps.removeAll { $0.doneAt == nil }
            day.standUps.append(StandUpEntry(picked: t, choiceID: choice.id, title: choice.title))
        }
        save()
    }

    /// Marks the picked stand-up done. Returns today's count.
    @discardableResult
    func completeStandUp() -> Int {
        let t = now()
        var wasLotion = false
        mutateDay(todayKey) { day in
            guard let i = day.standUps.lastIndex(where: { $0.doneAt == nil }) else { return }
            day.standUps[i].doneAt = t
            wasLotion = day.standUps[i].choiceID == StandUps.lotion.id
            if wasLotion && day.lotionDoneAt == nil { day.lotionDoneAt = t }
        }
        save()
        return standUpsDoneToday
    }

    func skipPendingStandUp() {
        mutateDay(todayKey) { $0.standUps.removeAll { $0.doneAt == nil } }
        save()
    }

    func setLotionDone(_ done: Bool) {
        let t = now()
        mutateDay(todayKey) { $0.lotionDoneAt = done ? t : nil }
        save()
    }

    func deleteStandUp(_ id: UUID, on key: String) {
        mutateDay(key) { $0.standUps.removeAll { $0.id == id } }
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

    func addEveryday(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let t = now()
        mutateDay(todayKey) { $0.everyday.append(EverydayEntry(time: t, note: trimmed)) }
        save()
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
        data.settings.breakReminderAt = nil
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
