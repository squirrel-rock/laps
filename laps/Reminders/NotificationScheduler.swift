import Foundation
import UserNotifications

protocol ReminderScheduling: AnyObject {
    func apply(_ plan: [PlannedReminder])
}

enum NotificationIDs {
    static let inviteCategory = "WALK_INVITE"
    static let walkAction = "WALK_NOW"
    static let laterAction = "REMIND_LATER"
}

/// Applies a reminder plan to the system notification center.
final class NotificationScheduler: ReminderScheduling {
    private let center = UNUserNotificationCenter.current()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    static func registerCategories() {
        let walk = UNNotificationAction(identifier: NotificationIDs.walkAction,
                                        title: "Let's walk",
                                        options: [.foreground])
        let later = UNNotificationAction(identifier: NotificationIDs.laterAction,
                                         title: "Remind me later",
                                         options: [])
        let category = UNNotificationCategory(identifier: NotificationIDs.inviteCategory,
                                              actions: [walk, later],
                                              intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func apply(_ plan: [PlannedReminder]) {
        center.removeAllPendingNotificationRequests()
        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.categoryIdentifier = NotificationIDs.inviteCategory
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}
