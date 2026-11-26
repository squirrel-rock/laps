import SwiftUI

// MARK: - Celebration

struct Celebration: Equatable {
    let id = UUID()
    let moment: LapMath.Moment
    let message: String
    var icon: String?
    /// Shows today's picture in the banner, with the newly uncovered tile appearing.
    var reveal = false
}

struct CelebrationBanner: View {
    let celebration: Celebration
    @State private var burst = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let big = celebration.moment.isBig
        HStack(spacing: 14) {
            ZStack {
                if big && !reduceMotion {
                    ForEach(0..<8, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(i.isMultiple(of: 2) ? Theme.warm : .white)
                            .offset(y: burst ? -34 : 0)
                            .rotationEffect(.degrees(Double(i) * 45))
                            .opacity(burst ? 0 : 1)
                    }
                }
                Image(systemName: celebration.icon ?? (big ? "star.fill" : "hand.thumbsup.fill"))
                    .font(.system(size: big ? 34 : 26, weight: .bold))
                    .foregroundStyle(big ? Theme.warm : .white)
                    .symbolEffect(.bounce, value: burst)
            }
            .frame(width: 48, height: 48)

            Text(celebration.message)
                .font(.system(big ? .title2 : .title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if celebration.reveal { BannerPicture() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, big ? 22 : 16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(UIColor(hex: 0x126B67))))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { burst = true }
            UIAccessibility.post(notification: .announcement, argument: celebration.message)
        }
    }
}

/// A small copy of today's picture in the celebration banner. It starts at the count before
/// this credit, then the new tile fades in once the picture catches up.
private struct BannerPicture: View {
    @Environment(WalkStore.self) private var store
    @Environment(PhotoStore.self) private var photos

    var body: some View {
        let s = photos.settings
        if s.isOn, let p = photos.picture(for: store.todayKey), let r = photos.lastReveal, r.day == p.day {
            TilePicture(image: photos.dayImage(p, .thumb), tiles: s.tiles, revealed: r.count,
                        order: PictureMath.order(tiles: s.tiles, seed: "\(p.day)-\(p.photoID)"))
                .frame(width: 60)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .accessibilityHidden(true)
        }
    }
}

/// The shared celebration: the banner at the top (with today's picture), and confetti for big moments.
struct CelebrationOverlay: ViewModifier {
    @Binding var celebration: Celebration?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if let c = celebration, c.moment.isBig, !reduceMotion {
                    ConfettiView(gold: c.moment == .lucky)
                        .id(c.id)
                        .ignoresSafeArea()
                }
            }
            .overlay(alignment: .top) {
                if let c = celebration {
                    CelebrationBanner(celebration: c)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .id(c.id)
                        .onTapGesture { withAnimation { celebration = nil } }
                }
            }
            .task(id: celebration?.id) {
                guard let c = celebration else { return }
                try? await Task.sleep(for: .seconds(c.moment.isBig ? 4.5 : 2.5))
                withAnimation(.easeOut(duration: 0.4)) {
                    if celebration?.id == c.id { celebration = nil }
                }
            }
    }
}

extension View {
    /// Keeps scrolled content from running under the clock and battery.
    func solidStatusBar() -> some View {
        overlay(alignment: .top) {
            Theme.background.ignoresSafeArea(edges: .top).frame(height: 0)
        }
    }

    func celebrating(_ celebration: Binding<Celebration?>) -> some View {
        modifier(CelebrationOverlay(celebration: celebration))
    }
}

/// "Saved: …" with a big Undo button, shown for 8 seconds after a tap: long enough to find it
/// with a shaky hand.
struct UndoBar: View {
    let text: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(text, systemImage: "checkmark.circle.fill")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(action: undo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.darkTeal)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 56)
                    .background(Capsule().fill(Theme.lightTeal))
            }
            .accessibilityHint("Takes back what you just saved")
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
