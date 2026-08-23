import Foundation
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(ManagedSettings)
import ManagedSettings
#endif

struct ShortcutInterventionStore {
    struct PendingTrigger: Equatable {
        let triggeredAt: Date
        let returnURL: URL?
        let hasShieldTarget: Bool
    }

    static let shared = ShortcutInterventionStore()

    private let requestKey = "shortcutInterventionRequestedAt"
    private let returnURLKey = "shortcutInterventionReturnURL"
    private let delayShieldTargetSelectionKey = "shortcutInterventionDelayShieldTargetSelection"
    private let delayShieldTargetBundleIDKey = "delayShieldTargetBundleID"
    private let nextOpenAllowedUntilKey = "shortcutInterventionNextOpenAllowedUntil"
    private let maxTriggerAge: TimeInterval = 60
    private let nextOpenAllowanceDuration: TimeInterval = 20

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedConfig.appGroupIdentifier)
    }

    func recordTrigger(returnURL: URL? = nil, now: Date = Date()) {
        defaults?.set(now, forKey: requestKey)
        defaults?.removeObject(forKey: delayShieldTargetSelectionKey)
        if let returnURL {
            defaults?.set(returnURL.absoluteString, forKey: returnURLKey)
        } else {
            defaults?.removeObject(forKey: returnURLKey)
        }
    }

    #if canImport(FamilyControls)
    func recordDelayShieldTrigger(selection: FamilyActivitySelection, now: Date = Date()) {
        defaults?.set(now, forKey: requestKey)
        defaults?.removeObject(forKey: returnURLKey)
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: delayShieldTargetSelectionKey)
        }
    }
    #endif

    func consumePendingTrigger(now: Date = Date()) -> PendingTrigger? {
        guard let triggeredAt = defaults?.object(forKey: requestKey) as? Date else { return nil }
        let returnURL = defaults?.string(forKey: returnURLKey).flatMap(URL.init(string:))
        let hasShieldTarget = defaults?.data(forKey: delayShieldTargetSelectionKey) != nil
        defaults?.removeObject(forKey: requestKey)
        defaults?.removeObject(forKey: returnURLKey)
        guard now.timeIntervalSince(triggeredAt) <= maxTriggerAge else {
            defaults?.removeObject(forKey: delayShieldTargetSelectionKey)
            return nil
        }
        return PendingTrigger(triggeredAt: triggeredAt, returnURL: returnURL, hasShieldTarget: hasShieldTarget)
    }

    func clearDelayShieldTarget() {
        defaults?.removeObject(forKey: delayShieldTargetSelectionKey)
        defaults?.removeObject(forKey: delayShieldTargetBundleIDKey)
    }

    #if canImport(FamilyControls)
    /// Bundle ID of the delay-shield target the user just confirmed opening.
    /// Recorded by the shield configuration extension (tokens are opaque, so
    /// the bundle ID is captured when the delay shield renders).
    /// Call BEFORE `allowPendingDelayShieldTarget()`.
    func pendingDelayShieldTargetBundleIDs() -> [String] {
        guard let bundleID = defaults?.string(forKey: delayShieldTargetBundleIDKey),
              !bundleID.isEmpty else { return [] }
        return [bundleID]
    }
    #endif

    #if canImport(FamilyControls) && canImport(ManagedSettings)
    @discardableResult
    func allowPendingDelayShieldTarget() -> Bool {
        guard let data = defaults?.data(forKey: delayShieldTargetSelectionKey),
              let target = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return false
        }

        var selection = ShieldStorage.shared.loadDelaySelection()
        selection.applicationTokens.subtract(target.applicationTokens)
        selection.categoryTokens.subtract(target.categoryTokens)
        selection.webDomainTokens.subtract(target.webDomainTokens)

        let delayStore = ManagedSettingsStore(named: .init("delay-apps"))
        delayStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        delayStore.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        delayStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        allowNextAutomationPass(now: Date())
        clearDelayShieldTarget()
        return true
    }
    #endif

    func allowNextAutomationPass(now: Date = Date()) {
        defaults?.set(now.addingTimeInterval(nextOpenAllowanceDuration), forKey: nextOpenAllowedUntilKey)
    }

    func clearNextAutomationPass() {
        defaults?.removeObject(forKey: nextOpenAllowedUntilKey)
    }

    func consumeNextAutomationPassIfActive(now: Date = Date()) -> Bool {
        guard let allowedUntil = defaults?.object(forKey: nextOpenAllowedUntilKey) as? Date else { return false }
        defaults?.removeObject(forKey: nextOpenAllowedUntilKey)
        return now <= allowedUntil
    }
}
