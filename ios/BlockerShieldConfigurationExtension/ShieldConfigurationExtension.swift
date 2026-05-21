import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let appGroupIdentifier = "group.com.benberther.BlockerApp"
    private let delayWaitStartedAtKey = "delayAppsWaitStartedAt"
    private let waitSeconds: TimeInterval = 15
    private let barSegments = 10

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
        let state = currentProgressState()

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0),
            icon: UIImage(systemName: "hourglass.circle.fill")?.withTintColor(.systemCyan, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: state.title, color: .white),
            subtitle: ShieldConfiguration.Label(text: state.subtitle, color: UIColor.white.withAlphaComponent(0.78)),
            primaryButtonLabel: ShieldConfiguration.Label(text: state.primaryButtonTitle, color: UIColor(red: 0.02, green: 0.05, blue: 0.08, alpha: 1.0)),
            primaryButtonBackgroundColor: UIColor(red: 0.20, green: 0.92, blue: 1.0, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay focused", color: UIColor.white.withAlphaComponent(0.78))
        )
    }

    private func currentProgressState() -> ProgressState {
        guard let startedAt = defaults?.object(forKey: delayWaitStartedAtKey) as? Date else {
            return ProgressState(
                title: "Pause for 15 seconds",
                subtitle: "██████████  15s left\nTap Start, then wait until the bar runs down. This tiny pause helps you choose intentionally.",
                primaryButtonTitle: "Start 15 sec pause"
            )
        }

        let remaining = remainingSeconds(startedAt: startedAt)
        let bar = progressBar(remainingSeconds: remaining)
        if remaining == 0 {
            return ProgressState(
                title: "Ready to continue",
                subtitle: "░░░░░░░░░░  Ready\nThe pause is complete. Tap Continue to open intentionally.",
                primaryButtonTitle: "Continue"
            )
        }

        return ProgressState(
            title: "Pause for \(remaining) seconds",
            subtitle: "\(bar)  \(remaining)s left\nWait for the bar to run down, then tap Continue.",
            primaryButtonTitle: "Still waiting"
        )
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private func remainingSeconds(startedAt: Date, now: Date = Date()) -> Int {
        let unlockAt = startedAt.addingTimeInterval(waitSeconds)
        return max(0, Int(ceil(unlockAt.timeIntervalSince(now))))
    }

    private func progressBar(remainingSeconds: Int) -> String {
        let clamped = max(0, min(remainingSeconds, Int(waitSeconds)))
        let fraction = Double(clamped) / waitSeconds
        let filled = Int(ceil(fraction * Double(barSegments)))
        return String(repeating: "█", count: filled) + String(repeating: "░", count: barSegments - filled)
    }

    private struct ProgressState {
        var title: String
        var subtitle: String
        var primaryButtonTitle: String
    }
}
