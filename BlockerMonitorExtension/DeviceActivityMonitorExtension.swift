//
//  DeviceActivityMonitorExtension.swift
//  BlockerMonitorExtension
//
//  Created by Ben Berther on 16.05.2026.
//

import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let appGroupIdentifier = "group.com.benberther.BlockerApp"
    private let scheduleActivityPrefix = "daily-block"
    private let immediateActivityName = "immediate-block"
    private let immediateStoreName = "immediate-block"
    private let scheduledStoreName = "scheduled-blocks"

    private let normalSelectionKey = "shieldSelection"
    private let scheduledSelectionKey = "scheduledShieldSelection"
    private let activeHardSelectionKey = "activeHardShieldSelection"
    private let activeImmediateSelectionKey = "activeImmediateShieldSelection"
    private let activeScheduledSelectionKey = "activeScheduledShieldSelection"
    private let activeScheduleActivityNamesKey = "activeScheduleActivityNames"
    private let activeImmediateSessionKey = "activeImmediateSession"
    private let activeFocusTemplateKey = "activeFocusTemplate"
    private let automaticWebDomainsKey = "automaticWebDomains"
    private let scheduledFocusStatsKey = "scheduledFocusStats"
    private let scheduledFocusStartsKey = "scheduledFocusStarts"
    private let scheduledFocusDurationsKey = "scheduledFocusDurations"

    // Decodable mirror of the app-side ImmediateBlockSession persisted in the
    // App Group. The extension cannot import the app model; it only needs
    // start/duration to decide whether an interval-end callback belongs to a
    // still-running Quick Block (preserve) or to a block whose time already
    // passed (clear).
    private struct StoredImmediateSessionPayload: Decodable {
        let start: Date
        let durationMinutes: Int

        var end: Date {
            start.addingTimeInterval(TimeInterval(max(1, durationMinutes) * 60))
        }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity.rawValue == immediateActivityName {
            // A stale start callback from a previous Quick Block generation must
            // not overwrite a newer commitment with the old picker snapshot.
            let hasCurrentSession = defaults?.data(forKey: activeImmediateSessionKey) != nil
            guard !hasCurrentSession else { return }
            guard let selection = loadSelection(forKey: activeImmediateSelectionKey),
                  applyShield(selection, storeName: immediateStoreName) else { return }
            saveSelection(selection, forKey: activeImmediateSelectionKey)
        } else if activity.rawValue.hasPrefix(scheduleActivityPrefix) {
            guard let selection = loadSelection(forKey: scheduledSelectionKey)
                ?? loadSelection(forKey: normalSelectionKey),
                  applyShield(selection, storeName: scheduledStoreName) else { return }
            var activeNames = loadActiveScheduleNames()
            activeNames.insert(activity.rawValue)
            saveActiveScheduleNames(activeNames)
            saveSelection(selection, forKey: activeScheduledSelectionKey)
            startScheduledFocusAccounting(activityName: activity.rawValue)
        }
        rebuildActiveHardSelection()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity.rawValue == immediateActivityName {
            // A stale end callback from a previous Quick Block generation must
            // never erase a newer commitment: clear only when no session is
            // still stored. The app-side cleanup of an expired session happens
            // in foreground reconciliation.
            // The stored session normally outlives the registered interval, so
            // a bare "key exists" check would make the genuine end callback
            // skip cleanup and leave shields applied until the app happens to
            // reconcile in the foreground. Clear exactly when the session that
            // produced this activity has already ended; preserve only when a
            // stored session is still running (for example a stale callback
            // racing a fresh Quick Block whose interval was just registered).
            let storedEnd = defaults?.data(forKey: activeImmediateSessionKey)
                .flatMap { try? JSONDecoder().decode(StoredImmediateSessionPayload.self, from: $0) }?
                .end
            let grace = Date().addingTimeInterval(1)
            guard let storedEnd, grace < storedEnd else {
                ManagedSettingsStore(named: .init(immediateStoreName)).clearAllSettings()
                removeValue(forKey: activeImmediateSelectionKey)
                removeValue(forKey: activeImmediateSessionKey)
                removeValue(forKey: activeFocusTemplateKey)
                return
            }
            // A newer commitment is still active; do not clear its enforcement.
            return
        } else if activity.rawValue.hasPrefix(scheduleActivityPrefix) {
            finishScheduledFocusAccounting(activityName: activity.rawValue)
            var activeNames = loadActiveScheduleNames()
            activeNames.remove(activity.rawValue)
            saveActiveScheduleNames(activeNames)
            if activeNames.isEmpty {
                ManagedSettingsStore(named: .init(scheduledStoreName)).clearAllSettings()
                removeValue(forKey: activeScheduledSelectionKey)
            }
        }
        rebuildActiveHardSelection()
    }

    @discardableResult
    private func applyShield(_ selection: FamilyActivitySelection, storeName: String) -> Bool {
        let store = ManagedSettingsStore(named: .init(storeName))
        let applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        let categories: ShieldSettings.ActivityCategoryPolicy<Application>? = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        let webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.applications = applications
        store.shield.applicationCategories = categories
        store.shield.webDomains = webDomains

        let automaticDomains = defaults?.stringArray(forKey: automaticWebDomainsKey) ?? []
        let webFilter: WebContentSettings.FilterPolicy? = automaticDomains.isEmpty
            ? nil
            : .specific(Set(automaticDomains.map { WebDomain(domain: $0) }))
        store.webContent.blockedByFilter = webFilter

        return store.shield.applications == applications
            && store.shield.applicationCategories == categories
            && store.shield.webDomains == webDomains
            && store.webContent.blockedByFilter == webFilter
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private func loadSelection(forKey key: String) -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private func saveSelection(_ selection: FamilyActivitySelection, forKey key: String) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(data, forKey: key)
    }

    private func removeValue(forKey key: String) {
        defaults?.removeObject(forKey: key)
    }

    private func loadActiveScheduleNames() -> Set<String> {
        Set(defaults?.stringArray(forKey: activeScheduleActivityNamesKey) ?? [])
    }

    private func saveActiveScheduleNames(_ names: Set<String>) {
        defaults?.set(Array(names).sorted(), forKey: activeScheduleActivityNamesKey)
    }

    private struct ScheduledFocusStatsPayload: Codable {
        var totalProtectedMinutes: Int
        var focusDayStamps: Set<String>

        init(totalProtectedMinutes: Int = 0, focusDayStamps: Set<String> = []) {
            self.totalProtectedMinutes = totalProtectedMinutes
            self.focusDayStamps = focusDayStamps
        }
    }

    private func startScheduledFocusAccounting(activityName: String, startedAt: Date = Date()) {
        var starts = loadScheduledFocusStarts()
        if let existing = starts[activityName],
           startedAt >= existing,
           startedAt.timeIntervalSince(existing) < 36 * 60 * 60 {
            return
        }
        starts[activityName] = startedAt
        saveScheduledFocusStarts(starts)
    }

    private func finishScheduledFocusAccounting(activityName: String, endedAt: Date = Date(), calendar: Calendar = .current) {
        var starts = loadScheduledFocusStarts()
        guard let startedAt = starts.removeValue(forKey: activityName) else { return }
        saveScheduledFocusStarts(starts)

        let maximumMinutes = loadScheduledFocusDurations()[activityName]
        let cappedEnd: Date
        if let maximumMinutes {
            cappedEnd = min(endedAt, startedAt.addingTimeInterval(TimeInterval(max(0, maximumMinutes) * 60)))
        } else {
            cappedEnd = endedAt
        }
        let elapsedMinutes = Int(floor(cappedEnd.timeIntervalSince(startedAt) / 60))
        guard elapsedMinutes > 0 else { return }
        var stats = loadScheduledFocusStats()
        stats.totalProtectedMinutes += elapsedMinutes

        var cursor = startedAt
        while cursor < cappedEnd {
            stats.focusDayStamps.insert(dayStamp(for: cursor, calendar: calendar))
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart), nextDay > cursor else { break }
            cursor = nextDay
        }
        guard let data = try? JSONEncoder().encode(stats) else { return }
        defaults?.set(data, forKey: scheduledFocusStatsKey)
    }

    private func loadScheduledFocusStats() -> ScheduledFocusStatsPayload {
        guard let data = defaults?.data(forKey: scheduledFocusStatsKey),
              let stats = try? JSONDecoder().decode(ScheduledFocusStatsPayload.self, from: data) else {
            return ScheduledFocusStatsPayload()
        }
        return stats
    }

    private func loadScheduledFocusDurations() -> [String: Int] {
        guard let data = defaults?.data(forKey: scheduledFocusDurationsKey),
              let durations = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return durations
    }

    private func loadScheduledFocusStarts() -> [String: Date] {
        guard let data = defaults?.data(forKey: scheduledFocusStartsKey),
              let starts = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return starts
    }

    private func saveScheduledFocusStarts(_ starts: [String: Date]) {
        guard let data = try? JSONEncoder().encode(starts) else { return }
        defaults?.set(data, forKey: scheduledFocusStartsKey)
    }

    private func dayStamp(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func rebuildActiveHardSelection() {
        let selections = [
            loadSelection(forKey: activeImmediateSelectionKey),
            loadSelection(forKey: activeScheduledSelectionKey)
        ].compactMap { $0 }

        var merged = FamilyActivitySelection()
        for selection in selections {
            merged.applicationTokens.formUnion(selection.applicationTokens)
            merged.categoryTokens.formUnion(selection.categoryTokens)
            merged.webDomainTokens.formUnion(selection.webDomainTokens)
        }

        if merged.applicationTokens.isEmpty && merged.categoryTokens.isEmpty && merged.webDomainTokens.isEmpty {
            removeValue(forKey: activeHardSelectionKey)
        } else {
            saveSelection(merged, forKey: activeHardSelectionKey)
        }
    }
}
