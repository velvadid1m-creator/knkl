import SwiftUI

@main
struct PingMeApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    await AppIconManager.ensureShopifyIcon()
                    await NotificationManager.shared.requestAuth()
                    await NotificationManager.shared.reschedule(store.reminders)
                }
        }
    }
}
