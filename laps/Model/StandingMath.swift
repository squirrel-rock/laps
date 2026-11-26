import Foundation

/// The numbers and gentle wording behind activities (getting up from sitting).
///
/// Every activity earns one credit. The goal is adjustable (10 by default); anything past it is gold.
/// The face washes come first in the ring and pills, in cream.
enum StandingMath {
    static let perGroup = 5

    /// Violet pill groups up to the goal, after the cream face-wash pills: e.g. [5, 5] or [5, 3].
    static func goalGroups(goal: Int, lotions: Int) -> [Int] {
        var left = max(0, goal - lotions), groups: [Int] = []
        while left > 0 { groups.append(min(perGroup, left)); left -= perGroup }
        return groups
    }

    static func progress(_ credits: Int, goal: Int) -> Double {
        goal > 0 ? min(1, Double(max(0, credits)) / Double(goal)) : 1
    }

    /// The line under the violet ring.
    static func statusLine(_ credits: Int, goal: Int) -> String {
        switch credits {
        case ..<1: return "Ready for your first activity?"
        case 1..<goal:
            let left = goal - credits
            return "\(left) more activit\(left == 1 ? "y" : "ies") to today's goal"
        case goal: return "Goal reached! Every extra one is gold."
        default:
            let extra = credits - goal
            return "\(extra) gold bonus\(extra == 1 ? "" : "es"). Wonderful!"
        }
    }

    enum Moment: Equatable { case one, goal, bonus }

    static func moment(after credits: Int, goal: Int) -> Moment {
        credits == goal ? .goal : (credits > goal ? .bonus : .one)
    }

    static func message(after credits: Int, goal: Int) -> String {
        switch moment(after: credits, goal: goal) {
        case .one: return credits == 1 ? "Nicely done! That's your first activity today." : "Nicely done! That's \(credits) today."
        case .goal: return "\(credits) activities today. Goal reached!"
        case .bonus: return "A gold one! \(credits) activities today."
        }
    }
}
