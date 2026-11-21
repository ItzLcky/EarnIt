import Foundation
import UserNotifications

/// Shield extensions can't open the app directly, so (like other blockers)
/// we post a local notification that takes the user straight to the challenge.
enum Notifier {
    static let unlockCategory = "earnit.unlock"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func postUnlockPrompt() {
        let content = UNMutableNotificationContent()
        content.title = "Earn your unlock 💪"
        content.body = "Tap here to start a quick challenge."
        content.sound = .default
        content.categoryIdentifier = unlockCategory
        content.interruptionLevel = .active

        let request = UNNotificationRequest(identifier: "earnit.unlock.prompt", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func clearUnlockPrompt() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["earnit.unlock.prompt"])
    }
}
