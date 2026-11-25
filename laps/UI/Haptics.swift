import CoreHaptics
import UIKit

/// A celebratory "da-da-DAH!" he can feel in his hand when he completes a set.
@MainActor
enum Haptics {
    private static var engine: CHHapticEngine?

    static func celebrate() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            if engine == nil {
                let e = try CHHapticEngine()
                e.resetHandler = { [weak e] in try? e?.start() }
                engine = e
            }
            try engine?.start()

            func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ], relativeTime: time)
            }
            let events = [
                tap(0.00, 0.6, 0.5),
                tap(0.14, 0.7, 0.6),
                tap(0.30, 1.0, 0.9),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                ], relativeTime: 0.32, duration: 0.35),
            ]
            let player = try engine?.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
