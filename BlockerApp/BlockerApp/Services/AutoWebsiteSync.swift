import Foundation

/// Reads the apps/categories the user picked in the DeviceActivityReport
/// picker (written by the report extension to the shared app group) and maps
/// them to website domains automatically via `AppDomainCatalog`.
final class AutoWebsiteSync {
    static let shared = AutoWebsiteSync()

    private let defaults = UserDefaults(suiteName: SharedConfig.appGroupIdentifier)

    private enum Keys {
        static let bundleIDs = "reportSelectedBundleIDs"
        static let displayNames = "reportSelectedDisplayNames"
        static let categoryNames = "reportSelectedCategoryNames"
    }

    var selectedBundleIDs: Set<String> {
        Set(defaults?.stringArray(forKey: Keys.bundleIDs) ?? [])
    }

    var selectedCategoryNames: Set<String> {
        Set(defaults?.stringArray(forKey: Keys.categoryNames) ?? [])
    }

    var selectedDisplayNames: Set<String> {
        Set(defaults?.stringArray(forKey: Keys.displayNames) ?? [])
    }

    var selectedAppCount: Int {
        selectedBundleIDs.count
    }

    /// Domains auto-derived from the user's app/category picks.
    var autoDomains: [String] {
        Self.effectiveDomains(
            bundleIDs: selectedBundleIDs,
            displayNames: selectedDisplayNames,
            categoryNames: selectedCategoryNames,
            manualDomains: []
        )
    }

    /// Manual + automatic domains, deduplicated and sanitized.
    func refreshSharedDomains() {
        defaults?.set(autoDomains, forKey: SharedConfig.automaticWebDomainsKey)
    }

    func mergedDomains(withManual manual: [String]) -> [String] {
        AppDomainCatalog.mergedDomains(manual, autoDomains)
    }

    static func effectiveDomains(bundleIDs: Set<String>, displayNames: Set<String>, categoryNames: Set<String>, manualDomains: [String]) -> [String] {
        AppDomainCatalog.mergedDomains(
            manualDomains,
            AppDomainCatalog.domains(forBundleIDs: bundleIDs),
            AppDomainCatalog.domains(forDisplayNames: displayNames),
            AppDomainCatalog.domains(forCategoryNames: categoryNames)
        )
    }
}
