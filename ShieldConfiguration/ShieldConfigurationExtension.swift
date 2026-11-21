import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom look for the screen that covers a blocked app.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName, target: application.token.map { UnlockTarget.app($0) })
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName, target: application.token.map { UnlockTarget.app($0) })
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain, target: webDomain.token.map { UnlockTarget.web($0) })
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain, target: webDomain.token.map { UnlockTarget.web($0) })
    }

    private func make(name: String?, target: UnlockTarget?) -> ShieldConfiguration {
        let accent = UIColor(red: 0.98, green: 0.45, blue: 0.20, alpha: 1)
        let pending = SharedStore.shared.pendingUnlock
        let justTapped = pending.map { $0.isFresh && Date().timeIntervalSince($0.requested) < 120 && $0.target == target } ?? false

        let appName = name ?? "This app"
        let subtitle = justTapped
            ? "Tap the EarnIt notification to start your challenge. Or open EarnIt directly."
            : "\(appName) is blocked. Move your body or snap a photo to earn some time."

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.6),
            icon: UIImage(systemName: "figure.run.circle.fill")?
                .withTintColor(accent, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "Earn it first", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.85)),
            primaryButtonLabel: ShieldConfiguration.Label(text: justTapped ? "Send again" : "Earn an unlock", color: .white),
            primaryButtonBackgroundColor: accent,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "I'll pass", color: UIColor.white.withAlphaComponent(0.8))
        )
    }
}
