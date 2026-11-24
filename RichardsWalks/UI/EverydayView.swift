import SwiftUI

/// Everyday walking — recorded separately and never counted toward the nine laps.
struct EverydayView: View {
    @Environment(WalkStore.self) private var store
    @State private var showingCustom = false
    @State private var customNote = ""
    @State private var justAdded: String?

    var body: some View {
        let recent = store.recordedDays.filter { !$0.everyday.isEmpty }.prefix(14)

        List {
            Section {
                VStack(spacing: 12) {
                    Text("Walking that isn't laps still counts for you. These don't change today's lap total.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        add("Walked to the car")
                    } label: {
                        Label("Walked to the car", systemImage: "car.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(minHeight: 88))

                    Button {
                        customNote = ""
                        showingCustom = true
                    } label: {
                        Label("Something else…", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if let added = justAdded {
                        Label("Saved: \(added)", systemImage: "checkmark.circle.fill")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.darkTeal)
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
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addEveryday(trimmed)
        Sounds.play(.lap, enabled: store.settings.soundOn)
        withAnimation { justAdded = trimmed }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { if justAdded == trimmed { justAdded = nil } }
        }
    }

    private func sectionTitle(_ key: String) -> String {
        if key == store.todayKey { return "Today" }
        return store.date(forKey: key)?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? key
    }
}
