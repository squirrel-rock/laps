import Foundation

/// The numbers and gentle wording behind Richard's laps.
enum LapMath {
    static let lapsPerSet = 3
    /// The daily minimum: 3 sets.
    static let dailyGoal = 9
    /// What's prescribed when he feels up to it: 4 sets. Never required.
    static let bonusGoal = 12

    static func sets(_ laps: Int) -> Int { max(0, laps) / lapsPerSet }
    static func extraLaps(_ laps: Int) -> Int { max(0, laps) % lapsPerSet }
    static func lapsToGoal(_ laps: Int) -> Int { max(0, dailyGoal - laps) }
    static func goalProgress(_ laps: Int) -> Double { min(1, Double(max(0, laps)) / Double(dailyGoal)) }

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

    /// Sets and laps for a week total, e.g. "14 sets + 2 laps".
    static func setsShort(_ laps: Int) -> String {
        let s = sets(laps), e = extraLaps(laps)
        if e == 0 { return plural(s, "set") }
        if s == 0 { return plural(e, "lap") }
        return "\(plural(s, "set")) + \(plural(e, "lap"))"
    }

    /// The line under the big number on the main screen.
    static func statusLine(_ laps: Int) -> String {
        switch laps {
        case ..<1: return "Ready whenever you are."
        case 1..<dailyGoal:
            let r = lapsToGoal(laps)
            return "\(plural(r, "lap")) to today's goal"
        case dailyGoal..<bonusGoal:
            let r = bonusGoal - laps
            return "Goal reached! \(plural(r, "more lap")) would make a 4th set — only if you feel up to it."
        case bonusGoal:
            return "Four sets today. What a day!"
        default:
            return "\(plural(sets(laps), "set")) and counting. Wonderful!"
        }
    }

    enum Moment: Equatable {
        case lap, set, goal, bonusLap, fourSets, extraSet

        var isBig: Bool { self != .lap && self != .bonusLap }
    }

    static func moment(afterLap laps: Int) -> Moment {
        switch laps {
        case dailyGoal: return .goal
        case bonusGoal: return .fourSets
        case _ where laps > bonusGoal && laps % lapsPerSet == 0: return .extraSet
        case _ where laps > dailyGoal: return .bonusLap
        case _ where laps % lapsPerSet == 0: return .set
        default: return .lap
        }
    }

    /// Encouraging message shown right after a lap is recorded.
    static func message(afterLap laps: Int) -> String {
        switch moment(afterLap: laps) {
        case .lap:
            return ["One more lap accomplished!", "Nicely done!", "That's another lap!"][laps % 3]
        case .set:
            return sets(laps) == 1 ? "You've completed a set!" : "That's \(sets(laps)) sets!"
        case .goal:
            return "Nine laps today. Goal reached!"
        case .bonusLap:
            return "A bonus lap! Every one counts."
        case .fourSets:
            return "Four sets today. What a day!"
        case .extraSet:
            return "\(sets(laps)) sets today. Remarkable!"
        }
    }
}
