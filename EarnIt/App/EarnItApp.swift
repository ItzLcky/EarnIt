import SwiftUI
import UserNotifications

@main
struct EarnItApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var tipJar = TipJar()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(tipJar)
                .tint(.accentColor)
                .task { await tipJar.listenForTransactions() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
                model.checkPendingUnlock()
            }
        }
    }
}

/// Shows notifications while the app is open and lets a tap on the unlock prompt land in the app.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // The app becoming active triggers AppModel.checkPendingUnlock(), which opens the challenge.
    }
}
