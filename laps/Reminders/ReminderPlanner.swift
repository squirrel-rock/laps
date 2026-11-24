import Foundation

/// A notification the app wants pending. Pure data so the rules can be unit tested.
struct PlannedReminder: Equatable {
    enum Kind: Equatable { case daily, later, bathroomBreak }

    var id: String
    var date: Date
    var title: String
    var body: String
    var kind: Kind
}

/// Decides exactly which reminders should be pending right now.
/// The scheduler replaces everything pending with this list, so there are never duplicates.
enum ReminderPlanner {
    static let laterMinutes = 30
    static let breakMinutes = 10
    /// iOS keeps at most 64 pending notifications per app.
    static let systemLimit = 64
    static let maxDaysAhead = 14
    /// A daily reminder this close to a one-off reminder is dropped to avoid doubling up.
    static let clashWindow: TimeInterval = 20 * 60

    static let laterID = "walk.later"
    static let breakID = "walk.break"

    static let invitations = [
        "Time for a little walk?",
        "Fancy a few laps?",
        "The stairs are ready when you are.",
    ]

    static func plan(now: Date,
                     calendar: Calendar,
                     settings: Settings,
                     lapsToday: Int) -> [PlannedReminder] {
        let dayKey = DayKey(calendar: calendar)
        let todayKey = dayKey.key(for: now)
        let pausedToday = settings.remindersPausedOn == todayKey
        var result: [PlannedReminder] = []

        if !pausedToday {
            if let at = settings.breakReminderAt, at > now {
                result.append(PlannedReminder(
                    id: breakID, date: at,
                    title: "Ready to finish your walk?",
                    body: "Your laps are saved. Pick up right where you left off.",
                    kind: .bathroomBreak))
            }
            if let at = settings.snoozeUntil, at > now {
                result.append(PlannedReminder(
                    id: laterID, date: at,
                    title: "Time for a little walk?",
                    body: "Whenever you're ready.",
                    kind: .later))
            }
        }
        let oneOffDates = result.map(\.date)

        let times = settings.reminders
            .filter(\.isOn)
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        guard !times.isEmpty else { return result }

        let room = systemLimit - result.count
        let daysAhead = max(1, min(maxDaysAhead, room / times.count))
        let startOfToday = calendar.startOfDay(for: now)

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let isToday = offset == 0
            if isToday && (pausedToday || lapsToday >= LapMath.bonusGoal) { continue }
            let key = dayKey.key(for: day)

            for (index, time) in times.enumerated() {
                guard let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
                      date > now else { continue }
                if oneOffDates.contains(where: { abs($0.timeIntervalSince(date)) < clashWindow }) { continue }

                let bonus = isToday && lapsToday >= LapMath.dailyGoal
                result.append(PlannedReminder(
                    id: String(format: "walk.daily.%@.%02d%02d", key, time.hour, time.minute),
                    date: date,
                    title: bonus ? "Feeling up for a bonus set?" : invitations[index % invitations.count],
                    body: bonus ? "You've already reached today's goal. Only if you feel like it."
                                : "A few laps whenever you're ready.",
                    kind: .daily))
            }
        }
        return Array(result.prefix(systemLimit))
    }
}
