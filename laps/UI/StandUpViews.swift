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
                .foregroundStyle(Theme.teal)
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
                .foregroundStyle(Theme.teal)
                .symbolEffect(.bounce, value: picked)
                .accessibilityHidden(true)
            Text("Off you go!")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
            Text(choice.title)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.darkTeal)
                .multilineTextAlignment(.center)
            Text("Tap Done when you're back.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            Button {
                let count = store.completeStandUp()
                Sounds.play(.standup, enabled: store.settings.soundOn)
                withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { finishedCount = count }
            } label: {
                Label("Done!", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle(minHeight: 110))
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
            Text(count == 1 ? "That's your first stand-up today." : "That's \(count) stand-ups today.")
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(Theme.darkTeal)
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
            .foregroundStyle(Theme.darkTeal)
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
                    .strokeBorder(highlight ? Theme.warm : Theme.teal.opacity(0.35), lineWidth: highlight ? 3 : 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Stand-ups and the face lotion, on the Today screen.
struct StandUpCard: View {
    @Environment(WalkStore.self) private var store

    var body: some View {
        let count = store.standUpsDoneToday

        VStack(alignment: .leading, spacing: 16) {
            Label("Stand-ups", systemImage: "figure.stand")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)

            Text(count == 0 ? "Ready for your first stand-up?" : "You've stood up \(count == 1 ? "once" : "\(count) times") today.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Theme.darkTeal)

            if let pending = store.pendingStandUp {
                VStack(alignment: .leading, spacing: 10) {
                    Text("You picked:")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Text(pending.title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.text)
                    Button {
                        store.completeStandUp()
                        Sounds.play(.standup, enabled: store.settings.soundOn)
                    } label: {
                        Label("Done!", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle(minHeight: 84))
                    Button("Skip this one") { store.skipPendingStandUp() }
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            } else {
                Button {
                    store.showStandUpPicker()
                } label: {
                    Label("Stand up now", systemImage: "figure.stand")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Divider()

            if store.lotionDoneToday {
                HStack {
                    Label("Face lotion: done today", systemImage: "checkmark.circle.fill")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.darkTeal)
                    Spacer()
                    Button("Undo") { store.setLotionDone(false) }
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minWidth: 60, minHeight: 48)
                        .accessibilityLabel("Undo face lotion done")
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Face lotion: not yet today", systemImage: "face.smiling")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.text)
                    Button {
                        store.setLotionDone(true)
                        Sounds.play(.standup, enabled: store.settings.soundOn)
                    } label: {
                        Label("I've put it on", systemImage: "checkmark")
                    }
                    .buttonStyle(SecondaryButtonStyle(minHeight: 64))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Gentle confetti for big moments (a set, the goal, four sets).
struct ConfettiView: View {
    @State private var fall = false
    private let pieces: [(x: CGFloat, delay: Double, spin: Double, color: Color, size: CGFloat)] = (0..<36).map { i in
        (CGFloat.random(in: 0...1), Double.random(in: 0...0.5), Double.random(in: 180...720),
         [Theme.teal, Theme.warm, Theme.lightTeal, Color(UIColor(hex: 0xF28C8C))][i % 4],
         CGFloat.random(in: 7...12))
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
