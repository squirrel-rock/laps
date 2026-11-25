import AVFoundation

enum SoundEffect: String {
    case lap, set, goal, standup
}

/// The app's own cheerful sounds. They play even when the ring/silent switch is on silent
/// (Richard asked for sounds), and can be turned off on the Reminders tab.
@MainActor
enum Sounds {
    private static var players: [SoundEffect: AVAudioPlayer] = [:]

    static func play(_ effect: SoundEffect, enabled: Bool) {
        guard enabled else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        if players[effect] == nil,
           let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
            players[effect] = try? AVAudioPlayer(contentsOf: url)
            players[effect]?.prepareToPlay()
        }
        players[effect]?.currentTime = 0
        players[effect]?.play()
    }

    static func play(for moment: LapMath.Moment, enabled: Bool) {
        switch moment {
        case .lap, .bonusLap: play(.lap, enabled: enabled)
        case .set: play(.set, enabled: enabled)
        case .goal, .fourSets, .extraSet: play(.goal, enabled: enabled)
        }
    }
}
