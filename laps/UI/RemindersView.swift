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
                        Text("Pause walk reminders for today")
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
                Text("Each reminder asks \"Time for a little walk?\" You can tap \"Remind me later\" right on the notification. Once you reach 13 in a day, the rest of that day's reminders stay quiet.")
            }

            StandUpSettingsSection()

            Section {
                Toggle("Sounds", isOn: Binding(
                    get: { store.settings.soundOn },
                    set: { store.setSound($0) }))
                    .frame(minHeight: 48)
            } footer: {
                Text("Cheerful sounds for laps, sets and standing up. They play even when the iPhone is on silent.")
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

struct StandUpSettingsSection: View {
    @Environment(WalkStore.self) private var store

    var body: some View {
        let settings = store.settings.standUp

        Section {
            Stepper(value: Binding(get: { store.standingGoal }, set: { store.setStandingGoal($0) }),
                    in: StandUpSettings.goalRange) {
                Text("Daily goal: \(store.standingGoal) times")
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            .frame(minHeight: 56)
            .accessibilityValue("\(store.standingGoal) times a day")
        } header: {
            Text("Standing up")
        } footer: {
            Text("Every time up counts: \"I stood up\", a finished idea, or the face lotion.")
        }

        Section {
            Toggle("Every half hour", isOn: binding(\.isOn))
                .frame(minHeight: 48)
            if settings.isOn {
                DatePicker("From", selection: time(hour: \.startHour, minute: \.startMinute),
                           displayedComponents: .hourAndMinute)
                    .frame(minHeight: 48)
                DatePicker("Until", selection: time(hour: \.endHour, minute: \.endMinute),
                           displayedComponents: .hourAndMinute)
                    .frame(minHeight: 48)
                Toggle(isOn: Binding(
                    get: { store.standUpsPausedToday },
                    set: { store.setStandUpsPausedToday($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause standing-up reminders for today")
                        Text("They'll start again tomorrow.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(minHeight: 56)
            }
        } header: {
            Text("Standing-up reminders")
        } footer: {
            Text("Each one offers three ideas: a spin around the living room, an exercise, and something fun or useful. They wait while you're in the middle of a walk, and skip any time a walk reminder is due.")
        }
    }

    private func binding(_ key: WritableKeyPath<StandUpSettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.settings.standUp[keyPath: key] },
                set: { var s = store.settings.standUp; s[keyPath: key] = $0; store.updateStandUpSettings(s) })
    }

    private func time(hour: WritableKeyPath<StandUpSettings, Int>,
                      minute: WritableKeyPath<StandUpSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let s = store.settings.standUp
                return Calendar.current.date(bySettingHour: s[keyPath: hour], minute: s[keyPath: minute], second: 0, of: .now) ?? .now
            },
            set: { newDate in
                var s = store.settings.standUp
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                s[keyPath: hour] = c.hour ?? s[keyPath: hour]
                s[keyPath: minute] = c.minute ?? s[keyPath: minute]
                store.updateStandUpSettings(s)
            })
    }
}
