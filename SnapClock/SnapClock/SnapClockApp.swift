import SwiftUI
import UserNotifications

@main
struct SnapClockApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
