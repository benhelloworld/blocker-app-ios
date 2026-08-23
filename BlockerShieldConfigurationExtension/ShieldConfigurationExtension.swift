import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let appGroupIdentifier = "group.com.benberther.BlockerApp"
    private let normalSelectionKey = "shieldSelection"
    private let scheduledSelectionKey = "scheduledShieldSelection"
    private let activeHardShieldSelectionKey = "activeHardShieldSelection"
    private let delaySelectionKey = "delaySelection"
    private let delayAppsEnabledKey = "delayAppsEnabled"
    private let delayWaitStartedAtKey = "delayAppsWaitStartedAt"
    private let delayTargetBundleIDKey = "delayShieldTargetBundleID"
    private let waitSeconds: TimeInterval = 15
    private let barSegments = 10

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        if let appToken = application.token,
           isDelayOnlyShield(application: appToken) {
            recordDelayTargetBundleID(application.bundleIdentifier)
        }
        return delayOrNormalConfiguration(forApplicationToken: application.token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        if let appToken = application.token,
           isDelayOnlyShield(application: appToken, category: category.token) {
            recordDelayTargetBundleID(application.bundleIdentifier)
            return delayConfiguration()
        }
        return delayOrNormalConfiguration(forCategoryToken: category.token)
    }

    /// Remembers which app the user tried to open, so AntiScroll can redirect
    /// straight into it after the 15-second pause ("Open it").
    private func recordDelayTargetBundleID(_ bundleID: String?) {
        guard let bundleID, !bundleID.isEmpty else { return }
        defaults?.set(bundleID, forKey: delayTargetBundleIDKey)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        delayOrNormalConfiguration(forWebDomainToken: webDomain.token)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        if let webToken = webDomain.token,
           isDelayOnlyShield(webDomain: webToken, category: category.token) {
            return delayConfiguration()
        }
        return delayOrNormalConfiguration(forCategoryToken: category.token)
    }

    private func delayOrNormalConfiguration(forApplicationToken token: ApplicationToken?) -> ShieldConfiguration {
        guard let token, isDelayOnlyShield(application: token) else {
            return normalBlockConfiguration()
        }
        return delayConfiguration()
    }

    private func delayOrNormalConfiguration(forWebDomainToken token: WebDomainToken?) -> ShieldConfiguration {
        guard let token, isDelayOnlyShield(webDomain: token) else {
            return normalBlockConfiguration()
        }
        return delayConfiguration()
    }

    private func delayOrNormalConfiguration(forCategoryToken token: ActivityCategoryToken?) -> ShieldConfiguration {
        guard let token, isDelayOnlyShield(category: token) else {
            return normalBlockConfiguration()
        }
        return delayConfiguration()
    }

    private func normalBlockConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.015, green: 0.014, blue: 0.012, alpha: 1.0),
            icon: UIImage(systemName: "lock.shield.fill")?.withTintColor(gold, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "Focus mode is on", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "You chose to protect this time. Take one breath, close this screen, and return to what matters.",
                color: UIColor.white.withAlphaComponent(0.80)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open AntiScroll", color: UIColor(red: 0.02, green: 0.018, blue: 0.012, alpha: 1.0)),
            primaryButtonBackgroundColor: gold,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay blocked", color: UIColor.white.withAlphaComponent(0.72))
        )
    }

    private func delayConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.015, green: 0.014, blue: 0.012, alpha: 1.0),
            icon: UIImage(systemName: "hourglass.circle.fill")?.withTintColor(gold, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "Open AntiScroll pause", color: .white),
            subtitle: ShieldConfiguration.Label(text: "This app is in Delay Apps. Open AntiScroll for the 15-second pause, then choose intentionally.", color: UIColor.white.withAlphaComponent(0.78)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open AntiScroll", color: UIColor(red: 0.02, green: 0.018, blue: 0.012, alpha: 1.0)),
            primaryButtonBackgroundColor: gold,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay focused", color: UIColor.white.withAlphaComponent(0.78))
        )
    }

    private func currentProgressState() -> ProgressState {
        guard let startedAt = defaults?.object(forKey: delayWaitStartedAtKey) as? Date else {
            return ProgressState(
                iconName: "hourglass.circle.fill",
                title: "Pause for 15 seconds",
                subtitle: "██████████  15s left\nTap Start. This closes for 15 seconds, then come back and choose Yes or No.",
                primaryButtonTitle: "Start pause",
                secondaryButtonTitle: "No, stay focused"
            )
        }

        let remaining = remainingSeconds(startedAt: startedAt)
        let bar = progressBar(remainingSeconds: remaining)
        if remaining == 0 {
            return ProgressState(
                iconName: "questionmark.circle.fill",
                title: "Do you really want to open it?",
                subtitle: "░░░░░░░░░░  Ready\nThe impulse pause is complete. Choose intentionally.",
                primaryButtonTitle: "Yes, open it",
                secondaryButtonTitle: "No, stay focused"
            )
        }

        return ProgressState(
            iconName: "hourglass.circle.fill",
            title: "Pause for \(remaining) seconds",
            subtitle: "\(bar)  \(remaining)s left\nThe pause is running. Come back when it reaches zero.",
            primaryButtonTitle: "Still waiting",
            secondaryButtonTitle: "No, stay focused"
        )
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private var isDelayAppsEnabled: Bool {
        defaults?.bool(forKey: delayAppsEnabledKey) ?? false
    }

    private var delaySelection: FamilyActivitySelection {
        loadSelection(forKey: delaySelectionKey)
    }

    private var normalSelection: FamilyActivitySelection {
        loadSelection(forKey: normalSelectionKey)
    }

    private var activeHardSelection: FamilyActivitySelection {
        let active = loadSelection(forKey: activeHardShieldSelectionKey)
        if !active.applicationTokens.isEmpty || !active.categoryTokens.isEmpty || !active.webDomainTokens.isEmpty {
            return active
        }
        return normalSelection
    }

    private func isDelayOnlyShield(application: ApplicationToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let hardSelection = activeHardSelection
        return delaySelection.applicationTokens.contains(application)
            && !hardSelection.applicationTokens.contains(application)
            && hardSelection.categoryTokens.isEmpty
    }

    private func isDelayOnlyShield(application: ApplicationToken, category: ActivityCategoryToken?) -> Bool {
        guard isDelayAppsEnabled, delaySelection.applicationTokens.contains(application) else { return false }
        let hardSelection = activeHardSelection
        if hardSelection.applicationTokens.contains(application) { return false }
        if let category, hardSelection.categoryTokens.contains(category) { return false }
        return true
    }

    private func isDelayOnlyShield(webDomain: WebDomainToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let hardSelection = activeHardSelection
        return delaySelection.webDomainTokens.contains(webDomain)
            && !hardSelection.webDomainTokens.contains(webDomain)
            && hardSelection.categoryTokens.isEmpty
    }

    private func isDelayOnlyShield(webDomain: WebDomainToken, category: ActivityCategoryToken?) -> Bool {
        guard isDelayAppsEnabled, delaySelection.webDomainTokens.contains(webDomain) else { return false }
        let hardSelection = activeHardSelection
        if hardSelection.webDomainTokens.contains(webDomain) { return false }
        if let category, hardSelection.categoryTokens.contains(category) { return false }
        return true
    }

    private func isDelayOnlyShield(category: ActivityCategoryToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let hardSelection = activeHardSelection
        return delaySelection.categoryTokens.contains(category) && !hardSelection.categoryTokens.contains(category)
    }

    private func loadSelection(forKey key: String) -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private var gold: UIColor {
        UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1.0)
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
        var iconName: String
        var title: String
        var subtitle: String
        var primaryButtonTitle: String
        var secondaryButtonTitle: String
    }
}


private extension FamilyActivitySelection {
    func merging(_ other: FamilyActivitySelection) -> FamilyActivitySelection {
        var merged = self
        merged.applicationTokens.formUnion(other.applicationTokens)
        merged.categoryTokens.formUnion(other.categoryTokens)
        merged.webDomainTokens.formUnion(other.webDomainTokens)
        return merged
    }
}
