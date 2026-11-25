import SwiftUI
import UserNotifications

@main
struct LapsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppDelegate.store)
                .environment(AppDelegate.photos)
                .tint(Theme.teal)
                .task {
                    #if DEBUG
                    if UserDefaults.standard.bool(forKey: "skipPermission") { return }
                    #endif
                    _ = await NotificationScheduler.requestPermission()
                    AppDelegate.store.refreshReminders()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Catch up after midnight and top up the next two weeks of reminders.
                AppDelegate.store.closeStaleSession()
                AppDelegate.store.refreshReminders()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static let store = WalkStore(scheduler: NotificationScheduler())
    @MainActor static let photos = PhotoStore()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategories()
        Sounds.prepareSession()
        Sounds.preload()
        return true
    }

    /// Show reminders even with the app open, unless he's in the middle of walking.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let walking = await MainActor.run { AppDelegate.store.active?.state == .walking }
        return walking ? [] : [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        if response.actionIdentifier == NotificationIDs.laterAction {
            await MainActor.run { AppDelegate.store.remindMeLater() }
        } else if content.categoryIdentifier == NotificationIDs.standUpCategory {
            let ids = content.userInfo[NotificationIDs.choicesKey] as? [String]
            await MainActor.run { AppDelegate.store.showStandUpPicker(choiceIDs: ids) }
        }
    }
}
