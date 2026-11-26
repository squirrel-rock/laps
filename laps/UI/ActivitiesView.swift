import SwiftUI

/// The Activities screen: everything Richard can get up for, recorded with one tap.
/// Daily activities and extra accomplishments are checked off and move to Completed today;
/// anytime activities can be done again and again, with a count.
struct ActivitiesView: View {
    @Environment(WalkStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var celebration: Celebration?
    @State private var justSaved: StandUpEntry?
    @State private var lastTap = Date.distantPast
    @State private var tick = 0

    /// One pause shared by every button on the screen. When a checked item moves down,
    /// the next row slides up under his finger; a shaky second tap mustn't record that one too.
    private let tapGuard: TimeInterval = 1.0

    var body: some View {
        let daily = Activities.daily.filter { !store.isDone($0) }
        let extra = Activities.extra.filter { !store.isDone($0) }
        let completed = store.completedToday

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ActivityRingCard(credits: store.standingCreditsToday, goal: store.standingGoal,
                                 lotions: store.today.lotions)

                sectionTitle("Daily activities", "Things to do every day.")
                if daily.isEmpty {
                    allDone("All of today's daily activities are done!")
                } else {
                    ForEach(daily) { a in
                        ActivityRow(activity: a, count: 0, amber: store.needsAttention(a),
                                    prominent: a == Activities.morningLotion) { record(a) }
                    }
                }

                sectionTitle("Extra accomplishments", "No pressure. A real achievement when you do.")
                if extra.isEmpty {
                    allDone("Both done today. Wonderful!")
                } else {
                    ForEach(extra) { a in
                        ActivityRow(activity: a, count: 0, amber: false) { record(a) }
                    }
                }

                sectionTitle("Anytime", "As often as you like. Each time counts.")
                ForEach(Activities.anytime + [Activities.somethingElse]) { a in
                    ActivityRow(activity: a, count: store.count(a), amber: false) { record(a) }
                }

                sectionTitle("Completed today", nil)
                if completed.isEmpty {
                    Text("Nothing yet today. Your first one will show here.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(completed) { e in
                            CompletedRow(entry: e) { undo(e) }
                            if e.id != completed.last?.id { Divider().padding(.leading, 60) }
                        }
                    }
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .solidStatusBar()
        .celebrating($celebration)
        .safeAreaInset(edge: .bottom) {
            if let e = justSaved {
                UndoBar(text: "Saved: \(e.title)") { undo(e) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: tick)
    }

    // MARK: - Pieces

    private var header: some View {
        Text("Activities")
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .accessibilityAddTraits(.isHeader)
    }

    private func sectionTitle(_ title: String, _ note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            if let note {
                Text(note)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 4)
    }

    private func allDone(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.seal.fill")
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.darkPurple)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.lightViolet))
    }

    // MARK: - Actions

    private func tapAllowed() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastTap) > tapGuard else { return false }
        lastTap = now
        return true
    }

    private func record(_ activity: Activity) {
        guard tapAllowed() else { return }
        let entry = reduceMotion ? store.record(activity)
            : withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { store.record(activity) }
        guard let entry else { return }
        tick += 1
        cheer(for: activity)
        withAnimation { justSaved = entry }
        Task {
            try? await Task.sleep(for: .seconds(8))
            withAnimation { if justSaved?.id == entry.id { justSaved = nil } }
        }
    }

    private func undo(_ entry: StandUpEntry) {
        guard tapAllowed() else { return }
        withAnimation {
            store.undo(entry)
            if justSaved?.id == entry.id { justSaved = nil }
        }
    }

    /// Sound, vibration and the banner (with the picture) for a new activity.
    /// Extra accomplishments get a bigger cheer of their own.
    private func cheer(for activity: Activity) {
        let credits = store.standingCreditsToday, goal = store.standingGoal
        let moment = StandingMath.moment(after: credits, goal: goal)
        let isExtra = activity.kind == .extra
        let big = moment == .goal || isExtra
        Sounds.play(big ? .goal : .standup, enabled: store.settings.soundOn)
        if big { Haptics.celebrate() }

        let message: String
        if moment == .goal { message = StandingMath.message(after: credits, goal: goal) }
        else if isExtra { message = Activities.extraCheer(credits) }
        else { message = StandingMath.message(after: credits, goal: goal) }

        let c = Celebration(moment: moment == .goal ? .goal : (isExtra ? .set : .lap),
                            message: message,
                            icon: big ? nil : activity.icon, reveal: true)
        if reduceMotion { celebration = c }
        else { withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { celebration = c } }
    }
}

/// One activity: a big card that records it with a single tap.
struct ActivityRow: View {
    let activity: Activity
    /// Times done today (anytime activities only).
    let count: Int
    /// Unfinished and worth a gentle nudge.
    let amber: Bool
    /// The morning face wash: larger, until it's done.
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: activity.icon)
                    .font(.system(size: prominent ? 30 : 24, weight: .semibold))
                    .foregroundStyle(amber ? Theme.amber : (prominent ? Theme.darkCream : Theme.purple))
                    .frame(width: prominent ? 56 : 48, height: prominent ? 56 : 48)
                    .background(Circle().fill(amber ? Theme.lightAmber : (prominent ? Theme.lightCream : Theme.lightViolet)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.subject)
                        .font(.system(prominent ? .title2 : .title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.text)
                    if let action = activity.action {
                        Text(action)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    if amber {
                        Text("Still to do today")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.amber)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, prominent ? 18 : 12)
            .frame(maxWidth: .infinity, minHeight: prominent ? 96 : 76)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(prominent && !amber ? Theme.lightCream : Theme.card)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(amber ? Theme.amber : (prominent ? Theme.cream : .clear), lineWidth: 3)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(activity.isCheckable ? "Checks it off. Counts as one activity." : "Records one more. Counts as one activity.")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var trailing: some View {
        if activity.isCheckable {
            Image(systemName: "circle")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(amber ? Theme.amber : Theme.violet.opacity(0.6))
        } else {
            HStack(spacing: 8) {
                if count > 0 {
                    Text("\(count)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 36, minHeight: 36)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Theme.violet))
                        .contentTransition(.numericText(value: Double(count)))
                }
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.violet.opacity(0.85))
            }
        }
    }

    private var accessibilityText: String {
        var parts = [activity.title]
        if activity.isCheckable { parts.append(amber ? "Still to do today" : "Not done yet") }
        else if count > 0 { parts.append("\(count) time\(count == 1 ? "" : "s") today") }
        return parts.joined(separator: ". ")
    }
}

/// A done activity in Completed today, with its time and an Undo.
struct CompletedRow: View {
    let entry: StandUpEntry
    let undo: () -> Void

    var body: some View {
        let activity = Activities.activity(id: entry.choiceID)
        let time = (entry.doneAt ?? entry.picked).formatted(date: .omitted, time: .shortened)
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(activity?.kind == .extra ? Theme.warm : Theme.violet)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text(time)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo", action: undo)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .frame(minWidth: 64, minHeight: 48)
                .accessibilityLabel("Undo \(entry.title) at \(time)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

/// A soft press effect for the activity cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
