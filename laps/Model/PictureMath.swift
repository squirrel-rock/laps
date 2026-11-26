import Foundation

/// How many tiles of the daily picture are uncovered, and in what order.
enum PictureMath {
    /// Walking credits a Determined picture needs.
    static let walkingNeeded = LapMath.dailyGoal

    /// Tiles uncovered for this many walking and activity credits.
    /// - Flexible: every credit is a tile.
    /// - Determined: every walking credit is a tile (gold laps too); activities fill
    ///   at most the tiles past the first 10, so the picture can't finish without 10 walking.
    static func revealed(walking: Int, standing: Int, tiles: Int, mode: RewardMode) -> Int {
        let w = max(0, walking), s = max(0, standing)
        switch mode {
        case .flexible:
            return min(tiles, w + s)
        case .determined:
            return min(tiles, w + min(s, max(0, tiles - walkingNeeded)))
        }
    }

    /// The line under the picture, e.g. "8 of 20 uncovered" and what's left.
    static func status(walking: Int, standing: Int, tiles: Int, mode: RewardMode) -> String {
        let shown = revealed(walking: walking, standing: standing, tiles: tiles, mode: mode)
        if shown >= tiles { return "All \(tiles) uncovered. Beautiful!" }
        if shown == 0 { return "Your first walk or activity uncovers a piece." }
        let left = tiles - shown
        // In Determined mode, once activities have done their share, only walking uncovers more.
        if mode == .determined, standing >= tiles - walkingNeeded {
            return "\(shown) of \(tiles) uncovered. \(LapMath.plural(left, "more walk")) to go."
        }
        return "\(shown) of \(tiles) uncovered. \(left) to go."
    }

    /// Every tile in a scattered order that stays the same all day for this picture,
    /// so reopening the app never reshuffles what's already uncovered.
    static func order(tiles: Int, seed: String) -> [Int] {
        var rng = SeededRandom(seed: seed)
        var cells = Array(0..<tiles)
        for i in stride(from: cells.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            cells.swapAt(i, j)
        }
        return cells
    }
}

/// A small repeatable random generator (SplitMix64), seeded from text.
/// Swift's own hashing changes every launch, so it can't be used for this.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var h: UInt64 = 0xcbf29ce484222325          // FNV-1a
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        state = h
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
