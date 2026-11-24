import SwiftUI
import UserNotifications

struct RemindersView: View {
    @Environment(WalkStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var permission: UNAuthorizationStatus = .notDetermined

    var body: some View {
        let reminders = store.settings.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }

        List {
            if permission == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notifications are turned off for laps, so reminders can't appear.")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(SecondaryButtonStyle(minHeight: 56))
                    }
                    .padding(.vertical, 6)
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.remindersPausedToday },
                    set: { store.setRemindersPausedToday($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause reminders for today")
                        Text("They'll start again tomorrow.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(minHeight: 56)
            }

            Section {
                ForEach(reminders) { r in
                    ReminderRow(reminder: r) { updated in
                        replace(updated)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { reminders[$0].id }
                    store.updateReminders(store.settings.reminders.filter { !ids.contains($0.id) })
                }
                if reminders.count < 6 {
                    Button {
                        store.updateReminders(store.settings.reminders + [nextSuggested(after: reminders)])
                    } label: {
                        Label("Add a reminder time", systemImage: "plus.circle.fill")
                            .frame(minHeight: 44)
                    }
                }
            } header: {
                Text("Walk reminders")
            } footer: {
                Text("Each reminder asks \"Time for a little walk?\" You can tap \"Remind me later\" right on the notification. Once you've done four sets in a day, the rest of that day's reminders stay quiet.")
            }

            Section {
                Toggle("Sounds", isOn: Binding(
                    get: { store.settings.soundOn },
                    set: { store.setSound($0) }))
                    .frame(minHeight: 48)
            } footer: {
                Text("Sounds follow the ring/silent switch on the side of the iPhone.")
            }
        }
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Reminders")
        .toolbar { EditButton() }
        .task(id: scenePhase) {
            permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    private func replace(_ r: ReminderTime) {
        var all = store.settings.reminders
        if let i = all.firstIndex(where: { $0.id == r.id }) { all[i] = r }
        store.updateReminders(all)
    }

    private func nextSuggested(after existing: [ReminderTime]) -> ReminderTime {
        let last = existing.last.map { $0.hour } ?? 9
        return ReminderTime(hour: min(20, last + 2), minute: 0)
    }
}

struct ReminderRow: View {
    let reminder: ReminderTime
    let onChange: (ReminderTime) -> Void

    var body: some View {
        HStack(spacing: 12) {
            DatePicker("Reminder time", selection: Binding(
                get: {
                    Calendar.current.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: .now) ?? .now
                },
                set: { newDate in
                    var r = reminder
                    let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                    r.hour = c.hour ?? r.hour
                    r.minute = c.minute ?? r.minute
                    onChange(r)
                }), displayedComponents: .hourAndMinute)
                .labelsHidden()
            Spacer()
            Toggle("On", isOn: Binding(
                get: { reminder.isOn },
                set: { var r = reminder; r.isOn = $0; onChange(r) }))
                .labelsHidden()
                .accessibilityLabel("Reminder at \(reminder.hour):\(String(format: "%02d", reminder.minute)) on")
        }
        .frame(minHeight: 56)
    }
}
