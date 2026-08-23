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

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity.rawValue == immediateActivityName {
            guard let selection = loadSelection(forKey: normalSelectionKey) else { return }
            applyShield(selection, storeName: immediateStoreName)
            saveSelection(selection, forKey: activeImmediateSelectionKey)
        } else if activity.rawValue.hasPrefix(scheduleActivityPrefix) {
            guard let selection = loadSelection(forKey: scheduledSelectionKey)
                ?? loadSelection(forKey: normalSelectionKey) else { return }
            var activeNames = loadActiveScheduleNames()
            activeNames.insert(activity.rawValue)
            saveActiveScheduleNames(activeNames)
            applyShield(selection, storeName: scheduledStoreName)
            saveSelection(selection, forKey: activeScheduledSelectionKey)
        }
        rebuildActiveHardSelection()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity.rawValue == immediateActivityName {
            ManagedSettingsStore(named: .init(immediateStoreName)).clearAllSettings()
            removeValue(forKey: activeImmediateSelectionKey)
            removeValue(forKey: activeImmediateSessionKey)
            removeValue(forKey: activeFocusTemplateKey)
        } else if activity.rawValue.hasPrefix(scheduleActivityPrefix) {
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

    private func applyShield(_ selection: FamilyActivitySelection, storeName: String) {
        let store = ManagedSettingsStore(named: .init(storeName))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        let automaticDomains = defaults?.stringArray(forKey: automaticWebDomainsKey) ?? []
        store.webContent.blockedByFilter = automaticDomains.isEmpty
            ? nil
            : .specific(Set(automaticDomains.map { WebDomain(domain: $0) }))
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
