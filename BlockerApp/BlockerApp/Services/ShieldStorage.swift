import Foundation
#if canImport(FamilyControls)
import FamilyControls
#endif

final class ShieldStorage {
    static let shared = ShieldStorage()

    private let defaults: UserDefaults?

    private init(defaults: UserDefaults? = UserDefaults(suiteName: SharedConfig.appGroupIdentifier)) {
        self.defaults = defaults
    }

    func saveSchedule(_ schedule: BlockSchedule) throws {
        let data = try JSONEncoder().encode(schedule)
        defaults?.set(data, forKey: SharedConfig.scheduleKey)
    }

    func loadSchedule() -> BlockSchedule {
        guard let data = defaults?.data(forKey: SharedConfig.scheduleKey),
              let schedule = try? JSONDecoder().decode(BlockSchedule.self, from: data) else {
            return .defaultFocus
        }
        return schedule
    }

    func saveScheduleEnabled(_ isEnabled: Bool) {
        defaults?.set(isEnabled, forKey: SharedConfig.scheduleEnabledKey)
    }

    func loadScheduleEnabled() -> Bool {
        defaults?.bool(forKey: SharedConfig.scheduleEnabledKey) ?? false
    }

    func saveRegisteredScheduleActivityNames(_ names: [String]) {
        defaults?.set(Array(Set(names)).sorted(), forKey: SharedConfig.registeredScheduleActivityNamesKey)
    }

    func loadRegisteredScheduleActivityNames() -> [String] {
        defaults?.stringArray(forKey: SharedConfig.registeredScheduleActivityNamesKey) ?? []
    }

    func saveActiveScheduleActivityNames(_ names: Set<String>) {
        defaults?.set(Array(names).sorted(), forKey: SharedConfig.activeScheduleActivityNamesKey)
    }

    func loadActiveScheduleActivityNames() -> Set<String> {
        Set(defaults?.stringArray(forKey: SharedConfig.activeScheduleActivityNamesKey) ?? [])
    }

    func saveActiveFocusTemplate(_ template: FocusTemplate?) {
        if let template {
            defaults?.set(template.rawValue, forKey: SharedConfig.activeFocusTemplateKey)
        } else {
            defaults?.removeObject(forKey: SharedConfig.activeFocusTemplateKey)
        }
    }

    func loadActiveFocusTemplate() -> FocusTemplate? {
        guard loadActiveImmediateSession() != nil,
              let rawValue = defaults?.string(forKey: SharedConfig.activeFocusTemplateKey) else {
            return nil
        }
        return FocusTemplate(rawValue: rawValue)
    }

    func saveActiveImmediateSession(_ session: ImmediateBlockSession) throws {
        let data = try JSONEncoder().encode(session)
        defaults?.set(data, forKey: SharedConfig.activeImmediateSessionKey)
    }

    func loadActiveImmediateSession(now: Date = Date()) -> ImmediateBlockSession? {
        guard let data = defaults?.data(forKey: SharedConfig.activeImmediateSessionKey),
              let session = try? JSONDecoder().decode(ImmediateBlockSession.self, from: data) else {
            return nil
        }

        if session.isActive(at: now) {
            return session
        }

        defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
        defaults?.removeObject(forKey: SharedConfig.activeFocusTemplateKey)
        defaults?.removeObject(forKey: SharedConfig.activeImmediateShieldSelectionKey)
        return nil
    }

    func clearActiveImmediateSession() {
        defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
        defaults?.removeObject(forKey: SharedConfig.activeFocusTemplateKey)
        defaults?.removeObject(forKey: SharedConfig.activeImmediateShieldSelectionKey)
    }

    func saveFocusCompletionPrompt(_ prompt: FocusCompletionPrompt) throws {
        defaults?.set(try JSONEncoder().encode(prompt), forKey: SharedConfig.focusCompletionPromptKey)
    }

    func loadFocusCompletionPrompt() -> FocusCompletionPrompt? {
        guard let data = defaults?.data(forKey: SharedConfig.focusCompletionPromptKey) else { return nil }
        return try? JSONDecoder().decode(FocusCompletionPrompt.self, from: data)
    }

    func clearFocusCompletionPrompt() {
        defaults?.removeObject(forKey: SharedConfig.focusCompletionPromptKey)
    }

    /// Returns true when a session is stored and still active at `now`.
    /// Unlike `loadActiveImmediateSession`, this never deletes state, so
    /// stale-callback guards can check it without destroying a new session.
    func hasActiveImmediateSession(now: Date = Date()) -> Bool {
        guard let data = defaults?.data(forKey: SharedConfig.activeImmediateSessionKey),
              let session = try? JSONDecoder().decode(ImmediateBlockSession.self, from: data) else {
            return false
        }
        return session.isActive(at: now)
    }

    /// Removes an expired stored session without touching the ManagedSettings
    /// store. Enforcement cleanup stays with the source that owns it.
    func clearExpiredImmediateSession(now: Date = Date()) {
        guard let data = defaults?.data(forKey: SharedConfig.activeImmediateSessionKey),
              let session = try? JSONDecoder().decode(ImmediateBlockSession.self, from: data),
              !session.isActive(at: now) else {
            return
        }
        defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
        defaults?.removeObject(forKey: SharedConfig.activeFocusTemplateKey)
        defaults?.removeObject(forKey: SharedConfig.activeImmediateShieldSelectionKey)
    }

    func savePremiumStatus(_ isPremium: Bool) {
        defaults?.set(isPremium, forKey: SharedConfig.premiumStatusKey)
    }

    func loadPremiumStatus() -> Bool {
        defaults?.bool(forKey: SharedConfig.premiumStatusKey) ?? false
    }

    func saveMacBlockDomains(_ domains: [String]) {
        defaults?.set(MacBlockDomainPreset.sanitized(domains), forKey: "macBlockDomains")
    }

    func loadMacBlockDomains() -> [String] {
        guard let saved = defaults?.stringArray(forKey: "macBlockDomains") else {
            return []
        }
        return MacBlockDomainPreset.sanitized(saved)
    }

    func saveSelectedMacDeviceIDs(_ ids: [String]) {
        defaults?.set(MacBlockDevicePreset.sanitizedDeviceIDs(ids), forKey: "selectedMacDeviceIDs")
    }

    func loadSelectedMacDeviceIDs() -> [String] {
        guard let saved = defaults?.stringArray(forKey: "selectedMacDeviceIDs"), !saved.isEmpty else {
            return MacBlockDevicePreset.defaultSelectedDeviceIDs
        }
        return MacBlockDevicePreset.sanitizedDeviceIDs(saved)
    }


    func saveFocusStats(_ stats: FocusStats) throws {
        let data = try JSONEncoder().encode(stats)
        defaults?.set(data, forKey: SharedConfig.focusStatsKey)
    }

    func loadFocusStats() -> FocusStats {
        guard let data = defaults?.data(forKey: SharedConfig.focusStatsKey),
              let stats = try? JSONDecoder().decode(FocusStats.self, from: data) else {
            return FocusStats()
        }
        return stats
    }

    func saveScheduledFocusStats(_ stats: ScheduledFocusStats) throws {
        defaults?.set(try JSONEncoder().encode(stats), forKey: SharedConfig.scheduledFocusStatsKey)
    }

    func loadScheduledFocusStats() -> ScheduledFocusStats {
        guard let data = defaults?.data(forKey: SharedConfig.scheduledFocusStatsKey),
              let stats = try? JSONDecoder().decode(ScheduledFocusStats.self, from: data) else {
            return ScheduledFocusStats()
        }
        return stats
    }

    func startScheduledFocusAccounting(activityName: String, startedAt: Date = Date()) {
        var starts = loadScheduledFocusStarts()
        if let existing = starts[activityName],
           startedAt >= existing,
           startedAt.timeIntervalSince(existing) < 36 * 60 * 60 {
            return
        }
        starts[activityName] = startedAt
        saveScheduledFocusStarts(starts)
    }

    func finishScheduledFocusAccounting(activityName: String, endedAt: Date = Date(), calendar: Calendar = .current) {
        var starts = loadScheduledFocusStarts()
        guard let startedAt = starts.removeValue(forKey: activityName) else { return }
        saveScheduledFocusStarts(starts)

        var stats = loadScheduledFocusStats()
        stats.recordProtection(
            start: startedAt,
            end: endedAt,
            maximumMinutes: loadScheduledFocusDurations()[activityName],
            calendar: calendar
        )
        try? saveScheduledFocusStats(stats)
    }

    func finishAllScheduledFocusAccounting(endedAt: Date = Date(), calendar: Calendar = .current) {
        let starts = loadScheduledFocusStarts()
        guard !starts.isEmpty else { return }
        saveScheduledFocusStarts([:])

        var stats = loadScheduledFocusStats()
        let durations = loadScheduledFocusDurations()
        for (activityName, startedAt) in starts {
            stats.recordProtection(
                start: startedAt,
                end: endedAt,
                maximumMinutes: durations[activityName],
                calendar: calendar
            )
        }
        try? saveScheduledFocusStats(stats)
    }

    func saveScheduledFocusDurations(_ durations: [String: Int]) {
        guard let data = try? JSONEncoder().encode(durations) else { return }
        defaults?.set(data, forKey: SharedConfig.scheduledFocusDurationsKey)
    }

    private func loadScheduledFocusDurations() -> [String: Int] {
        guard let data = defaults?.data(forKey: SharedConfig.scheduledFocusDurationsKey),
              let durations = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return durations
    }

    private func loadScheduledFocusStarts() -> [String: Date] {
        guard let data = defaults?.data(forKey: SharedConfig.scheduledFocusStartsKey),
              let starts = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return starts
    }

    private func saveScheduledFocusStarts(_ starts: [String: Date]) {
        guard let data = try? JSONEncoder().encode(starts) else { return }
        defaults?.set(data, forKey: SharedConfig.scheduledFocusStartsKey)
    }


    func recordFrictionUnlock(_ reflection: FrictionUnlockReflection) throws {
        var history = loadFrictionUnlockHistory()
        history.append(reflection)
        let data = try JSONEncoder().encode(history)
        defaults?.set(data, forKey: SharedConfig.frictionUnlockHistoryKey)
    }

    func loadFrictionUnlockHistory() -> [FrictionUnlockReflection] {
        guard let data = defaults?.data(forKey: SharedConfig.frictionUnlockHistoryKey),
              let history = try? JSONDecoder().decode([FrictionUnlockReflection].self, from: data) else {
            return []
        }
        return history
    }


    func loadEscapeTokenLedger() -> EscapeTokenLedger {
        guard let data = defaults?.data(forKey: SharedConfig.escapeTokenLedgerKey),
              let ledger = try? JSONDecoder().decode(EscapeTokenLedger.self, from: data) else {
            return EscapeTokenLedger()
        }
        return ledger
    }

    func saveEscapeTokenLedger(_ ledger: EscapeTokenLedger) throws {
        let data = try JSONEncoder().encode(ledger)
        defaults?.set(data, forKey: SharedConfig.escapeTokenLedgerKey)
    }

    @discardableResult
    func spendEscapeToken(on date: Date = Date(), calendar: Calendar = .current) throws -> EscapeTokenLedger {
        let ledger = loadEscapeTokenLedger()
        guard EscapeTokenPolicy.canSpendToken(in: ledger, on: date, calendar: calendar) else {
            return ledger
        }
        let updated = EscapeTokenPolicy.spendingToken(in: ledger, on: date, calendar: calendar)
        try saveEscapeTokenLedger(updated)
        return updated
    }


    func saveAccountabilityReceipt(_ receipt: AccountabilityReceipt) throws {
        let data = try JSONEncoder().encode(receipt)
        defaults?.set(data, forKey: SharedConfig.lastAccountabilityReceiptKey)
    }

    func loadLastAccountabilityReceipt() -> AccountabilityReceipt? {
        guard let data = defaults?.data(forKey: SharedConfig.lastAccountabilityReceiptKey) else { return nil }
        return try? JSONDecoder().decode(AccountabilityReceipt.self, from: data)
    }


    #if canImport(FamilyControls)
    func saveBlocklists(_ blocklists: [NamedBlocklist]) throws {
        let data = try JSONEncoder().encode(blocklists)
        defaults?.set(data, forKey: SharedConfig.blocklistsKey)
    }

    func loadBlocklists() -> [NamedBlocklist] {
        guard let data = defaults?.data(forKey: SharedConfig.blocklistsKey),
              let blocklists = try? JSONDecoder().decode([NamedBlocklist].self, from: data) else {
            return []
        }
        return blocklists.sorted { $0.createdAt < $1.createdAt }
    }

    func upsertBlocklist(_ blocklist: NamedBlocklist) throws {
        var blocklists = loadBlocklists()
        if let idx = blocklists.firstIndex(where: { $0.id == blocklist.id }) {
            blocklists[idx] = blocklist
        } else {
            blocklists.append(blocklist)
        }
        try saveBlocklists(blocklists)
    }

    func loadBlocklist(id: UUID?) -> NamedBlocklist? {
        guard let id else { return nil }
        return loadBlocklists().first { $0.id == id }
    }
    #endif

    #if canImport(FamilyControls)

    func saveScheduledSelection(_ selection: FamilyActivitySelection) throws {
        let data = try JSONEncoder().encode(selection)
        defaults?.set(data, forKey: SharedConfig.scheduledShieldSelectionKey)
    }

    func loadScheduledSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: SharedConfig.scheduledShieldSelectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func clearActiveHardShieldSelection() {
        defaults?.removeObject(forKey: SharedConfig.activeHardShieldSelectionKey)
        defaults?.removeObject(forKey: SharedConfig.activeImmediateShieldSelectionKey)
        defaults?.removeObject(forKey: SharedConfig.activeScheduledShieldSelectionKey)
        saveActiveScheduleActivityNames([])
    }

    func saveActiveImmediateShieldSelection(_ selection: FamilyActivitySelection?) throws {
        try saveSourceSelection(selection, key: SharedConfig.activeImmediateShieldSelectionKey)
        try rebuildActiveHardShieldSelection()
    }

    func saveActiveScheduledShieldSelection(_ selection: FamilyActivitySelection?) throws {
        try saveSourceSelection(selection, key: SharedConfig.activeScheduledShieldSelectionKey)
        try rebuildActiveHardShieldSelection()
    }

    func loadActiveImmediateShieldSelection() -> FamilyActivitySelection? {
        loadSourceSelection(key: SharedConfig.activeImmediateShieldSelectionKey)
    }

    func loadActiveScheduledShieldSelection() -> FamilyActivitySelection? {
        loadSourceSelection(key: SharedConfig.activeScheduledShieldSelectionKey)
    }

    private func saveSourceSelection(_ selection: FamilyActivitySelection?, key: String) throws {
        guard let selection else {
            defaults?.removeObject(forKey: key)
            return
        }
        defaults?.set(try JSONEncoder().encode(selection), forKey: key)
    }

    private func loadSourceSelection(key: String) -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private func rebuildActiveHardShieldSelection() throws {
        var merged = FamilyActivitySelection()
        for selection in [loadActiveImmediateShieldSelection(), loadActiveScheduledShieldSelection()].compactMap({ $0 }) {
            merged.applicationTokens.formUnion(selection.applicationTokens)
            merged.categoryTokens.formUnion(selection.categoryTokens)
            merged.webDomainTokens.formUnion(selection.webDomainTokens)
        }
        let isEmpty = merged.applicationTokens.isEmpty && merged.categoryTokens.isEmpty && merged.webDomainTokens.isEmpty
        if isEmpty {
            defaults?.removeObject(forKey: SharedConfig.activeHardShieldSelectionKey)
        } else {
            try saveActiveHardShieldSelection(merged)
        }
    }


    func saveActiveHardShieldSelection(_ selection: FamilyActivitySelection) throws {
        let data = try JSONEncoder().encode(selection)
        defaults?.set(data, forKey: SharedConfig.activeHardShieldSelectionKey)
    }

    func loadActiveHardShieldSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: SharedConfig.activeHardShieldSelectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func saveAdultWebFilterEnabled(_ isEnabled: Bool) {
        defaults?.set(isEnabled, forKey: SharedConfig.adultWebFilterEnabledKey)
    }

    func loadAdultWebFilterEnabled() -> Bool {
        defaults?.bool(forKey: SharedConfig.adultWebFilterEnabledKey) ?? false
    }


    func saveSelection(_ selection: FamilyActivitySelection) throws {
        let data = try JSONEncoder().encode(selection)
        defaults?.set(data, forKey: SharedConfig.shieldSelectionKey)
    }

    func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: SharedConfig.shieldSelectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }
    #endif

    func saveDelayAppsEnabled(_ isEnabled: Bool) {
        defaults?.set(isEnabled, forKey: SharedConfig.delayAppsEnabledKey)
    }

    func loadDelayAppsEnabled() -> Bool {
        defaults?.bool(forKey: SharedConfig.delayAppsEnabledKey) ?? false
    }

    func clearDelayAppsWait() {
        defaults?.removeObject(forKey: SharedConfig.delayWaitStartedAtKey)
    }

    #if canImport(FamilyControls)
    func saveDelaySelection(_ selection: FamilyActivitySelection) throws {
        let data = try JSONEncoder().encode(selection)
        defaults?.set(data, forKey: SharedConfig.delaySelectionKey)
    }

    func loadDelaySelection() -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: SharedConfig.delaySelectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    func loadDelayAppsConfiguration() -> DelayAppsConfiguration {
        let selection = loadDelaySelection()
        return DelayAppsConfiguration(
            isEnabled: loadDelayAppsEnabled(),
            appCount: selection.applicationTokens.count,
            categoryCount: selection.categoryTokens.count,
            webDomainCount: selection.webDomainTokens.count
        )
    }
    #else
    func loadDelayAppsConfiguration() -> DelayAppsConfiguration {
        DelayAppsConfiguration(isEnabled: loadDelayAppsEnabled())
    }
    #endif

}
