import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        applyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        clearShield()
    }

    private func applyShield() {
        let selection = ShieldStorage.shared.loadSelection()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func clearShield() {
        store.clearAllSettings()
    }
}
