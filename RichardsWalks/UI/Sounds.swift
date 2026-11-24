import AudioToolbox

/// Short built-in iOS sounds. They follow the ringer switch, like other app sounds.
enum Sounds {
    static func play(_ moment: LapMath.Moment, enabled: Bool) {
        guard enabled else { return }
        let id: SystemSoundID
        switch moment {
        case .lap, .bonusLap: id = 1057          // soft "tink"
        case .set: id = 1021                     // "Bloom"
        case .goal, .fourSets, .extraSet: id = 1025  // "Fanfare"
        }
        AudioServicesPlaySystemSound(id)
    }
}
