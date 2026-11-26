import Foundation

/// One thing Richard can get up for. Every one is recorded with a single tap and earns one
/// activity credit (the honor system: it counts when he gets up from sitting to do it).
struct Activity: Hashable, Identifiable {
    enum Kind {
        /// Encouraged every day; checked off once and moved to Completed today.
        case daily
        /// Harder exercises he'd like to do more often: checked off once, never any pressure.
        case extra
        /// Repeatable through the day, with a count.
        case anytime
    }

    let id: String
    let kind: Kind
    /// The main word, shown large and used for alphabetical order, e.g. "Fire".
    let subject: String
    /// What to do, shown smaller, e.g. "Tend".
    let action: String?
    let icon: String
    /// Turns amber once he reaches his goal without having done it.
    var amberAtGoal = false

    var title: String { action.map { "\(subject): \($0)" } ?? subject }
    var isCheckable: Bool { kind != .anytime }
}

enum Activities {
    /// The morning face wash. Kept as `DayRecord.lotionDoneAt`, so older days still read the same.
    static let morningLotion = Activity(id: "lotion", kind: .daily, subject: "Face wash and lotion",
                                        action: "Morning", icon: "sun.max.fill")
    static let eveningLotion = Activity(id: "lotionEvening", kind: .daily, subject: "Face wash and lotion",
                                        action: "Evening", icon: "moon.fill")

    /// Daily activities, in the order Richard and Kelly chose.
    static let daily: [Activity] = [
        morningLotion,
        eveningLotion,
        Activity(id: "dishwasher", kind: .daily, subject: "Dishwasher", action: "Check or unload", icon: "fork.knife"),
        Activity(id: "heels", kind: .daily, subject: "Heel raises (10)", action: nil, icon: "shoeprints.fill", amberAtGoal: true),
        Activity(id: "squats", kind: .daily, subject: "Squats in the kitchen (10)", action: nil,
                 icon: "figure.strengthtraining.functional", amberAtGoal: true),
        Activity(id: "standups", kind: .daily, subject: "Stand-ups (10)", action: nil, icon: "figure.stand", amberAtGoal: true),
    ]

    static let extra: [Activity] = [
        Activity(id: "balance", kind: .extra, subject: "Balance exercises", action: nil, icon: "figure.mind.and.body"),
        Activity(id: "floor", kind: .extra, subject: "Floor stretches", action: nil, icon: "figure.cooldown"),
    ]

    /// Anytime activities, alphabetical by subject (Richard's request).
    static let anytime: [Activity] = [
        Activity(id: "bathroom", kind: .anytime, subject: "Bathroom", action: "Visit", icon: "toilet.fill"),
        Activity(id: "clap", kind: .anytime, subject: "Clap overhead (3)", action: nil, icon: "hands.clap.fill"),
        Activity(id: "fire", kind: .anytime, subject: "Fire", action: "Tend", icon: "flame.fill"),
        Activity(id: "laundry", kind: .anytime, subject: "Laundry", action: nil, icon: "washer.fill"),
        Activity(id: "spin", kind: .anytime, subject: "Living room", action: "Take a spin", icon: "arrow.triangle.2.circlepath"),
        Activity(id: "march", kind: .anytime, subject: "March in place (10)", action: nil, icon: "figure.walk"),
        Activity(id: "raingauge", kind: .anytime, subject: "Rain gauge", action: "Check", icon: "cloud.rain.fill"),
        Activity(id: "shower", kind: .anytime, subject: "Shower", action: nil, icon: "shower.fill"),
        Activity(id: "squirrels", kind: .anytime, subject: "Squirrels", action: "Look outside", icon: "tree.fill"),
        Activity(id: "teeth", kind: .anytime, subject: "Teeth", action: "Brush", icon: "face.smiling"),
        Activity(id: "water", kind: .anytime, subject: "Water glass", action: "Refill", icon: "waterbottle.fill"),
    ].sorted { $0.subject.localizedCaseInsensitiveCompare($1.subject) == .orderedAscending }

    /// Anything not on the list, at the bottom of Anytime. (The old "I stood up".)
    static let somethingElse = Activity(id: "stood", kind: .anytime, subject: "Something else",
                                        action: "I got up", icon: "figure.stand")

    static let all: [Activity] = daily + extra + anytime + [somethingElse]

    static func activity(id: String) -> Activity? { all.first { $0.id == id } }

    /// The extra cheer for an extra accomplishment.
    static func extraCheer(_ n: Int) -> String {
        ["That's a hard one. Well done!", "Extra credit! Wonderful.", "Look at you go!"][abs(n) % 3]
    }

    /// The morning face wash turns amber at noon if it isn't done.
    static let morningDeadlineHour = 12
}
