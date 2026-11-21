import ManagedSettings
import Foundation

/// Handles the buttons on the shield screen shown over blocked apps.
/// Primary = "Earn an unlock" → remember which app, ping a notification that opens EarnIt.
/// Secondary = "Close" → count it as resisting temptation.
class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, target: .app(application), completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, target: .web(webDomain), completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // No specific token available; unlocking means taking a break from everything.
        respond(to: action, target: .everything, completionHandler)
    }

    private func respond(to action: ShieldAction, target: UnlockTarget,
                         _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            SharedStore.shared.pendingUnlock = PendingUnlock(target: target)
            Notifier.postUnlockPrompt()
            // .defer keeps the shield up and re-renders it, so it can say "check your notification".
            completionHandler(.defer)
        case .secondaryButtonPressed:
            SharedStore.shared.pendingUnlock = nil
            SharedStore.shared.recordResisted()
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
