import Foundation

/// A notification the app wants pending. Pure data so the rules can be unit tested.
struct PlannedReminder: Equatable {
    enum Kind: Equatable { case daily, later, bathroomBreak, standUp }

    var id: String
    var date: Date
    var title: String
    var body: String
    var kind: Kind
    /// For stand-ups: the three choice IDs offered.
    var choiceIDs: [String] = []

    var isWalkReminder: Bool { kind != .standUp }
}

/// Decides exactly which reminders should be pending right now.
/// The scheduler replaces everything pending with this list, so there are never duplicates.
enum ReminderPlanner {
    static let laterMinutes = 30
    static let breakMinutes = 10
    /// iOS keeps at most 64 pending notifications per app.
    static let systemLimit = 64
    static let maxDaysAhead = 14
    /// Walk reminders cover a week ahead when stand-ups are on (stand-ups use the rest of the room).
    static let walkDaysWithStandUps = 7
    /// A daily reminder this close to a one-off reminder is dropped to avoid doubling up.
    static let clashWindow: TimeInterval = 20 * 60
    /// A stand-up this close to any walk reminder is dropped.
    static let standUpClashWindow: TimeInterval = 15 * 60

    static let laterID = "walk.later"
    static let breakID = "walk.break"

    static let invitations = [
        "Time for a little walk?",
        "Fancy a few laps?",
        "The stairs are ready when you are.",
    ]

    /// - Parameters:
    ///   - lotionDoneToday: once true, today's stand-ups stop offering the face lotion.
    ///   - standUpsQuietUntil: no stand-ups before this time (he's in the middle of a walk).
    static func plan(now: Date,
                     calendar: Calendar,
                     settings: Settings,
                     creditsToday: Int,
                     lotionDoneToday: Bool = false,
                     standUpsQuietUntil: Date? = nil) -> [PlannedReminder] {
        let dayKey = DayKey(calendar: calendar)
        let todayKey = dayKey.key(for: now)
        let pausedToday = settings.remindersPausedOn == todayKey
        let startOfToday = calendar.startOfDay(for: now)
        var result: [PlannedReminder] = []

        // One-off walk reminders.
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

        // Daily walk reminders.
        let times = settings.reminders
            .filter(\.isOn)
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        if !times.isEmpty {
            let room = systemLimit - result.count
            let horizon = settings.standUp.isOn ? walkDaysWithStandUps : maxDaysAhead
            let daysAhead = max(1, min(horizon, room / times.count))

            for offset in 0..<daysAhead {
                guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
                let isToday = offset == 0
                if isToday && (pausedToday || creditsToday >= LapMath.quietAfter) { continue }
                let key = dayKey.key(for: day)

                for (index, time) in times.enumerated() {
                    guard let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
                          date > now else { continue }
                    if oneOffDates.contains(where: { abs($0.timeIntervalSince(date)) < clashWindow }) { continue }

                    let bonus = isToday && creditsToday >= LapMath.dailyGoal
                    result.append(PlannedReminder(
                        id: String(format: "walk.daily.%@.%02d%02d", key, time.hour, time.minute),
                        date: date,
                        title: bonus ? "Feeling up for a bonus?" : invitations[index % invitations.count],
                        body: bonus ? "You've reached today's goal. 3 gold laps make 13 — only if you feel like it."
                                    : "A few laps whenever you're ready.",
                        kind: .daily))
                }
            }
        }

        // Stand-up reminders fill the remaining room, soonest first.
        let standUp = settings.standUp
        if standUp.isOn {
            let walkDates = result.map(\.date)
            var room = systemLimit - result.count
            var offset = 0
            while room > 0 && offset < maxDaysAhead {
                defer { offset += 1 }
                guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
                let isToday = offset == 0
                if isToday && standUp.pausedOn == todayKey { continue }
                let key = dayKey.key(for: day)
                let dayNumber = StandUps.dayNumber(day, calendar: calendar)
                let comps = StandUps.slots(on: day, calendar: calendar, settings: standUp)

                for (slot, date) in comps.enumerated() where room > 0 {
                    guard date > now else { continue }
                    if let quiet = standUpsQuietUntil, date < quiet { continue }
                    if walkDates.contains(where: { abs($0.timeIntervalSince(date)) < standUpClashWindow }) { continue }

                    let choices = StandUps.choices(dayNumber: dayNumber, slot: slot,
                                                   lotionDone: isToday && lotionDoneToday)
                    let hm = calendar.dateComponents([.hour, .minute], from: date)
                    result.append(PlannedReminder(
                        id: String(format: "standup.%@.%02d%02d", key, hm.hour ?? 0, hm.minute ?? 0),
                        date: date,
                        title: StandUps.titles[slot % StandUps.titles.count],
                        body: StandUps.notificationBody(choices),
                        kind: .standUp,
                        choiceIDs: choices.map(\.id)))
                    room -= 1
                }
            }
        }

        return Array(result.prefix(systemLimit))
    }
}
