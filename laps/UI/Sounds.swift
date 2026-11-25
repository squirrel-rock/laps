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

    /// Each set climbs C, E, G (tuning-fork tones). The 3rd lap's G leads into the
    /// happy set sound, or the fanfare at 9 and 12 laps.
    static func playLap(total: Int, enabled: Bool) {
        play(lapNote(forLap: total), enabled: enabled)
        let finish: SoundEffect?
        switch LapMath.moment(afterLap: total) {
        case .set: finish = .set
        case .goal, .fourSets, .extraSet: finish = .goal
        case .lap, .bonusLap: finish = nil
        }
        if let finish {
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                play(finish, enabled: enabled)
            }
        }
    }

    /// Lap 1, 2, 3 of each set → C, E, G.
    nonisolated static func lapNote(forLap total: Int) -> SoundEffect {
        switch (max(1, total) - 1) % 3 {
        case 0: return .lapC
        case 1: return .lapE
        default: return .lapG
        }
    }
}
