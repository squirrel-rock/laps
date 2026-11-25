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

    static func play(_ effect: SoundEffect, enabled: Bool) {
        guard enabled else { return }
        if players[effect] == nil,
           let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
            players[effect] = try? AVAudioPlayer(contentsOf: url)
            players[effect]?.prepareToPlay()
        }
        players[effect]?.currentTime = 0
        players[effect]?.play()
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
