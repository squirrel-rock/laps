import Foundation

struct StandUpChoice: Hashable, Identifiable {
    enum Kind { case spin, exercise, fun, lotion }

    let id: String
    let kind: Kind
    /// Button text in the app.
    let title: String
    /// Short form used in the notification ("Pick one: …").
    let short: String
    let icon: String
}

/// The three-way choice offered when it's time to stand up. Every choice requires standing.
enum StandUps {
    /// Choice ID used for a quick "I stood up" with no suggestion.
    static let stoodID = "stood"

    static let spin = StandUpChoice(
        id: "spin", kind: .spin,
        title: "Take a spin around the living room",
        short: "a spin around the living room",
        icon: "arrow.triangle.2.circlepath")

    /// A daily medical task. Offered at every stand-up until it's done for the day.
    static let lotion = StandUpChoice(
        id: "lotion", kind: .lotion,
        title: "Wash your face and put on your lotion",
        short: "your face lotion",
        icon: "face.smiling")

    static let exercises: [StandUpChoice] = [
        .init(id: "standups", kind: .exercise, title: "Do 10 stand-ups", short: "10 stand-ups", icon: "figure.stand"),
        .init(id: "floor", kind: .exercise, title: "Get down on the floor and back up again", short: "down to the floor and back up", icon: "figure.cooldown"),
        .init(id: "stretch", kind: .exercise, title: "Stand up and do a big stretch", short: "a big stretch", icon: "figure.flexibility"),
        .init(id: "march", kind: .exercise, title: "March in place 10 times", short: "marching in place", icon: "figure.walk"),
        .init(id: "balance", kind: .exercise, title: "Go to the doorway and do a balance exercise", short: "a balance exercise", icon: "figure.mind.and.body"),
        .init(id: "heels", kind: .exercise, title: "Hold the kitchen counter and do 10 heel raises", short: "10 heel raises", icon: "shoeprints.fill"),
        .init(id: "squats", kind: .exercise, title: "Go to the kitchen and do your squats", short: "your kitchen squats", icon: "figure.strengthtraining.functional"),
        .init(id: "clap", kind: .exercise, title: "Stand up and clap your hands above your head 3 times", short: "3 big claps overhead", icon: "hands.clap.fill"),
    ]

    static let fun: [StandUpChoice] = [
        .init(id: "squirrels", kind: .fun, title: "Go see if there are any squirrels outside", short: "a squirrel check", icon: "tree.fill"),
        .init(id: "dishes", kind: .fun, title: "Are the dishes unloaded yet? Go and check!", short: "checking on the dishes", icon: "fork.knife"),
        .init(id: "fire", kind: .fun, title: "Go see if the fire needs another piece of wood", short: "checking the fire", icon: "flame.fill"),
        .init(id: "water", kind: .fun, title: "Walk to the kitchen and refill your water glass", short: "a fresh glass of water", icon: "waterbottle.fill"),
        .init(id: "tidy", kind: .fun, title: "Put one thing back where it belongs", short: "putting one thing away", icon: "archivebox.fill"),
        .init(id: "raingauge", kind: .fun, title: "Go check the rain gauge", short: "a rain gauge check", icon: "cloud.rain.fill"),
    ]

    static let titles = ["Time to stand up, Richard!", "Up you get, Richard!", "Time to get up and move!"]

    static func choice(id: String) -> StandUpChoice? {
        ([spin, lotion] + exercises + fun).first { $0.id == id }
    }

    /// Spin around the living room, one exercise, and one fun or useful thing.
    /// Rotates through the lists by day and time slot, so the options keep changing.
    static func choices(dayNumber: Int, slot: Int, lotionDone: Bool) -> [StandUpChoice] {
        let exercise = exercises[positiveMod(dayNumber * 3 + slot, exercises.count)]
        let third = lotionDone ? fun[positiveMod(dayNumber * 2 + slot, fun.count)] : lotion
        return [spin, exercise, third]
    }

    static func notificationBody(_ choices: [StandUpChoice]) -> String {
        guard choices.count == 3 else { return "Pick one thing to stand up for." }
        return "Pick one: \(choices[0].short), \(choices[1].short), or \(choices[2].short)."
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

    static func dayNumber(_ date: Date, calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    /// Index of the most recent slot at or before `now` (0 before the first one).
    static func currentSlot(now: Date, calendar: Calendar, settings: StandUpSettings) -> Int {
        let slots = slots(on: calendar.startOfDay(for: now), calendar: calendar, settings: settings)
        return max(0, (slots.lastIndex { $0 <= now }) ?? 0)
    }

    private static func positiveMod(_ a: Int, _ n: Int) -> Int { ((a % n) + n) % n }
}
