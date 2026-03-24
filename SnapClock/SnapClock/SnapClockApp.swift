import SwiftUI
import SwiftData
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
            TabView {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("主页", systemImage: "moon.zzz.fill")
                }

                NavigationStack {
                    NapHistoryView()
                }
                .tabItem {
                    Label("记录", systemImage: "clock.arrow.circlepath")
                }
            }
            .preferredColorScheme(.dark)
            .tint(Color(red: 0.72, green: 0.67, blue: 0.96))
        }
        .modelContainer(for: NapSession.self)
    }
}
