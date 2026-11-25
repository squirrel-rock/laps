import SwiftUI

/// Everyday walking. A walk to the car and back earns a turquoise walking credit
/// toward today's 10; "Something else…" is just a note.
struct EverydayView: View {
    @Environment(WalkStore.self) private var store
    @State private var showingCustom = false
    @State private var customNote = ""
    @State private var justAdded: EverydayEntry?
    @State private var lastTap = Date.distantPast

    /// Same tremor guard as the lap button.
    private let doubleTapGuard: TimeInterval = 0.6

    var body: some View {
        let recent = store.recordedDays.filter { !$0.everyday.isEmpty }.prefix(14)

        List {
            Section {
                VStack(spacing: 12) {
                    Text("A walk to the car and back counts toward today's 10, as a turquoise dot.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        add(EverydayEntry.carWalk)
                    } label: {
                        Label(EverydayEntry.carWalk, systemImage: "car.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(minHeight: 88, color: Theme.turquoise, shadow: Theme.darkTurquoise))

                    Button {
                        customNote = ""
                        showingCustom = true
                    } label: {
                        Label("Something else…", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if let added = justAdded {
                        VStack(spacing: 4) {
                            Label("Saved: \(added.note)", systemImage: "checkmark.circle.fill")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.darkTurquoise)
                                .multilineTextAlignment(.center)
                            Button {
                                withAnimation {
                                    store.deleteEveryday(added.id, on: store.todayKey)
                                    justAdded = nil
                                }
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                                    .font(.system(.title3, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .accessibilityHint("Removes what you just saved")
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            ForEach(Array(recent), id: \.day) { day in
                Section(sectionTitle(day.day)) {
                    ForEach(day.everyday.sorted { $0.time > $1.time }) { e in
                        HStack {
                            Text(e.note)
                            Spacer()
                            Text(e.time.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete { offsets in
                        let sorted = day.everyday.sorted { $0.time > $1.time }
                        for i in offsets { store.deleteEveryday(sorted[i].id, on: day.day) }
                    }
                }
            }
        }
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Everyday walking")
        .toolbar { if !recent.isEmpty { EditButton() } }
        .alert("What did you do?", isPresented: $showingCustom) {
            TextField("e.g. Walked to the kitchen", text: $customNote)
            Button("Save") { add(customNote) }
            Button("Cancel", role: .cancel) {}
        }
        .sensoryFeedback(.success, trigger: justAdded)
    }

    private func add(_ note: String) {
        let now = Date()
        guard now.timeIntervalSince(lastTap) > doubleTapGuard else { return }
        lastTap = now

        guard let entry = store.addEveryday(note) else { return }
        let soundOn = store.settings.soundOn
        if entry.earnsCredit && [LapMath.dailyGoal, LapMath.luckyNumber].contains(store.walkingCreditsToday) {
            Sounds.play(.goal, enabled: soundOn)
            Haptics.celebrate()
        } else {
            Sounds.play(.lapC, enabled: soundOn)
        }
        withAnimation { justAdded = entry }
        Task {
            // Long enough to find the Undo button with a shaky hand.
            try? await Task.sleep(for: .seconds(8))
            withAnimation { if justAdded?.id == entry.id { justAdded = nil } }
        }
    }

    private func sectionTitle(_ key: String) -> String {
        if key == store.todayKey { return "Today" }
        return store.date(forKey: key)?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? key
    }
}
