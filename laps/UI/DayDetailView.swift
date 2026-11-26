import SwiftUI

/// One day's records, with ways to fix mistakes.
struct DayDetailView: View {
    @Environment(WalkStore.self) private var store
    let dayKey: String
    @State private var lapToDelete: LapEntry?

    var body: some View {
        let day = store.record(for: dayKey)

        List {
            Section {
                HStack {
                    Text("Laps").font(.system(.title3, design: .rounded))
                    Spacer()
                    Text("\(day.lapCount)").font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.darkTeal)
                }
                .accessibilityElement(children: .combine)
                Text(LapMath.setsDescription(day.lapCount))
                    .foregroundStyle(Theme.secondaryText)
                Button {
                    store.addLap(on: dayKey)
                } label: {
                    Label("Add a forgotten lap", systemImage: "plus.circle.fill")
                        .frame(minHeight: 44)
                }
            }

            if !day.laps.isEmpty {
                Section("Each lap") {
                    ForEach(day.laps.sorted { $0.time < $1.time }) { lap in
                        HStack {
                            Text(lap.time.formatted(date: .omitted, time: .shortened))
                            Spacer()
                            Button(role: .destructive) {
                                lapToDelete = lap
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove lap at \(lap.time.formatted(date: .omitted, time: .shortened))")
                        }
                    }
                }
            }

            if !day.sessions.isEmpty {
                Section("Walks") {
                    ForEach(day.sessions) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(s.start.formatted(date: .omitted, time: .shortened)) – \(s.end.formatted(date: .omitted, time: .shortened))")
                            Text("\(LapMath.plural(s.lapCount, "lap"))\(s.breaks > 0 ? ", \(LapMath.plural(s.breaks, "break"))" : "")")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            if !day.standUps.isEmpty || day.lotionDoneAt != nil {
                Section("Activities") {
                    if let lotion = day.lotionDoneAt, !day.standUps.contains(where: { $0.choiceID == Activities.morningLotion.id }) {
                        Label("Face wash and lotion at \(lotion.formatted(date: .omitted, time: .shortened))",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.darkTeal)
                    }
                    ForEach(day.standUps.filter { $0.doneAt != nil }.sorted { $0.picked < $1.picked }) { s in
                        HStack {
                            Text(s.title)
                            Spacer()
                            Text(s.doneAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "")
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete { offsets in
                        let sorted = day.standUps.filter { $0.doneAt != nil }.sorted { $0.picked < $1.picked }
                        for i in offsets { store.deleteStandUp(sorted[i].id, on: dayKey) }
                    }
                }
            }

            if !day.everyday.isEmpty {
                Section("Walks to the car and notes") {
                    ForEach(day.everyday.sorted { $0.time < $1.time }) { e in
                        HStack {
                            Text(e.note)
                            Spacer()
                            Text(e.time.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete { offsets in
                        let sorted = day.everyday.sorted { $0.time < $1.time }
                        for i in offsets { store.deleteEveryday(sorted[i].id, on: dayKey) }
                    }
                }
            }
        }
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .confirmationDialog("Remove this lap?", isPresented: Binding(
            get: { lapToDelete != nil }, set: { if !$0 { lapToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Remove lap", role: .destructive) {
                if let lap = lapToDelete { store.deleteLap(lap.id, on: dayKey) }
                lapToDelete = nil
            }
            Button("Keep it", role: .cancel) { lapToDelete = nil }
        }
    }

    private var title: String {
        if dayKey == store.todayKey { return "Today" }
        return store.date(forKey: dayKey)?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? dayKey
    }
}
