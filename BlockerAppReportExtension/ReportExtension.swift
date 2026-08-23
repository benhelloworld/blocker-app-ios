import DeviceActivity
import _DeviceActivity_SwiftUI
import ExtensionKit
import ManagedSettings
import SwiftUI

/// Shared storage between the report extension and the main app.
enum ReportShared {
    static let appGroup = "group.com.benberther.BlockerApp"
    static let selectedBundleIDsKey = "reportSelectedBundleIDs"
    static let selectedDisplayNamesKey = "reportSelectedDisplayNames"
    static let selectedCategoryNamesKey = "reportSelectedCategoryNames"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func loadSelectedBundleIDs() -> Set<String> {
        Set(defaults?.stringArray(forKey: selectedBundleIDsKey) ?? [])
    }

    static func saveSelectedBundleIDs(_ ids: Set<String>) {
        defaults?.set(ids.sorted(), forKey: selectedBundleIDsKey)
    }

    static func saveSelectedDisplayNames(_ names: Set<String>) {
        defaults?.set(names.sorted(), forKey: selectedDisplayNamesKey)
    }

    static func loadSelectedCategoryNames() -> Set<String> {
        Set(defaults?.stringArray(forKey: selectedCategoryNamesKey) ?? [])
    }

    static func saveSelectedCategoryNames(_ names: Set<String>) {
        defaults?.set(names.sorted(), forKey: selectedCategoryNamesKey)
    }
}

/// A lightweight snapshot of what the report extension parsed from Screen Time.
struct AppUsageSnapshot {
    struct AppUsage: Identifiable, Hashable {
        let bundleIdentifier: String
        let displayName: String
        var id: String { bundleIdentifier }
    }

    struct CategoryUsage: Identifiable, Hashable {
        let name: String
        var id: String { name }
    }

    var apps: [AppUsage]
    var categories: [CategoryUsage]
}

@main
@MainActor
struct ReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        AppUsageReport { snapshot in
            AppUsageReportView(snapshot: snapshot)
        }
        SelectedAppSyncReport { _ in EmptyView() }
    }
}

/// Resolves the Family Controls tokens supplied by the iPhone selection into
/// bundle IDs/display names inside Apple's report extension sandbox.
struct SelectedAppSyncReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "Selected App Sync")
    let content: (AppUsageSnapshot) -> EmptyView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> AppUsageSnapshot {
        var apps: [AppUsageSnapshot.AppUsage] = []
        var seenBundles = Set<String>()
        var categories = Set<String>()
        for await activityData in data {
            for await segment in activityData.activitySegments {
                for await category in segment.categories {
                    if let name = category.category.localizedDisplayName { categories.insert(name) }
                    for await appActivity in category.applications {
                        let app = appActivity.application
                        guard let bundle = app.bundleIdentifier, !bundle.isEmpty, seenBundles.insert(bundle).inserted else { continue }
                        apps.append(.init(bundleIdentifier: bundle, displayName: app.localizedDisplayName ?? bundle))
                    }
                }
            }
        }
        apps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        let snapshot = AppUsageSnapshot(apps: apps, categories: categories.sorted().map { .init(name: $0) })
        ReportShared.saveSelectedBundleIDs(Set(apps.map(\.bundleIdentifier)))
        ReportShared.saveSelectedDisplayNames(Set(apps.map(\.displayName)))
        ReportShared.saveSelectedCategoryNames(categories)
        return snapshot
    }
}

struct AppUsageReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "App Usage")
    let content: (AppUsageSnapshot) -> AppUsageReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> AppUsageSnapshot {
        var apps: [AppUsageSnapshot.AppUsage] = []
        var seenBundles = Set<String>()
        var categories = Set<String>()

        for await activityData in data {
            for await segment in activityData.activitySegments {
                for await category in segment.categories {
                    if let name = category.category.localizedDisplayName {
                        categories.insert(name)
                    }
                    for await appActivity in category.applications {
                        let app = appActivity.application
                        guard let bundle = app.bundleIdentifier, !bundle.isEmpty else { continue }
                        let name = app.localizedDisplayName ?? bundle
                        guard seenBundles.insert(bundle).inserted else { continue }
                        apps.append(.init(bundleIdentifier: bundle, displayName: name))
                    }
                }
            }
        }

        apps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return AppUsageSnapshot(
            apps: apps,
            categories: categories.sorted().map { .init(name: $0) }
        )
    }
}
