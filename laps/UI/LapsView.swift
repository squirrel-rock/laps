import SwiftUI

/// The Laps screen: laps and walks to the car, toward 10 walking credits a day.
struct LapsView: View {
    @Environment(WalkStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var celebration: Celebration?
    @State private var lastTap = Date.distantPast
    @State private var confirmUndo = false
    @State private var lapTick = 0
    @State private var justAddedCarWalk: EverydayEntry?

    /// Taps closer together than this are treated as one, which catches an accidental
    /// tremor double-tap but still lets him log laps quickly: tap, tap, tap.
    private let doubleTapGuard: TimeInterval = 0.6

    var body: some View {
        let laps = store.lapsToday

        ScrollView {
            VStack(spacing: 20) {
                header
                TodayProgressCard(laps: laps, carWalks: store.carWalksToday)

                Button(action: recordLap) {
                    Label("Completed a lap!", systemImage: "figure.walk")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(PrimaryButtonStyle(minHeight: 120))
                .accessibilityLabel("Completed a lap")
                .accessibilityHint("Records one lap for today")

                sessionButtons

                // Kept well below the lap button, so a shaky tap can't land on the wrong one.
                Button(action: recordCarWalk) {
                    Label("Walked to the car", systemImage: "car.fill")
                }
                .buttonStyle(PrimaryButtonStyle(minHeight: 88, color: Theme.turquoise, shadow: Theme.darkTurquoise))
                .accessibilityHint("Counts toward today's 10, like a lap")
                .padding(.top, 12)

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
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .solidStatusBar()
        .celebrating($celebration)
        .safeAreaInset(edge: .bottom) {
            if let added = justAddedCarWalk {
                UndoBar(text: "Saved: walk to the car") {
                    withAnimation {
                        store.deleteEveryday(added.id, on: store.todayKey)
                        justAddedCarWalk = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: lapTick)
        .confirmationDialog("Remove your last lap?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Yes, remove one lap", role: .destructive) { store.undoLastLap() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Today will go from \(laps) to \(max(0, laps - 1)) laps.")
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

    /// "Finished for now" while a walk is going; otherwise "Remind me later".
    @ViewBuilder
    private var sessionButtons: some View {
        if store.active != nil {
            Button {
                animate { store.finishForNow() }
                show(Celebration(moment: .lap, message: "All saved. Rest well!", icon: "checkmark.circle.fill"))
            } label: {
                Label("Finished for now", systemImage: "checkmark")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("Ends this walk. Your laps stay saved and you can walk again later.")
        } else if let later = store.pendingLater {
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

    private func tapAllowed() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastTap) > doubleTapGuard else { return false }
        lastTap = now
        return true
    }

    private func recordLap() {
        guard tapAllowed() else { return }
        let total = animateReturning { store.recordLap() }
        let carWalks = store.carWalksToday
        lapTick += 1
        let moment = LapMath.moment(afterLap: total, carWalks: carWalks)
        Sounds.playLap(total: total, carWalks: carWalks, enabled: store.settings.soundOn)
        if moment.isBig { Haptics.celebrate() }
        show(Celebration(moment: moment, message: LapMath.message(afterLap: total, carWalks: carWalks),
                         icon: moment == .lucky ? "sparkles" : nil, reveal: true))
    }

    private func recordCarWalk() {
        guard tapAllowed(), let entry = animateReturning({ store.addEveryday(EverydayEntry.carWalk) }) else { return }
        lapTick += 1
        let credits = store.walkingCreditsToday
        let moment: LapMath.Moment = credits == LapMath.dailyGoal ? .goal
            : credits == LapMath.luckyNumber ? .lucky : (credits > LapMath.dailyGoal ? .bonusLap : .lap)
        Sounds.play(moment.isBig ? .goal : .lapC, enabled: store.settings.soundOn)
        if moment.isBig { Haptics.celebrate() }
        let message: String
        switch moment {
        case .goal: message = "Ten today. Goal reached!"
        case .lucky: message = "Thirteen! A lucky number."
        default: message = "A walk to the car! That's \(credits) today."
        }
        show(Celebration(moment: moment, message: message, icon: moment.isBig ? nil : "car.fill", reveal: true))
        withAnimation { justAddedCarWalk = entry }
        Task {
            try? await Task.sleep(for: .seconds(8))
            withAnimation { if justAddedCarWalk?.id == entry.id { justAddedCarWalk = nil } }
        }
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
    /// Walks to the car and back today.
    let carWalks: Int
    @ScaledMetric(relativeTo: .largeTitle) private var bigNumber: CGFloat = 76
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 210
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The gold bonus (outer ring + 3 dots) only appears once he reaches 10.
    @State private var showGold = false
    /// The one-time "drawn around the 10" sweep when he first reaches it.
    @State private var sweep: CGFloat = 0
    @State private var sweepOpacity: Double = 0
    @State private var revealTask: Task<Void, Never>?

    private var credits: Int { laps + carWalks }
    private var reachedGoal: Bool { credits >= LapMath.dailyGoal }
    private var bonus: Int { max(0, credits - LapMath.dailyGoal) }

    var body: some View {
        let goal = Double(LapMath.dailyGoal)

        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Theme.lightTeal, lineWidth: 18)
                // Laps on top of the car walks, so the turquoise start stays visible.
                Circle()
                    .trim(from: 0, to: LapMath.goalProgress(credits))
                    .stroke(Theme.teal, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if carWalks > 0 {
                    Circle()
                        .trim(from: 0, to: min(1, Double(carWalks) / goal))
                        .stroke(Theme.carWalk, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                goldRing
                VStack(spacing: 0) {
                    Text("\(credits)")
                        .font(.system(size: bigNumber, weight: .bold, design: .rounded))
                        .foregroundStyle(credits >= LapMath.luckyNumber ? Theme.warm : Theme.text)
                        .contentTransition(.numericText(value: Double(credits)))
                    Text("of \(LapMath.dailyGoal) today")
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .padding(14)

            SetDots(laps: laps, carWalks: carWalks, showGold: showGold)

            VStack(spacing: 6) {
                Text(LapMath.walkingDescription(laps: laps, carWalks: carWalks))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text(LapMath.statusLine(credits: credits))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.darkTeal)
            }
            .multilineTextAlignment(.center)
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Walking today: \(credits) of \(LapMath.dailyGoal). \(LapMath.walkingDescription(laps: laps, carWalks: carWalks)). \(LapMath.statusLine(credits: credits))")
        .onAppear { showGold = reachedGoal }
        .onChange(of: reachedGoal) { _, reached in
            reached ? revealGold() : hideGold()
        }
    }

    /// Gold outer ring in 3 segments, one per bonus lap toward 13.
    private var goldRing: some View {
        ZStack {
            if showGold {
                ForEach(0..<3, id: \.self) { k in
                    let gap = 0.015
                    let from = Double(k) / 3 + gap, to = Double(k + 1) / 3 - gap
                    Circle()
                        .trim(from: from, to: to)
                        .stroke(Theme.warm.opacity(0.3), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    Circle()
                        .trim(from: from, to: bonus > k ? to : from)
                        .stroke(Theme.warm, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                }
                .transition(.opacity)
            }
            // The sweep: a solid gold ring drawn around the 10, which then fades away.
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(Theme.warm, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .opacity(sweepOpacity)
        }
        .rotationEffect(.degrees(-90))
        .padding(-24)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: bonus)
    }

    private func revealGold() {
        revealTask?.cancel()
        if reduceMotion {
            withAnimation(.easeIn(duration: 0.4)) { showGold = true }
            return
        }
        revealTask = Task { @MainActor in
            // Let the goal fanfare and confetti have their moment first.
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            sweep = 0
            sweepOpacity = 1
            withAnimation(.easeInOut(duration: 1.1)) { sweep = 1 }
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.9)) {
                sweepOpacity = 0
                showGold = true
            }
        }
    }

    private func hideGold() {
        revealTask?.cancel()
        sweepOpacity = 0
        sweep = 0
        withAnimation(.easeOut(duration: 0.3)) { showGold = false }
    }
}

/// Turquoise dots for car walks come first (only once recorded), then teal dots up to the
/// goal of 10, grouped in threes. Once he reaches 10, a gold group of 3 appears: 13 is the
/// lucky number. Past 13, more gold dots keep appearing.
struct SetDots: View {
    let laps: Int
    let carWalks: Int
    let showGold: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let groups = LapMath.goalGroups(carWalks: carWalks)
        let needed = LapMath.lapsNeeded(carWalks: carWalks)
        let goldLaps = max(0, laps - needed)
        let goldGroups = showGold ? max(1, Int(ceil(Double(goldLaps) / 3))) : 0
        let pop: AnyTransition = reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity)

        FlowLayout(spacing: 10) {
            if carWalks > 0 {
                HStack(spacing: 5) {
                    ForEach(0..<carWalks, id: \.self) { _ in
                        dot(filled: true, color: Theme.carWalk)
                            .transition(pop)
                    }
                }
                .padding(6)
                .background(Capsule().fill(Theme.lightTurquoise))
                .transition(pop)
            }
            ForEach(groups.indices, id: \.self) { g in
                let start = groups.prefix(g).reduce(0, +)
                HStack(spacing: 5) {
                    ForEach(0..<groups[g], id: \.self) { i in
                        dot(filled: start + i < laps, color: Theme.teal)
                    }
                }
                .padding(6)
                .background(Capsule().fill(Theme.lightTeal.opacity(0.5)))
            }
            ForEach(0..<goldGroups, id: \.self) { g in
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        dot(filled: g * 3 + i < goldLaps, color: Theme.warm, dashed: true)
                    }
                }
                .padding(6)
                .background(Capsule().fill(Theme.warm.opacity(0.15)))
                .transition(pop)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: carWalks)
        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.6), value: showGold)
        .accessibilityHidden(true)
    }

    private func dot(filled: Bool, color: Color, dashed: Bool = false) -> some View {
        Circle()
            .fill(filled ? color : Color.clear)
            .overlay(
                Circle().strokeBorder(
                    filled ? color : color.opacity(dashed ? 1 : 0.45),
                    style: StrokeStyle(lineWidth: 2, dash: dashed && !filled ? [3, 3] : []))
            )
            .frame(width: 16, height: 16)
    }
}

/// Lays children out left to right, wrapping to a new centered row when one fills up.
struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [], row = Row()
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let extra = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if !row.items.isEmpty && extra > width {
                rows.append(row)
                row = Row()
            }
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append(i)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

