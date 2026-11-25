import SwiftUI
import UIKit

enum Theme {
    static let teal = dynamic(light: 0x168A85, dark: 0x168A85)   // white text stays readable in both modes
    static let darkTeal = dynamic(light: 0x126B67, dark: 0x7FD6CF)
    static let lightTeal = dynamic(light: 0xDDF3EF, dark: 0x1D3836)
    static let background = dynamic(light: 0xFAF7F2, dark: 0x121615)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x1D2322)
    static let text = dynamic(light: 0x2B2D2D, dark: 0xEEF1F0)
    static let secondaryText = dynamic(light: 0x5C6362, dark: 0xA9B3B1)
    static let warm = dynamic(light: 0xE9A23B, dark: 0xF2B65A)   // celebration accent, never a warning
    /// Car walks: bluer and brighter than the lap teal, same family.
    static let turquoise = dynamic(light: 0x1A9CC2, dark: 0x1A9CC2)
    /// Car walks in the ring, dots and chart: a lighter turquoise under the deep teal,
    /// like the cream under the purple. (The button keeps the deeper one for white text.)
    static let carWalk = dynamic(light: 0x5CC3E0, dark: 0x5CC3E0)
    static let darkTurquoise = dynamic(light: 0x13728F, dark: 0x7ACDE6)
    static let lightTurquoise = dynamic(light: 0xDCF0F7, dark: 0x173440)
    /// Standing up: a deep purple with the same weight as the lap teal, the same in both modes.
    static let purple = dynamic(light: 0x6A3FCF, dark: 0x6A3FCF)
    static let darkPurple = dynamic(light: 0x4F2D9E, dark: 0xC4ADF5)
    /// The ring, pills and chart bars: rich enough to hold up on a black screen.
    static let violet = dynamic(light: 0x7A4BDD, dark: 0x7A4BDD)
    static let lightViolet = dynamic(light: 0xECE5FA, dark: 0x2A2240)
    /// The face lotion: creamy, like the lotion itself. Caramel on white so it still shows.
    static let cream = dynamic(light: 0xD8BD8A, dark: 0xF0E4CA)
    static let lightCream = dynamic(light: 0xF7F0E2, dark: 0x37322A)
    static let darkCream = dynamic(light: 0x7A6235, dark: 0xF0E4CA)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Big teal button for the main action.
struct PrimaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 96
    var color: Color = Theme.teal
    var shadow: Color = Theme.darkTeal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(color)
                    .shadow(color: shadow.opacity(0.3), radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Quieter, still-large button for secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 72
    var text: Color = Theme.darkTeal
    var fill: Color = Theme.lightTeal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fill)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.card))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
