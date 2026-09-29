import ManagedSettings
import FamilyControls
import Foundation

final class ShieldActionExtension: ShieldActionDelegate {
    private let appGroupIdentifier = "group.com.benberther.BlockerApp"
    private let scheduledSelectionKey = "scheduledShieldSelection"
    private let activeHardShieldSelectionKey = "activeHardShieldSelection"
    private let delaySelectionKey = "delaySelection"
    private let delayAppsEnabledKey = "delayAppsEnabled"
    private let delayWaitStartedAtKey = "delayAppsWaitStartedAt"
    private let shortcutRequestKey = "shortcutInterventionRequestedAt"
    private let shortcutReturnURLKey = "shortcutInterventionReturnURL"
    private let delayShieldTargetSelectionKey = "shortcutInterventionDelayShieldTargetSelection"
    private let hardBlockOpenRequestedAtKey = "hardBlockOpenRequestedAt"
    private let waitSeconds: TimeInterval = 15

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, delayTarget: .application(application), isDelayOnlyShield: isDelayOnlyShield(application: application), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, delayTarget: .webDomain(webDomain), isDelayOnlyShield: isDelayOnlyShield(webDomain: webDomain), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, delayTarget: .category(category), isDelayOnlyShield: isDelayOnlyShield(category: category), completionHandler: completionHandler)
    }

    private func handle(action: ShieldAction, delayTarget: DelayTarget, isDelayOnlyShield: Bool, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            if isDelayOnlyShield {
                recordDelayShieldIntervention(for: delayTarget)
            } else {
                recordHardBlockOpenRequest()
                clearDelayWait()
            }
            if #available(iOS 26.5, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                // Older iOS versions cannot open the parent app from a Screen Time shield.
                // Close after recording the trigger so opening AntiScroll manually still
                // presents the same in-app state.
                completionHandler(.close)
            }
        case .secondaryButtonPressed,
             .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            clearDelayWait()
            completionHandler(.close)
        @unknown default:
            clearDelayWait()
            completionHandler(.close)
        }
    }

    private func recordHardBlockOpenRequest() {
        defaults?.set(Date(), forKey: hardBlockOpenRequestedAtKey)
    }

    private func recordDelayShieldIntervention(for target: DelayTarget) {
        defaults?.set(Date(), forKey: shortcutRequestKey)
        defaults?.removeObject(forKey: shortcutReturnURLKey)
        if let data = try? JSONEncoder().encode(selection(containing: target)) {
            defaults?.set(data, forKey: delayShieldTargetSelectionKey)
        }
    }

    private func selection(containing target: DelayTarget) -> FamilyActivitySelection {
        var selection = FamilyActivitySelection()
        switch target {
        case .application(let token):
            selection.applicationTokens.insert(token)
        case .webDomain(let token):
            selection.webDomainTokens.insert(token)
        case .category(let token):
            selection.categoryTokens.insert(token)
        }
        return selection
    }

    private func completeDelayAction(for target: DelayTarget, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let now = Date()
        if let startedAt = defaults?.object(forKey: delayWaitStartedAtKey) as? Date {
            let unlockAt = startedAt.addingTimeInterval(waitSeconds)
            if now >= unlockAt {
                allowTemporarily(target)
                clearDelayWait()
                completionHandler(.close)
            } else {
                // Apple's shield UI is static: returning .none makes the button look like it did
                // nothing. Close instead so the user gets visible feedback and can retry after
                // the short pause has elapsed.
                completionHandler(.close)
            }
        } else {
            defaults?.set(now, forKey: delayWaitStartedAtKey)
            completionHandler(.close)
        }
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private func clearDelayWait() {
        defaults?.removeObject(forKey: delayWaitStartedAtKey)
    }

    private func allowTemporarily(_ target: DelayTarget) {
        let delayStore = ManagedSettingsStore(named: .init("delay-apps"))
        var selection = delaySelection

        switch target {
        case .application(let token):
            selection.applicationTokens.remove(token)
        case .webDomain(let token):
            selection.webDomainTokens.remove(token)
        case .category(let token):
            selection.categoryTokens.remove(token)
        }

        delayStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        delayStore.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        delayStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func isDelayOnlyShield(application: ApplicationToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let hardSelection = activeHardSelection
        return delaySelection.applicationTokens.contains(application)
            && !hardSelection.applicationTokens.contains(application)
            && hardSelection.categoryTokens.isEmpty
    }

    private func isDelayOnlyShield(webDomain: WebDomainToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let hardSelection = activeHardSelection
        return delaySelection.webDomainTokens.contains(webDomain)
            && !hardSelection.webDomainTokens.contains(webDomain)
            && hardSelection.categoryTokens.isEmpty
    }

    private func isDelayOnlyShield(category: ActivityCategoryToken) -> Bool {
        guard isDelayAppsEnabled else { return false }
        let hardSelection = activeHardSelection
        return delaySelection.categoryTokens.contains(category) && !hardSelection.categoryTokens.contains(category)
    }

    private var isDelayAppsEnabled: Bool {
        defaults?.bool(forKey: delayAppsEnabledKey) ?? false
    }

    private var delaySelection: FamilyActivitySelection {
        loadSelection(forKey: delaySelectionKey)
    }

    private var activeHardSelection: FamilyActivitySelection {
        loadSelection(forKey: activeHardShieldSelectionKey)
    }

    private func loadSelection(forKey key: String) -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private enum DelayTarget {
        case application(ApplicationToken)
        case webDomain(WebDomainToken)
        case category(ActivityCategoryToken)
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
