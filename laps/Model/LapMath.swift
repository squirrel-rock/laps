import Foundation

/// The numbers and gentle wording behind Richard's walking.
///
/// A **walking credit** is one lap, or one walk down to the car and back. The daily goal is 10 credits: on a day with a car walk, 9 laps gets
/// him there; on a day without, 10 laps. Anything past 10 is a gold bonus.
enum LapMath {
    static let lapsPerSet = 3
    /// The daily goal, in walking credits.
    static let dailyGoal = 10
    /// After this many credits, today's walk reminders go quiet (3 bonus at most).
    static let quietAfter = 13

    static func sets(_ laps: Int) -> Int { max(0, laps) / lapsPerSet }
    static func extraLaps(_ laps: Int) -> Int { max(0, laps) % lapsPerSet }
    static func creditsToGoal(_ credits: Int) -> Int { max(0, dailyGoal - credits) }
    static func goalProgress(_ credits: Int) -> Double { min(1, Double(max(0, credits)) / Double(dailyGoal)) }

    static func plural(_ n: Int, _ word: String) -> String {
        "\(n) \(word)\(n == 1 ? "" : "s")"
    }

    /// "1 complete set + 1 lap", "2 complete sets", "2 laps toward your first set".
    static func setsDescription(_ laps: Int) -> String {
        let s = sets(laps), e = extraLaps(laps)
        switch (s, e) {
        case (0, 0): return "No laps yet today"
        case (0, _): return "\(plural(e, "lap")) toward your first set"
        case (_, 0): return "\(s) complete set\(s == 1 ? "" : "s")"
        default: return "\(s) complete set\(s == 1 ? "" : "s") + \(plural(e, "lap"))"
        }
    }

    /// "2 complete sets + 1 car walk" — the sets line plus any car walks.
    static func walkingDescription(laps: Int, carWalks: Int) -> String {
        guard carWalks > 0 else { return setsDescription(laps) }
        let walks = plural(carWalks, "car walk")
        return laps == 0 ? walks : "\(setsDescription(laps)) + \(walks)"
    }

    /// Sets and laps for a week total, e.g. "14 sets + 2 laps".
    static func setsShort(_ laps: Int) -> String {
        let s = sets(laps), e = extraLaps(laps)
        if e == 0 { return plural(s, "set") }
        if s == 0 { return plural(e, "lap") }
        return "\(plural(s, "set")) + \(plural(e, "lap"))"
    }

    /// Laps still needed for the goal once car walks are counted.
    static func lapsNeeded(carWalks: Int) -> Int { max(0, dailyGoal - carWalks) }

    /// How the lap slots are grouped on screen: sets of 3 up to the goal (the last one may be
    /// shorter), e.g. [3, 3, 3, 1] with no car walk, or [3, 3, 3] with one.
    static func goalGroups(carWalks: Int) -> [Int] {
        var left = lapsNeeded(carWalks: carWalks), groups: [Int] = []
        while left > 0 { groups.append(min(lapsPerSet, left)); left -= lapsPerSet }
        return groups
    }

    /// The line under the ring on the main screen.
    static func statusLine(credits: Int) -> String {
        let toLucky = luckyNumber - credits
        switch credits {
        case ..<1: return "Ready whenever you are."
        case 1..<dailyGoal:
            return "\(plural(creditsToGoal(credits), "lap")) to today's goal"
        case dailyGoal:
            return "Goal reached! 3 gold laps make 13 — only if you feel up to it."
        case _ where credits < luckyNumber:
            return "\(toLucky) more gold lap\(toLucky == 1 ? "" : "s") make\(toLucky == 1 ? "s" : "") 13 — only if you feel up to it."
        case luckyNumber:
            return "Thirteen! A lucky number. What a day!"
        default:
            return "\(credits) today. Wonderful!"
        }
    }

    /// The special number: the goal plus a full gold set.
    static let luckyNumber = 13

    enum Moment: Equatable {
        case lap, set, goal, bonusLap, lucky, bonusSet

        var isBig: Bool { self != .lap && self != .bonusLap }
    }

    /// Where a lap lands on screen: its place in its group (0, 1, 2 → C, E, G) and what it finished.
    /// Groups are the dot groups, so what he hears matches what he sees.
    static func step(afterLap laps: Int, carWalks: Int) -> (note: Int, moment: Moment) {
        let n = max(1, laps)
        let needed = lapsNeeded(carWalks: carWalks)
        if n <= needed {
            let note = (n - 1) % lapsPerSet
            if n == needed { return (note, .goal) }
            return (note, n % lapsPerSet == 0 ? .set : .lap)
        }
        let b = n - needed
        let note = (b - 1) % lapsPerSet
        guard b % lapsPerSet == 0 else { return (note, .bonusLap) }
        return (note, b == lapsPerSet ? .lucky : .bonusSet)
    }

    static func moment(afterLap laps: Int, carWalks: Int) -> Moment {
        step(afterLap: laps, carWalks: carWalks).moment
    }

    /// Encouraging message shown right after a lap is recorded.
    static func message(afterLap laps: Int, carWalks: Int) -> String {
        let credits = laps + carWalks
        switch moment(afterLap: laps, carWalks: carWalks) {
        case .lap:
            return ["One more lap accomplished!", "Nicely done!", "That's another lap!"][laps % 3]
        case .set:
            return sets(laps) == 1 ? "You've completed a set!" : "That's \(sets(laps)) sets!"
        case .goal:
            return "Ten today. Goal reached!"
        case .bonusLap:
            return "A gold bonus lap! Every one counts."
        case .lucky:
            return "Thirteen! A lucky number."
        case .bonusSet:
            return "\(credits) today. Remarkable!"
        }
    }
}
