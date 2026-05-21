import ManagedSettings
import FamilyControls
import Foundation

final class ShieldActionExtension: ShieldActionDelegate {
    private let appGroupIdentifier = "group.com.benberther.BlockerApp"
    private let normalSelectionKey = "shieldSelection"
    private let delaySelectionKey = "delaySelection"
    private let delayAppsEnabledKey = "delayAppsEnabled"
    private let delayWaitStartedAtKey = "delayAppsWaitStartedAt"
    private let waitSeconds: TimeInterval = 15

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, isDelayOnlyShield: isDelayOnlyShield(application: application), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, isDelayOnlyShield: isDelayOnlyShield(webDomain: webDomain), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, isDelayOnlyShield: isDelayOnlyShield(category: category), completionHandler: completionHandler)
    }

    private func handle(action: ShieldAction, isDelayOnlyShield: Bool, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            guard isDelayOnlyShield else {
                clearDelayWait()
                completionHandler(.close)
                return
            }
            completeDelayAction(completionHandler: completionHandler)
        case .secondaryButtonPressed:
            clearDelayWait()
            completionHandler(.close)
        @unknown default:
            clearDelayWait()
            completionHandler(.close)
        }
    }

    private func completeDelayAction(completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let now = Date()
        if let startedAt = defaults?.object(forKey: delayWaitStartedAtKey) as? Date {
            let unlockAt = startedAt.addingTimeInterval(waitSeconds)
            if now >= unlockAt {
                clearDelayWait()
                completionHandler(.defer)
            } else {
                // Respond immediately so Apple's shield does not look frozen.
                // The shield stays up while the user finishes the pause, then they tap again.
                completionHandler(.none)
            }
        } else {
            defaults?.set(now, forKey: delayWaitStartedAtKey)
            completionHandler(.none)
        }
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private func clearDelayWait() {
        defaults?.removeObject(forKey: delayWaitStartedAtKey)
    }

    private func isDelayOnlyShield(application: ApplicationToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let delayContains = delaySelection.applicationTokens.contains(application)
        let normalContains = normalSelection.applicationTokens.contains(application)
        return delayContains && !normalContains
    }

    private func isDelayOnlyShield(webDomain: WebDomainToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let delayContains = delaySelection.webDomainTokens.contains(webDomain)
        let normalContains = normalSelection.webDomainTokens.contains(webDomain)
        return delayContains && !normalContains
    }

    private func isDelayOnlyShield(category: ActivityCategoryToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let delayContains = delaySelection.categoryTokens.contains(category)
        let normalContains = normalSelection.categoryTokens.contains(category)
        return delayContains && !normalContains
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

    private func loadSelection(forKey key: String) -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }
}
