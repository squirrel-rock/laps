import Foundation

/// The numbers and gentle wording behind standing up.
///
/// Every time he stands up earns one credit: a quick "I stood up", a finished suggestion,
/// or the face lotion. The goal is adjustable (10 by default); anything past it is gold.
enum StandingMath {
    static let perGroup = 5

    /// Violet pill groups up to the goal, after the face lotion pill: e.g. [5, 5] or [5, 4].
    static func goalGroups(goal: Int, lotionDone: Bool) -> [Int] {
        var left = max(0, goal - (lotionDone ? 1 : 0)), groups: [Int] = []
        while left > 0 { groups.append(min(perGroup, left)); left -= perGroup }
        return groups
    }

    static func progress(_ credits: Int, goal: Int) -> Double {
        goal > 0 ? min(1, Double(max(0, credits)) / Double(goal)) : 1
    }

    /// The line under the violet ring.
    static func statusLine(_ credits: Int, goal: Int) -> String {
        switch credits {
        case ..<1: return "Ready for your first time up?"
        case 1..<goal:
            let left = goal - credits
            return "\(left) more time\(left == 1 ? "" : "s") up to today's goal"
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
        case .one: return credits == 1 ? "You stood up! That's your first today." : "You stood up! That's \(credits) today."
        case .goal: return "\(credits) times up today. Goal reached!"
        case .bonus: return "A gold one! \(credits) times up today."
        }
    }
}
