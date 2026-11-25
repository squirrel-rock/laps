import SwiftUI

/// Three big choices. Picking one is the commitment; "Done!" afterwards counts it.
struct StandUpPickerView: View {
    @Environment(WalkStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let choices: [StandUpChoice]

    @State private var picked: StandUpChoice?
    @State private var finishedCount: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let count = finishedCount {
                    finished(count: count)
                } else if let choice = picked {
                    offYouGo(choice)
                } else {
                    chooser
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Theme.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: picked)
        .sensoryFeedback(.success, trigger: finishedCount)
    }

    private var chooser: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.stand")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .accessibilityHidden(true)
            Text("Time to stand up, Richard!")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text("Pick one, then off you go.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            ForEach(choices) { choice in
                Button {
                    store.pickStandUp(choice)
                    withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { picked = choice }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: choice.icon)
                            .font(.system(size: 30, weight: .semibold))
                            .frame(width: 44)
                            .accessibilityHidden(true)
                        Text(choice.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(ChoiceButtonStyle(highlight: choice.kind == .lotion))
            }

            Button("Not right now") {
                store.standUpPrompt = nil
                dismiss()
            }
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 56)
        }
    }

    private func offYouGo(_ choice: StandUpChoice) -> some View {
        VStack(spacing: 22) {
            Image(systemName: choice.icon)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .symbolEffect(.bounce, value: picked)
                .accessibilityHidden(true)
            Text("Off you go!")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
            Text(choice.title)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.darkPurple)
                .multilineTextAlignment(.center)
            Text("Tap Done when you're back.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            Button {
                let count = store.completeStandUp()
                let reachedGoal = count == store.standingGoal
                Sounds.play(reachedGoal ? .goal : .standup, enabled: store.settings.soundOn)
                if reachedGoal { Haptics.celebrate() }
                withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { finishedCount = count }
            } label: {
                Label("Done!", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle(minHeight: 110, color: Theme.purple, shadow: Theme.darkPurple))
            .padding(.top, 8)

            Button("I'll tap Done later") {
                store.standUpPrompt = nil
                dismiss()
            }
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .padding(.top, 20)
    }

    private func finished(count: Int) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "star.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Theme.warm)
                .symbolEffect(.bounce, value: finishedCount)
                .accessibilityHidden(true)
            Text("Nicely done!")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
            Text(count == store.standingGoal ? "That's \(count) times up today. Goal reached!"
                 : count == 1 ? "That's your first time up today." : "That's \(count) times up today.")
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(Theme.darkPurple)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .task {
            UIAccessibility.post(notification: .announcement, argument: "Nicely done!")
            try? await Task.sleep(for: .seconds(2.5))
            store.standUpPrompt = nil
            dismiss()
        }
    }
}

struct ChoiceButtonStyle: ButtonStyle {
    var highlight = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.darkPurple)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(highlight ? Theme.cream : Theme.violet.opacity(0.45), lineWidth: highlight ? 3 : 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The violet Standing up section on the Today screen: a ring, pills, and one big button.
struct StandingUpCard: View {
    @Environment(WalkStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Shows the shared celebration banner (and confetti at the goal) on the Today screen.
    var celebrate: (Celebration) -> Void = { _ in }

    @State private var lastTap = Date.distantPast
    @State private var justStood: StandUpEntry?
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 150
    @ScaledMetric(relativeTo: .largeTitle) private var bigNumber: CGFloat = 54

    /// Same tremor guard as the lap button.
    private let doubleTapGuard: TimeInterval = 0.6

    var body: some View {
        let credits = store.standingCreditsToday
        let goal = store.standingGoal
        let lotion = store.lotionDoneToday

        VStack(spacing: 18) {
            Label("Standing up", systemImage: "figure.stand")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                ring(credits: credits, goal: goal, lotion: lotion)
                StandingPills(credits: credits, goal: goal, lotionDone: lotion)
                Text(StandingMath.statusLine(credits, goal: goal))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.darkPurple)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Standing up today: \(credits) of \(goal).\(lotion ? " Face lotion done." : "") \(StandingMath.statusLine(credits, goal: goal))")

            if let pending = store.pendingStandUp {
                pendingChoice(pending)
            } else {
                Button(action: stoodUp) {
                    Label("I stood up", systemImage: "figure.stand")
                }
                .buttonStyle(PrimaryButtonStyle(minHeight: 100, color: Theme.purple, shadow: Theme.darkPurple))
                .accessibilityHint("Records one time standing up")

                if let entry = justStood {
                    Button {
                        withAnimation {
                            store.deleteStandUp(entry.id, on: store.todayKey)
                            justStood = nil
                        }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .accessibilityHint("Removes the time you just recorded")
                    .transition(.opacity)
                }

                Button {
                    store.showStandUpPicker()
                } label: {
                    Label("Give me an idea", systemImage: "lightbulb")
                }
                .buttonStyle(SecondaryButtonStyle(minHeight: 64, text: Theme.darkPurple, fill: Theme.lightViolet))
                .accessibilityHint("Shows three things to stand up for")
            }

            lotionRow(done: lotion)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: - Pieces

    private func ring(credits: Int, goal: Int, lotion: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.lightViolet, lineWidth: 14)
            Circle()
                .trim(from: 0, to: StandingMath.progress(credits, goal: goal))
                .stroke(Theme.violet, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if lotion {
                // The face lotion starts the ring, like the car walk does for walking.
                Circle()
                    .trim(from: 0, to: StandingMath.progress(1, goal: goal))
                    .stroke(Theme.cream, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if credits > goal {
                Circle()
                    .stroke(Theme.warm, lineWidth: 6)
                    .padding(-14)
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
        .padding(10)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75), value: credits)
    }

    private func pendingChoice(_ pending: StandUpEntry) -> some View {
        VStack(spacing: 10) {
            Text("You picked:")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            Text(pending.title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Button {
                store.completeStandUp()
                cheer()
            } label: {
                Label("Done!", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle(minHeight: 100, color: Theme.purple, shadow: Theme.darkPurple))
            Button("Skip this one") { store.skipPendingStandUp() }
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
    }

    @ViewBuilder
    private func lotionRow(done: Bool) -> some View {
        if done {
            HStack {
                Label("Face lotion: done today", systemImage: "checkmark.circle.fill")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.darkCream)
                Spacer()
                Button("Undo") { store.setLotionDone(false) }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(minWidth: 60, minHeight: 48)
                    .accessibilityLabel("Undo face lotion done")
            }
        } else {
            Button {
                store.setLotionDone(true)
                cheer()
            } label: {
                Label("I put on my face lotion", systemImage: "face.smiling")
            }
            .buttonStyle(SecondaryButtonStyle(minHeight: 64, text: Theme.darkCream, fill: Theme.lightCream))
            .accessibilityHint("Counts as one time standing up")
        }
    }

    // MARK: - Actions

    private func stoodUp() {
        let now = Date()
        guard now.timeIntervalSince(lastTap) > doubleTapGuard else { return }
        lastTap = now

        let entry = store.recordStoodUp()
        cheer()
        withAnimation { justStood = entry }
        Task {
            // Long enough to find the Undo button with a shaky hand.
            try? await Task.sleep(for: .seconds(8))
            withAnimation { if justStood?.id == entry.id { justStood = nil } }
        }
    }

    /// Sound, vibration and the banner for a new standing-up credit.
    private func cheer() {
        let credits = store.standingCreditsToday, goal = store.standingGoal
        let moment = StandingMath.moment(after: credits, goal: goal)
        let soundOn = store.settings.soundOn
        Sounds.play(moment == .goal ? .goal : .standup, enabled: soundOn)
        if moment == .goal { Haptics.celebrate() }
        celebrate(Celebration(moment: moment == .goal ? .goal : .lap,
                              message: StandingMath.message(after: credits, goal: goal),
                              icon: moment == .goal ? nil : "figure.stand"))
    }
}

/// One cream pill for the face lotion (once it's done), violet pills up to the goal in
/// groups of 5, then gold pills for every extra time up.
struct StandingPills: View {
    let credits: Int
    let goal: Int
    let lotionDone: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let others = max(0, credits - (lotionDone ? 1 : 0))
        let groups = StandingMath.goalGroups(goal: goal, lotionDone: lotionDone)
        let violetSlots = groups.reduce(0, +)
        let gold = max(0, others - violetSlots)
        let goldGroups = Int(ceil(Double(gold) / Double(StandingMath.perGroup)))
        let pop: AnyTransition = reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity)

        FlowLayout(spacing: 10) {
            if lotionDone {
                pill(filled: true, color: Theme.cream)
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
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: lotionDone)
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
