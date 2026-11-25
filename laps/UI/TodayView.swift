import SwiftUI

struct TodayView: View {
    @Environment(WalkStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var celebration: Celebration?
    @State private var lastLapTap = Date.distantPast
    @State private var confirmUndo = false
    @State private var lapTick = 0

    /// Taps closer together than this are treated as one (helps with a hand tremor).
    private let doubleTapGuard: TimeInterval = 2.5

    #if DEBUG
    // Debug-only: `-scrollBottom YES` opens scrolled to the bottom (used for screenshots).
    private let startAtBottom = UserDefaults.standard.bool(forKey: "scrollBottom")
    #else
    private let startAtBottom = false
    #endif

    var body: some View {
        let laps = store.lapsToday
        let session = store.active

        ScrollView {
            VStack(spacing: 20) {
                header
                TodayProgressCard(laps: laps)

                if session?.state == .onBreak {
                    breakCard(laps: laps)
                }

                Button(action: recordLap) {
                    Label("Completed a lap!", systemImage: "figure.walk")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(PrimaryButtonStyle(minHeight: 120))
                .accessibilityLabel("Completed a lap")
                .accessibilityHint("Records one lap for today")

                sessionButtons(session: session)

                if laps > 0 {
                    Button {
                        confirmUndo = true
                    } label: {
                        Label("Undo last lap", systemImage: "arrow.uturn.backward")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .accessibilityHint("Removes the most recent lap after you confirm")
                    .padding(.top, 4)
                }

                StandUpCard()
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .defaultScrollAnchor(startAtBottom ? .bottom : .top)
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if let c = celebration, c.moment.isBig, !reduceMotion {
                ConfettiView()
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
        .sensoryFeedback(.success, trigger: lapTick)
        .confirmationDialog("Remove your last lap?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Yes, remove one lap", role: .destructive) { store.undoLastLap() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Today will go from \(laps) to \(max(0, laps - 1)) laps.")
        }
        .task(id: celebration?.id) {
            guard let c = celebration else { return }
            try? await Task.sleep(for: .seconds(c.moment.isBig ? 4.5 : 2.5))
            withAnimation(.easeOut(duration: 0.4)) {
                if celebration?.id == c.id { celebration = nil }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning, Richard"
        case 12..<17: return "Good afternoon, Richard"
        default: return "Good evening, Richard"
        }
    }

    private func breakCard(laps: Int) -> some View {
        VStack(spacing: 14) {
            Label("On a break", systemImage: "pause.circle.fill")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.darkTeal)
            Text("Your \(LapMath.plural(laps, "lap")) \(laps == 1 ? "is" : "are") saved. Take all the time you need — I'll check in after 10 minutes.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Button("I'm back — keep walking") { animate { store.resumeWalking() } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    @ViewBuilder
    private func sessionButtons(session: ActiveSession?) -> some View {
        switch session?.state {
        case .walking:
            VStack(spacing: 12) {
                Button {
                    animate { store.takeBathroomBreak() }
                } label: {
                    Label("Bathroom break", systemImage: "pause.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Saves your laps, pauses, and reminds you in 10 minutes")

                Button {
                    animate { store.finishForNow() }
                    show(Celebration(moment: .lap, message: "All saved. Rest well!", icon: "checkmark.circle.fill"))
                } label: {
                    Label("Finished for now", systemImage: "checkmark")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Ends this walk. Your laps stay saved and you can walk again later.")
            }
        case .onBreak:
            Button {
                animate { store.finishForNow() }
            } label: {
                Label("Finished for now", systemImage: "checkmark")
            }
            .buttonStyle(SecondaryButtonStyle())
        case nil:
            remindLaterSection
        }
    }

    @ViewBuilder
    private var remindLaterSection: some View {
        if let later = store.pendingLater {
            VStack(spacing: 8) {
                Label("I'll remind you at \(later.formatted(date: .omitted, time: .shortened))",
                      systemImage: "bell.fill")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.darkTeal)
                    .multilineTextAlignment(.center)
                Button("Cancel that reminder") { animate { store.cancelRemindLater() } }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(minHeight: 48)
            }
            .card()
        } else {
            Button {
                animate { store.remindMeLater() }
            } label: {
                Label("Remind me later", systemImage: "clock")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("Reminds you to walk in 30 minutes")
        }
    }

    // MARK: - Actions

    private func recordLap() {
        let now = Date()
        guard now.timeIntervalSince(lastLapTap) > doubleTapGuard else { return }
        lastLapTap = now

        let total = animateReturning { store.recordLap() }
        lapTick += 1
        let moment = LapMath.moment(afterLap: total)
        Sounds.play(for: moment, enabled: store.settings.soundOn)
        if moment.isBig { Haptics.celebrate() }
        show(Celebration(moment: moment, message: LapMath.message(afterLap: total)))
    }

    private func show(_ c: Celebration) {
        if reduceMotion {
            celebration = c
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { celebration = c }
        }
    }

    private func animate(_ change: () -> Void) {
        if reduceMotion { change() } else { withAnimation(.spring(response: 0.4, dampingFraction: 0.8), change) }
    }

    private func animateReturning<T>(_ change: () -> T) -> T {
        if reduceMotion { return change() }
        return withAnimation(.spring(response: 0.4, dampingFraction: 0.8), change)
    }
}

// MARK: - Progress card

struct TodayProgressCard: View {
    let laps: Int
    @ScaledMetric(relativeTo: .largeTitle) private var bigNumber: CGFloat = 76
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 210

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Theme.lightTeal, lineWidth: 18)
                Circle()
                    .trim(from: 0, to: LapMath.goalProgress(laps))
                    .stroke(Theme.teal, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if laps > LapMath.dailyGoal {
                    // A warm outer arc for bonus laps toward the 4th set.
                    Circle()
                        .trim(from: 0, to: min(1, Double(laps - LapMath.dailyGoal) / Double(LapMath.bonusGoal - LapMath.dailyGoal)))
                        .stroke(Theme.warm, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-17)
                }
                VStack(spacing: 0) {
                    Text("\(laps)")
                        .font(.system(size: bigNumber, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText(value: Double(laps)))
                    Text("of \(LapMath.dailyGoal) laps")
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .padding(.top, 10)

            SetDots(laps: laps)

            VStack(spacing: 6) {
                Text(LapMath.setsDescription(laps))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text(LapMath.statusLine(laps))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.darkTeal)
            }
            .multilineTextAlignment(.center)
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today: \(laps) of \(LapMath.dailyGoal) laps. \(LapMath.setsDescription(laps)). \(LapMath.statusLine(laps))")
    }
}

/// Three dots per set. The 4th set is drawn dashed: there if he wants it, never required.
struct SetDots: View {
    let laps: Int

    var body: some View {
        let groups = max(4, Int(ceil(Double(laps) / 3)))
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
            ForEach(0..<groups, id: \.self) { g in
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        let index = g * 3 + i
                        let filled = index < laps
                        let bonus = g >= 3
                        Circle()
                            .fill(filled ? (bonus ? Theme.warm : Theme.teal) : Color.clear)
                            .overlay(
                                Circle().strokeBorder(
                                    bonus ? Theme.warm : Theme.teal.opacity(0.45),
                                    style: StrokeStyle(lineWidth: 2, dash: bonus && !filled ? [3, 3] : []))
                            )
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(6)
                .background(Capsule().fill(Theme.lightTeal.opacity(0.5)))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Celebration

struct Celebration: Equatable {
    let id = UUID()
    let moment: LapMath.Moment
    let message: String
    var icon: String?
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
