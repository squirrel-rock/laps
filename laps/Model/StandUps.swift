import Foundation

/// Timing and wording of the half-hourly "time to get up" reminders.
/// Tapping one opens the Activities list; there's nothing to choose in the notification itself.
enum StandUps {
    static let titles = ["Time to get up, Richard!", "Up you get, Richard!", "Time to get up and move!"]

    /// The reminder's second line. The morning face wash comes first until it's done.
    static func notificationBody(lotionPending: Bool, slot: Int) -> String {
        if lotionPending { return "Face wash and lotion first, then anything from your list." }
        return ["Pick anything from your activities.", "Your activities are ready when you are.",
                "One activity from your list?"][slot % 3]
    }

    /// Reminder times for a day: every 30 minutes from start to end, inclusive.
    static func slots(on day: Date, calendar: Calendar, settings: StandUpSettings) -> [Date] {
        guard let start = calendar.date(bySettingHour: settings.startHour, minute: settings.startMinute, second: 0, of: day),
              let end = calendar.date(bySettingHour: settings.endHour, minute: settings.endMinute, second: 0, of: day),
              end >= start else { return [] }
        var result: [Date] = []
        var t = start
        while t <= end {
            result.append(t)
            t = t.addingTimeInterval(30 * 60)
        }
        return result
    }
}
