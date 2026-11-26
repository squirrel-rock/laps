import Foundation

/// One structured lap: down the stairs (holding the handrail) and back up.
struct LapEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Date
}

/// Everyday walking. A walk to the car and back earns a turquoise walking credit;
/// anything typed with "Something else…" is just a note.
struct EverydayEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Date
    var note: String

    static let carWalk = "Walked to the car"

    var earnsCredit: Bool { note == Self.carWalk }
}

/// A walking session that has ended ("Finished for now").
struct WalkSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Date
    var end: Date
    var lapCount: Int
    var breaks: Int
}

/// One activity, recorded with one tap (`doneAt` is set right away). Entries from before
/// one-tap recording may have been picked and never finished; those have no `doneAt` and don't count.
struct StandUpEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var picked: Date
    var choiceID: String
    var title: String
    var doneAt: Date?
}

/// Everything recorded for one local calendar day.
struct DayRecord: Codable, Hashable {
    var day: String               // "yyyy-MM-dd" in the device's calendar
    var laps: [LapEntry] = []
    var everyday: [EverydayEntry] = []
    var sessions: [WalkSession] = []
    var standUps: [StandUpEntry] = []
    var lotionDoneAt: Date?

    var lapCount: Int { laps.count }
    /// Walks to the car and back: turquoise walking credits.
    var carWalks: Int { everyday.filter(\.earnsCredit).count }
    /// Laps plus car walks. The daily goal is 10.
    var walkingCredits: Int { lapCount + carWalks }
    var standUpsDone: Int { standUps.filter { $0.doneAt != nil }.count }
    /// Activity credits: every recorded activity, with the morning face wash counted once
    /// (older days may have it both as an entry and as `lotionDoneAt`).
    var standingCredits: Int {
        standUps.filter { $0.doneAt != nil && $0.choiceID != Activities.morningLotion.id }.count
            + (lotionDoneAt != nil ? 1 : 0)
    }
    /// Times this activity was recorded today.
    func count(_ id: String) -> Int {
        if id == Activities.morningLotion.id { return lotionDoneAt != nil ? 1 : 0 }
        return standUps.filter { $0.doneAt != nil && $0.choiceID == id }.count
    }
    /// Face washes done (morning and evening): the cream part of the ring and chart.
    var lotions: Int { count(Activities.morningLotion.id) + min(1, count(Activities.eveningLotion.id)) }
    var hasAnything: Bool {
        !laps.isEmpty || !everyday.isEmpty || !sessions.isEmpty || !standUps.isEmpty || lotionDoneAt != nil
    }
}

/// The walking session currently in progress, if any.
struct ActiveSession: Codable, Hashable {
    enum State: String, Codable { case walking, onBreak }

    var id = UUID()
    var day: String
    var start: Date
    var state: State = .walking
    var lapCount = 0
    var breaks = 0
}

struct ReminderTime: Codable, Identifiable, Hashable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var isOn = true

    static let suggested: [ReminderTime] = [
        ReminderTime(hour: 7, minute: 30),
        ReminderTime(hour: 13, minute: 0),
        ReminderTime(hour: 16, minute: 0),
    ]
}

/// Half-hourly "time to get up" activity reminders.
struct StandUpSettings: Codable, Hashable {
    var isOn = true
    var startHour = 10
    var startMinute = 30
    var endHour = 20
    var endMinute = 0
    /// Day key on which standing-up reminders were paused for the rest of the day.
    var pausedOn: String?
    /// Daily standing-up goal, adjustable on the Reminders tab.
    var goal = 10

    static let goalRange = 5...20
}

struct Settings: Codable, Hashable {
    var reminders: [ReminderTime] = ReminderTime.suggested
    var soundOn = true
    /// Day key on which walk reminders were paused for the rest of the day.
    var remindersPausedOn: String?
    /// "Remind me later" invitation, if one is pending.
    var snoozeUntil: Date?
    var standUp = StandUpSettings()
}

struct AppData: Codable {
    var version = 2
    var days: [String: DayRecord] = [:]
    var settings = Settings()
    var active: ActiveSession?
}

// MARK: - Reading older saved files
// Fields added in later versions may be missing from files saved by earlier ones,
// so every field falls back to its default instead of failing to load.

extension DayRecord {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        laps = try c.decodeIfPresent([LapEntry].self, forKey: .laps) ?? []
        everyday = try c.decodeIfPresent([EverydayEntry].self, forKey: .everyday) ?? []
        sessions = try c.decodeIfPresent([WalkSession].self, forKey: .sessions) ?? []
        standUps = try c.decodeIfPresent([StandUpEntry].self, forKey: .standUps) ?? []
        lotionDoneAt = try c.decodeIfPresent(Date.self, forKey: .lotionDoneAt)
    }
}

extension StandUpSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = StandUpSettings()
        isOn = try c.decodeIfPresent(Bool.self, forKey: .isOn) ?? d.isOn
        startHour = try c.decodeIfPresent(Int.self, forKey: .startHour) ?? d.startHour
        startMinute = try c.decodeIfPresent(Int.self, forKey: .startMinute) ?? d.startMinute
        endHour = try c.decodeIfPresent(Int.self, forKey: .endHour) ?? d.endHour
        endMinute = try c.decodeIfPresent(Int.self, forKey: .endMinute) ?? d.endMinute
        pausedOn = try c.decodeIfPresent(String.self, forKey: .pausedOn)
        goal = try c.decodeIfPresent(Int.self, forKey: .goal) ?? d.goal
    }
}

extension Settings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reminders = try c.decodeIfPresent([ReminderTime].self, forKey: .reminders) ?? ReminderTime.suggested
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        remindersPausedOn = try c.decodeIfPresent(String.self, forKey: .remindersPausedOn)
        snoozeUntil = try c.decodeIfPresent(Date.self, forKey: .snoozeUntil)
        standUp = try c.decodeIfPresent(StandUpSettings.self, forKey: .standUp) ?? StandUpSettings()
    }
}

extension AppData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        days = try c.decodeIfPresent([String: DayRecord].self, forKey: .days) ?? [:]
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        active = try c.decodeIfPresent(ActiveSession.self, forKey: .active)
    }
}

/// One day on the This Week charts.
struct WeekDay: Equatable {
    var key: String
    var date: Date
    var laps: Int
    var carWalks: Int
    /// Activities, including the face washes.
    var standing: Int
    /// Face washes (0–2).
    var lotions: Int

    var walking: Int { laps + carWalks }

    /// Walking bar from the bottom: car walks (turquoise), laps up to the goal (teal), then gold.
    var walkingParts: (carWalks: Int, laps: Int, gold: Int) {
        let teal = min(laps, max(0, LapMath.dailyGoal - carWalks))
        return (carWalks, teal, laps - teal)
    }

    /// Activities bar from the bottom: face washes (cream), activities to the goal (violet), then gold.
    func standingParts(goal: Int) -> (lotion: Int, violet: Int, gold: Int) {
        let l = min(lotions, standing)
        let others = standing - l
        let violet = min(others, max(0, goal - l))
        return (l, violet, others - violet)
    }
}
