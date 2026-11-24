import Foundation
import Observation

/// Owns all of Richard's records. Every change is written to disk immediately.
@MainActor
@Observable
final class WalkStore {
    private(set) var data: AppData
    /// Set when the saved file couldn't be read, so nothing gets silently overwritten.
    private(set) var loadProblem: String?

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
            .filter { !$0.laps.isEmpty || !$0.everyday.isEmpty || !$0.sessions.isEmpty }
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
        ReminderPlanner.plan(now: now(), calendar: calendar, settings: data.settings, lapsToday: lapsToday)
    }

    func refreshReminders() {
        scheduler?.apply(currentPlan())
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
