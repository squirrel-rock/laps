import Foundation

/// One structured lap (down the stairs, back up, once around the living room).
struct LapEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Date
}

/// Everyday walking, kept separate from the structured laps.
struct EverydayEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Date
    var note: String
}

/// A walking session that has ended ("Finished for now").
struct WalkSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Date
    var end: Date
    var lapCount: Int
    var breaks: Int
}

/// Everything recorded for one local calendar day.
struct DayRecord: Codable, Hashable {
    var day: String               // "yyyy-MM-dd" in the device's calendar
    var laps: [LapEntry] = []
    var everyday: [EverydayEntry] = []
    var sessions: [WalkSession] = []

    var lapCount: Int { laps.count }
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

struct Settings: Codable, Hashable {
    var reminders: [ReminderTime] = ReminderTime.suggested
    var soundOn = true
    /// Day key on which reminders were paused for the rest of the day.
    var remindersPausedOn: String?
    /// "Remind me later" invitation, if one is pending.
    var snoozeUntil: Date?
    /// Bathroom-break reminder, if one is pending.
    var breakReminderAt: Date?
}

struct AppData: Codable {
    var version = 1
    var days: [String: DayRecord] = [:]
    var settings = Settings()
    var active: ActiveSession?
}
