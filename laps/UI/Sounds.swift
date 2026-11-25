import AVFoundation

enum SoundEffect: String {
    case lapC, lapE, lapG, set, goal, standup
}

/// The app's own sounds. They play even when the ring/silent switch is on silent
/// (Richard asked for sounds), and can be turned off on the Reminders tab.
@MainActor
enum Sounds {
    private static var players: [SoundEffect: AVAudioPlayer] = [:]

    /// Sets up audio once, off the main thread, so playing never stalls the screen.
    /// `.playback` lets sounds play on silent; `.mixWithOthers` leaves music or radio playing.
    nonisolated static func prepareSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.mixWithOthers])
            try? session.setActive(true)
        }
    }

    /// Loads every sound up front so even the first tap plays instantly.
    static func preload() {
        for effect in [SoundEffect.lapC, .lapE, .lapG, .set, .goal, .standup] { _ = player(for: effect) }
    }

    /// Never blocks: each sound has its own player, so notes can ring over each other.
    static func play(_ effect: SoundEffect, enabled: Bool) {
        guard enabled, let p = player(for: effect) else { return }
        p.currentTime = 0
        p.play()
    }

    private static func player(for effect: SoundEffect) -> AVAudioPlayer? {
        if let p = players[effect] { return p }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        players[effect] = p
        return p
    }

    /// Each dot group climbs C, E, G (tuning-fork tones). A full group leads into the
    /// happy set sound, or the fanfare at the goal of 10, at 13, and each gold set after.
    static func playLap(total: Int, carWalks: Int, enabled: Bool) {
        let step = LapMath.step(afterLap: total, carWalks: carWalks)
        play(note(step.note), enabled: enabled)
        let finish: SoundEffect?
        switch step.moment {
        case .set: finish = .set
        case .goal, .lucky, .bonusSet: finish = .goal
        case .lap, .bonusLap: finish = nil
        }
        if let finish {
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                play(finish, enabled: enabled)
            }
        }
    }

    /// Place 0, 1, 2 in a dot group → C, E, G.
    nonisolated static func note(_ place: Int) -> SoundEffect {
        switch place % 3 {
        case 0: return .lapC
        case 1: return .lapE
        default: return .lapG
        }
    }
}
