import SwiftUI

/// The violet activities ring at the top of the Activities screen, with its pills and status line.
/// Face washes start the ring in cream, like car walks do for walking.
struct ActivityRingCard: View {
    let credits: Int
    let goal: Int
    let lotions: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 170
    @ScaledMetric(relativeTo: .largeTitle) private var bigNumber: CGFloat = 60

    var body: some View {
        VStack(spacing: 16) {
            ring
            StandingPills(credits: credits, goal: goal, lotions: lotions)
            Text(StandingMath.statusLine(credits, goal: goal))
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.darkPurple)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activities today: \(credits) of \(goal). \(StandingMath.statusLine(credits, goal: goal))")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.lightViolet, lineWidth: 16)
            Circle()
                .trim(from: 0, to: StandingMath.progress(credits, goal: goal))
                .stroke(Theme.violet, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if lotions > 0 {
                Circle()
                    .trim(from: 0, to: StandingMath.progress(lotions, goal: goal))
                    .stroke(Theme.cream, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if credits > goal {
                Circle()
                    .stroke(Theme.warm, lineWidth: 6)
                    .padding(-16)
                    .transition(.opacity)
            }
            VStack(spacing: 0) {
                Text("\(credits)")
                    .font(.system(size: bigNumber, weight: .bold, design: .rounded))
                    .foregroundStyle(credits > goal ? Theme.warm : Theme.text)
                    .contentTransition(.numericText(value: Double(credits)))
                Text("of \(goal) today")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .padding(12)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75), value: credits)
    }
}

/// Cream pills for the face washes done, violet pills up to the goal in groups of 5,
/// then gold pills for every extra activity.
struct StandingPills: View {
    let credits: Int
    let goal: Int
    let lotions: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let others = max(0, credits - lotions)
        let groups = StandingMath.goalGroups(goal: goal, lotions: lotions)
        let violetSlots = groups.reduce(0, +)
        let gold = max(0, others - violetSlots)
        let goldGroups = Int(ceil(Double(gold) / Double(StandingMath.perGroup)))
        let pop: AnyTransition = reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity)

        FlowLayout(spacing: 10) {
            if lotions > 0 {
                HStack(spacing: 5) {
                    ForEach(0..<lotions, id: \.self) { _ in pill(filled: true, color: Theme.cream) }
                }
                .padding(6)
                .background(Capsule().fill(Theme.lightCream))
                .transition(pop)
            }
            ForEach(groups.indices, id: \.self) { g in
                let start = groups.prefix(g).reduce(0, +)
                HStack(spacing: 5) {
                    ForEach(0..<groups[g], id: \.self) { i in
                        pill(filled: start + i < others, color: Theme.violet)
                    }
                }
                .padding(6)
                .background(Capsule().fill(Theme.lightViolet.opacity(0.7)))
            }
            ForEach(0..<goldGroups, id: \.self) { g in
                HStack(spacing: 5) {
                    ForEach(0..<min(StandingMath.perGroup, gold - g * StandingMath.perGroup), id: \.self) { _ in
                        pill(filled: true, color: Theme.warm)
                            .transition(pop)
                    }
                }
                .padding(6)
                .background(Capsule().fill(Theme.warm.opacity(0.15)))
                .transition(pop)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: credits)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: lotions)
        .accessibilityHidden(true)
    }

    private func pill(filled: Bool, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(filled ? color : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(filled ? color : color.opacity(0.5), lineWidth: 2)
            )
            .frame(width: 12, height: 24)
    }
}

struct ConfettiView: View {
    @State private var fall = false
    private let pieces: [(x: CGFloat, delay: Double, spin: Double, color: Color, size: CGFloat)]

    /// `gold`: a bigger, all-gold shower for 13.
    init(gold: Bool = false) {
        let colors = gold
            ? [Theme.warm, Color(UIColor(hex: 0xFFD66B)), Color(UIColor(hex: 0xF5B83D)), .white]
            : [Theme.teal, Theme.warm, Theme.lightTeal, Color(UIColor(hex: 0xF28C8C))]
        pieces = (0..<(gold ? 64 : 36)).map { i in
            (CGFloat.random(in: 0...1), Double.random(in: 0...(gold ? 0.9 : 0.5)), Double.random(in: 180...720),
             colors[i % colors.count], CGFloat.random(in: 7...(gold ? 14 : 12)))
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(fall ? p.spin : 0))
                    .position(x: p.x * geo.size.width, y: fall ? geo.size.height + 40 : -20)
                    .opacity(fall ? 0.2 : 1)
                    .animation(.easeIn(duration: 2.4).delay(p.delay), value: fall)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fall = true }
    }
}
