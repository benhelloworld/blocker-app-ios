import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        delayConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        delayConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        delayConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        delayConfiguration()
    }

    private func delayConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: "Wait 30 seconds", color: .white),
            subtitle: ShieldConfiguration.Label(text: "If you still want it, continue. This pause helps you choose intentionally.", color: UIColor.white.withAlphaComponent(0.72)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Start 30 second wait", color: .white),
            primaryButtonBackgroundColor: UIColor.systemCyan,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay focused", color: UIColor.white.withAlphaComponent(0.72))
        )
    }
}
