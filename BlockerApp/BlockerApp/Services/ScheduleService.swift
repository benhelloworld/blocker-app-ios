import Foundation
#if canImport(DeviceActivity)
import DeviceActivity
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(ManagedSettings)
import ManagedSettings
#endif

enum HardBlockActivationFailure: Equatable {
    case authorizationRequired
    case emptySelection
}

struct HardBlockActivationPreflight {
    static func failure(
        isAuthorized: Bool,
        applicationCount: Int,
        categoryCount: Int,
        webDomainCount: Int
    ) -> HardBlockActivationFailure? {
        guard isAuthorized else { return .authorizationRequired }
        guard applicationCount + categoryCount + webDomainCount > 0 else { return .emptySelection }
        return nil
    }
}

enum ImmediateShieldReconciliationAction: Equatable {
    case clearStaleEnforcement
    case invalidateAuthorization
    case invalidateSelection
    case reapplyShield
    case verified
}

struct ImmediateShieldReconciliationPolicy {
    static func action(
        hasActiveSession: Bool,
        isAuthorized: Bool,
        hasSelection: Bool,
        settingsMatch: Bool
    ) -> ImmediateShieldReconciliationAction {
        guard hasActiveSession else { return .clearStaleEnforcement }
        guard isAuthorized else { return .invalidateAuthorization }
        guard hasSelection else { return .invalidateSelection }
        return settingsMatch ? .verified : .reapplyShield
    }
}

enum ScheduleServiceError: LocalizedError, Equatable {
    case immediateBlockAlreadyActive(String)
    case premiumRequired(String)
    case authorizationRequired
    case emptySelection
    case invalidSchedule(ScheduleValidationIssue)
    case managedSettingsNotApplied

    var errorDescription: String? {
        switch self {
        case .immediateBlockAlreadyActive(let message), .premiumRequired(let message):
            return message
        case .authorizationRequired:
            return L10n.string("Allow Screen Time access to start blocking.")
        case .emptySelection:
            return L10n.string("Choose at least one app, category, or website before starting a block.")
        case .invalidSchedule(let issue):
            switch issue {
            case .emptySchedule:
                return L10n.string("Add at least one time period.")
            case .zeroLengthPeriod:
                return L10n.string("A time period must have different start and end times.")
            case .overlappingPeriods:
                return L10n.string("Time periods cannot overlap, including across midnight.")
            case .monitorLimitExceeded(let limit):
                return String(format: L10n.string("This schedule uses too many time periods. Use up to %d weekday periods."), limit)
            }
        case .managedSettingsNotApplied:
            return L10n.string("Screen Time did not accept the blocking rules. Try again after reopening AntiScroll.")
        }
    }
}

final class ScheduleService {
    static let shared = ScheduleService()

    func startMonitoring(schedule: BlockSchedule) throws {
        guard ShieldStorage.shared.loadPremiumStatus() else {
            throw ScheduleServiceError.premiumRequired(L10n.string("Premium unlocks scheduled and recurring blocks."))
        }
        if let issue = schedule.validationIssue() {
            throw ScheduleServiceError.invalidSchedule(issue)
        }

        let protectsThisDevice = schedule.protectsCurrentDevice(
            defaultRemoteDeviceIDs: ShieldStorage.shared.loadSelectedMacDeviceIDs()
        )
        let transitionDate = Date()
        let wasScheduleEnabled = ShieldStorage.shared.loadScheduleEnabled()

        #if canImport(FamilyControls)
        let selection = ShieldStorage.shared.loadBlocklist(id: schedule.selectedBlocklistID)?.selection
            ?? ShieldStorage.shared.loadSelection()
        if protectsThisDevice {
            try validateHardBlock(selection)
        }
        if protectsThisDevice {
            // Persist before registering so an intervalDidStart callback can never race
            // ahead and apply a stale selection in the extension process.
            try ShieldStorage.shared.saveScheduledSelection(selection)
        }
        #endif

        #if canImport(DeviceActivity)
        let center = DeviceActivityCenter()
        let oldNames = ShieldStorage.shared.loadRegisteredScheduleActivityNames()
        let namesToStop = Array(Set(oldNames + SharedConfig.legacyDailyActivityNames))
            .map { DeviceActivityName($0) }
        if wasScheduleEnabled {
            ShieldStorage.shared.finishAllScheduledFocusAccounting(endedAt: transitionDate)
        }
        center.stopMonitoring(namesToStop)

        let descriptors = protectsThisDevice ? schedule.monitoringDescriptors : []
        ShieldStorage.shared.saveScheduledFocusDurations(
            Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0.durationMinutes) })
        )
        var registered: [DeviceActivityName] = []
        do {
            for descriptor in descriptors {
                let activity = DeviceActivityName(descriptor.id)
                let deviceSchedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(
                        hour: descriptor.startHour,
                        minute: descriptor.startMinute,
                        weekday: descriptor.startWeekday
                    ),
                    intervalEnd: DateComponents(
                        hour: descriptor.endHour,
                        minute: descriptor.endMinute,
                        weekday: descriptor.endWeekday
                    ),
                    repeats: true
                )
                try center.startMonitoring(activity, during: deviceSchedule)
                registered.append(activity)
            }
        } catch {
            center.stopMonitoring(registered)
            ShieldStorage.shared.saveScheduledFocusDurations([:])
            ShieldStorage.shared.saveRegisteredScheduleActivityNames([])
            ShieldStorage.shared.saveScheduleEnabled(false)
            throw error
        }
        #endif

        do {
            try ShieldStorage.shared.saveSchedule(schedule)

            #if canImport(FamilyControls) && canImport(ManagedSettings)
            if protectsThisDevice,
               let activeWindow = ActiveScheduledBlockWindow.activeWindow(for: schedule, now: transitionDate) {
                try applyHardShield(selection, storeName: SharedConfig.scheduledStoreName)
                try ShieldStorage.shared.saveActiveScheduledShieldSelection(selection)
                ShieldStorage.shared.startScheduledFocusAccounting(
                    activityName: activeWindow.activityName,
                    startedAt: transitionDate
                )
            } else {
                clearHardShield(storeName: SharedConfig.scheduledStoreName)
                try ShieldStorage.shared.saveActiveScheduledShieldSelection(nil)
            }
            #endif

            ShieldStorage.shared.saveRegisteredScheduleActivityNames(
                protectsThisDevice ? schedule.monitoringDescriptors.map(\.id) : []
            )
            // This is the commit point: the UI may report enabled only after monitor
            // registration, rule assignment verification, and persistence all succeeded.
            ShieldStorage.shared.saveScheduleEnabled(true)
        } catch {
            #if canImport(DeviceActivity)
            center.stopMonitoring(registered)
            #endif
            ShieldStorage.shared.saveScheduledFocusDurations([:])
            ShieldStorage.shared.saveRegisteredScheduleActivityNames([])
            ShieldStorage.shared.saveActiveScheduleActivityNames([])
            ShieldStorage.shared.saveScheduleEnabled(false)
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            clearHardShield(storeName: SharedConfig.scheduledStoreName)
            try? ShieldStorage.shared.saveActiveScheduledShieldSelection(nil)
            #endif
            throw error
        }

        Task { try? await MacBlockPlanSyncService.shared.publishCurrentConfiguration() }
    }

    @discardableResult
    func startImmediateBlock(
        durationMinutes: Int,
        start: Date = Date(),
        calendar: Calendar = .current,
        commitmentMode: QuickBlockCommitmentMode = .normal,
        focusTemplate: FocusTemplate? = nil
    ) throws -> ImmediateBlockSession {
        guard PremiumAccessPolicy.canStartQuickBlock(
            durationMinutes: durationMinutes,
            isPremium: ShieldStorage.shared.loadPremiumStatus(),
            commitmentMode: commitmentMode
        ) else {
            throw ScheduleServiceError.premiumRequired(L10n.string("Premium unlocks Quick Blocks longer than 2 hours."))
        }

        if let existing = ShieldStorage.shared.loadActiveImmediateSession(now: start),
           !QuickBlockStartGuard.canStartNewBlock(existing: existing, now: start) {
            throw ScheduleServiceError.immediateBlockAlreadyActive(
                QuickBlockStartGuard.activeBlockMessage(existing: existing, now: start)
            )
        }

        #if canImport(FamilyControls)
        let selection = ShieldStorage.shared.loadSelection()
        try validateHardBlock(selection)
        #endif

        let session = ImmediateBlockSession(
            start: start,
            durationMinutes: durationMinutes,
            calendar: calendar,
            commitmentMode: commitmentMode
        )

        // Make the immutable session snapshot available to the monitor extension
        // before registration. The mutable global picker must never replace an
        // already-started commitment block if the callback is delivered later.
        #if canImport(FamilyControls)
        do {
            try ShieldStorage.shared.saveActiveImmediateShieldSelection(selection)
        } catch {
            try? ShieldStorage.shared.saveActiveImmediateShieldSelection(nil)
            throw error
        }
        #endif

        #if canImport(DeviceActivity)
        let center = DeviceActivityCenter()
        let activity = DeviceActivityName(SharedConfig.immediateActivityName)
        center.stopMonitoring([activity])
        let monitoringStart = start.addingTimeInterval(-1)
        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: monitoringStart),
            intervalEnd: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: session.end),
            repeats: false
        )
        do {
            try center.startMonitoring(activity, during: deviceSchedule)
        } catch {
            center.stopMonitoring([activity])
            #if canImport(FamilyControls)
            try? ShieldStorage.shared.saveActiveImmediateShieldSelection(nil)
            #endif
            throw error
        }
        #endif

        do {
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            try applyHardShield(selection, storeName: SharedConfig.immediateStoreName)
            #endif
            try ShieldStorage.shared.saveActiveImmediateSession(session)
            ShieldStorage.shared.saveActiveFocusTemplate(focusTemplate)
            try ShieldStorage.shared.saveFocusCompletionPrompt(FocusCompletionPrompt(session: session))
            return session
        } catch {
            #if canImport(DeviceActivity)
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(SharedConfig.immediateActivityName)])
            #endif
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            clearHardShield(storeName: SharedConfig.immediateStoreName)
            try? ShieldStorage.shared.saveActiveImmediateShieldSelection(nil)
            #endif
            ShieldStorage.shared.clearActiveImmediateSession()
            ShieldStorage.shared.clearFocusCompletionPrompt()
            throw error
        }
    }

    @discardableResult
    func reconcileImmediateShield(now: Date = Date()) throws -> ImmediateBlockSession? {
        // Discard a stored session that already expired without an end callback.
        ShieldStorage.shared.clearExpiredImmediateSession(now: now)
        let session = ShieldStorage.shared.loadActiveImmediateSession(now: now)

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        let selection = ShieldStorage.shared.loadActiveImmediateShieldSelection()
        let hasEffectiveSelection = selection.map {
            !$0.applicationTokens.isEmpty
                || !$0.categoryTokens.isEmpty
                || !$0.webDomainTokens.isEmpty
                || !automaticWebDomains.isEmpty
        } ?? false
        let settingsMatch = selection.map {
            hardShieldMatches($0, storeName: SharedConfig.immediateStoreName)
        } ?? false
        let action = ImmediateShieldReconciliationPolicy.action(
            hasActiveSession: session != nil,
            isAuthorized: AuthorizationCenter.shared.authorizationStatus == .approved,
            hasSelection: hasEffectiveSelection,
            settingsMatch: settingsMatch
        )

        switch action {
        case .clearStaleEnforcement:
            clearImmediateEnforcement()
            return nil
        case .invalidateAuthorization:
            // Authorization was revoked or denied while a session is stored:
            // the session can never be enforced again, so invalidate it fully.
            clearImmediateEnforcement(force: true)
            ShieldStorage.shared.clearFocusCompletionPrompt()
            throw ScheduleServiceError.authorizationRequired
        case .invalidateSelection:
            // The persisted snapshot lost its effective selection while a
            // session is stored: this is corrupt state that must not linger.
            clearImmediateEnforcement(force: true)
            ShieldStorage.shared.clearFocusCompletionPrompt()
            throw ScheduleServiceError.emptySelection
        case .reapplyShield:
            guard let session, let selection else {
                clearImmediateEnforcement(force: true)
                ShieldStorage.shared.clearFocusCompletionPrompt()
                throw ScheduleServiceError.managedSettingsNotApplied
            }
            do {
                try validateHardBlock(selection)
                try applyHardShield(selection, storeName: SharedConfig.immediateStoreName)
                return session
            } catch {
                // Keep the active commitment and its persisted snapshot intact:
                // a transient ManagedSettings failure must not delete the block.
                // The next launch/foreground reconciliation retries reapplication.
                throw error
            }
        case .verified:
            return session
        }
        #else
        return session
        #endif
    }

    /// Stops only recurring schedule monitors. Quick Block has an independent activity and store.
    func stopMonitoring() {
        ShieldStorage.shared.finishAllScheduledFocusAccounting()
        ShieldStorage.shared.saveScheduledFocusDurations([:])
        #if canImport(DeviceActivity)
        let names = Array(Set(ShieldStorage.shared.loadRegisteredScheduleActivityNames() + SharedConfig.legacyDailyActivityNames))
        DeviceActivityCenter().stopMonitoring(names.map { DeviceActivityName($0) })
        #endif
        ShieldStorage.shared.saveRegisteredScheduleActivityNames([])
        ShieldStorage.shared.saveActiveScheduleActivityNames([])
        ShieldStorage.shared.saveScheduleEnabled(false)
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        clearHardShield(storeName: SharedConfig.scheduledStoreName)
        try? ShieldStorage.shared.saveActiveScheduledShieldSelection(nil)
        #endif
        Task { try? await MacBlockPlanSyncService.shared.publishCurrentConfiguration() }
    }

    func reconcileScheduleShield(now: Date = Date()) throws {
        guard ShieldStorage.shared.loadScheduleEnabled() else {
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            clearHardShield(storeName: SharedConfig.scheduledStoreName)
            try ShieldStorage.shared.saveActiveScheduledShieldSelection(nil)
            #endif
            return
        }

        let schedule = ShieldStorage.shared.loadSchedule()
        guard schedule.protectsCurrentDevice(defaultRemoteDeviceIDs: ShieldStorage.shared.loadSelectedMacDeviceIDs()) else {
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            clearHardShield(storeName: SharedConfig.scheduledStoreName)
            try ShieldStorage.shared.saveActiveScheduledShieldSelection(nil)
            #endif
            return
        }

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        let selection = ShieldStorage.shared.loadScheduledSelection() ?? ShieldStorage.shared.loadSelection()
        do {
            try validateHardBlock(selection)
        } catch {
            stopMonitoring()
            throw error
        }
        if let activeWindow = ActiveScheduledBlockWindow.activeWindow(for: schedule, now: now) {
            try applyHardShield(selection, storeName: SharedConfig.scheduledStoreName)
            try ShieldStorage.shared.saveActiveScheduledShieldSelection(selection)
            ShieldStorage.shared.startScheduledFocusAccounting(
                activityName: activeWindow.activityName,
                startedAt: now
            )
        } else {
            clearHardShield(storeName: SharedConfig.scheduledStoreName)
            try ShieldStorage.shared.saveActiveScheduledShieldSelection(nil)
        }
        #endif
    }

    func isScheduledShieldApplied(now: Date = Date()) -> Bool {
        guard ShieldStorage.shared.loadScheduleEnabled(),
              ActiveScheduledBlockWindow.activeWindow(for: ShieldStorage.shared.loadSchedule(), now: now) != nil else {
            return false
        }
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        guard let selection = ShieldStorage.shared.loadActiveScheduledShieldSelection() else { return false }
        return hardShieldMatches(selection, storeName: SharedConfig.scheduledStoreName)
        #else
        return false
        #endif
    }

    func recordImmediateBlockCompletion(
        _ session: ImmediateBlockSession,
        completedAt: Date = Date(),
        calendar: Calendar = .current,
        presentsFocusComplete: Bool = false
    ) {
        let storedPrompt = ShieldStorage.shared.loadFocusCompletionPrompt()
        let matchesStoredSession = storedPrompt?.session.start == session.start
            && storedPrompt?.session.durationMinutes == session.durationMinutes
        if !(matchesStoredSession && storedPrompt?.progressRecorded == true) {
            var stats = ShieldStorage.shared.loadFocusStats()
            stats.recordCompleted(session: session, completedAt: completedAt, calendar: calendar)
            try? ShieldStorage.shared.saveFocusStats(stats)
        }

        if presentsFocusComplete {
            try? ShieldStorage.shared.saveFocusCompletionPrompt(
                FocusCompletionPrompt(session: session, progressRecorded: true)
            )
        } else {
            ShieldStorage.shared.clearFocusCompletionPrompt()
        }
        ShieldStorage.shared.clearActiveImmediateSession()
    }

    /// Records a naturally finished Quick Block once, keeps its calm completion
    /// screen available for one hour, and expires that prompt without losing stats.
    func reconcileFocusCompletionPrompt(now: Date = Date(), calendar: Calendar = .current) -> FocusCompletionPrompt? {
        guard var prompt = ShieldStorage.shared.loadFocusCompletionPrompt() else { return nil }
        guard now >= prompt.completedAt else { return nil }

        if !prompt.progressRecorded {
            var stats = ShieldStorage.shared.loadFocusStats()
            stats.recordCompleted(session: prompt.session, completedAt: prompt.completedAt, calendar: calendar)
            try? ShieldStorage.shared.saveFocusStats(stats)
            try? ShieldStorage.shared.saveAccountabilityReceipt(
                AccountabilityReceipt(protectedMinutes: prompt.session.durationMinutes)
            )
            prompt.progressRecorded = true
            try? ShieldStorage.shared.saveFocusCompletionPrompt(prompt)
        }

        guard prompt.isAvailable(at: now) else {
            ShieldStorage.shared.clearFocusCompletionPrompt()
            return nil
        }
        return prompt
    }

    func dismissFocusCompletionPrompt() {
        ShieldStorage.shared.clearFocusCompletionPrompt()
    }

    func stopImmediateBlock(force: Bool = false, preserveFocusCompletion: Bool = false) {
        clearImmediateEnforcement(force: force)
        if !preserveFocusCompletion {
            ShieldStorage.shared.clearFocusCompletionPrompt()
        }
    }

    private func clearImmediateEnforcement(force: Bool = false) {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        // A stale stop/clear call (for example a callback racing a fresh start)
        // must never erase a newer commitment that is still active.
        guard force || !ShieldStorage.shared.hasActiveImmediateSession() else { return }
        #endif
        #if canImport(DeviceActivity)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(SharedConfig.immediateActivityName)])
        #endif
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        clearHardShield(storeName: SharedConfig.immediateStoreName)
        try? ShieldStorage.shared.saveActiveImmediateShieldSelection(nil)
        #endif
        ShieldStorage.shared.clearActiveImmediateSession()
    }

    #if canImport(FamilyControls) && canImport(ManagedSettings)
    private var automaticWebDomains: [String] {
        UserDefaults(suiteName: SharedConfig.appGroupIdentifier)?
            .stringArray(forKey: SharedConfig.automaticWebDomainsKey) ?? []
    }

    private func validateHardBlock(_ selection: FamilyActivitySelection) throws {
        let failure = HardBlockActivationPreflight.failure(
            isAuthorized: AuthorizationCenter.shared.authorizationStatus == .approved,
            applicationCount: selection.applicationTokens.count,
            categoryCount: selection.categoryTokens.count,
            webDomainCount: selection.webDomainTokens.count + automaticWebDomains.count
        )
        switch failure {
        case .authorizationRequired: throw ScheduleServiceError.authorizationRequired
        case .emptySelection: throw ScheduleServiceError.emptySelection
        case nil: return
        }
    }

    private func applyHardShield(_ selection: FamilyActivitySelection, storeName: String) throws {
        let store = ManagedSettingsStore(named: .init(storeName))
        let applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        let categories: ShieldSettings.ActivityCategoryPolicy<Application>? = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        let webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        store.shield.applications = applications
        store.shield.applicationCategories = categories
        store.shield.webDomains = webDomains

        let expectedWebFilter: WebContentSettings.FilterPolicy? = automaticWebDomains.isEmpty
            ? nil
            : .specific(Set(automaticWebDomains.map { WebDomain(domain: $0) }))
        store.webContent.blockedByFilter = expectedWebFilter

        guard store.shield.applications == applications,
              store.shield.applicationCategories == categories,
              store.shield.webDomains == webDomains,
              store.webContent.blockedByFilter == expectedWebFilter else {
            store.clearAllSettings()
            throw ScheduleServiceError.managedSettingsNotApplied
        }
    }

    private func hardShieldMatches(_ selection: FamilyActivitySelection, storeName: String) -> Bool {
        let store = ManagedSettingsStore(named: .init(storeName))
        let applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        let categories: ShieldSettings.ActivityCategoryPolicy<Application>? = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        let webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        let expectedWebFilter: WebContentSettings.FilterPolicy? = automaticWebDomains.isEmpty
            ? nil
            : .specific(Set(automaticWebDomains.map { WebDomain(domain: $0) }))
        return store.shield.applications == applications
            && store.shield.applicationCategories == categories
            && store.shield.webDomains == webDomains
            && store.webContent.blockedByFilter == expectedWebFilter
    }

    private func clearHardShield(storeName: String) {
        ManagedSettingsStore(named: .init(storeName)).clearAllSettings()
    }

    func setDelayAppsEnabled(_ isEnabled: Bool, selection: FamilyActivitySelection? = nil) throws {
        ShieldStorage.shared.clearDelayAppsWait()
        if isEnabled {
            let targetSelection = selection ?? ShieldStorage.shared.loadDelaySelection()
            do {
                try validateHardBlock(targetSelection)
                try applyDelayAppsShield(selection: targetSelection)
                ShieldStorage.shared.saveDelayAppsEnabled(true)
            } catch {
                clearDelayAppsShield()
                ShieldStorage.shared.saveDelayAppsEnabled(false)
                throw error
            }
        } else {
            clearDelayAppsShield()
            ShieldStorage.shared.saveDelayAppsEnabled(false)
        }
    }

    func updateDelayAppsSelection(_ selection: FamilyActivitySelection) throws {
        ShieldStorage.shared.clearDelayAppsWait()
        if ShieldStorage.shared.loadDelayAppsEnabled() {
            do {
                try validateHardBlock(selection)
                try ShieldStorage.shared.saveDelaySelection(selection)
                try applyDelayAppsShield(selection: selection)
            } catch {
                clearDelayAppsShield()
                ShieldStorage.shared.saveDelayAppsEnabled(false)
                // Preserve the new picker choice while keeping Delay Apps off;
                // selection and enforcement state must not contradict each other.
                try? ShieldStorage.shared.saveDelaySelection(selection)
                throw error
            }
        } else {
            try ShieldStorage.shared.saveDelaySelection(selection)
        }
    }

    func refreshDelayAppsShieldIfNeeded() throws {
        guard ShieldStorage.shared.loadDelayAppsEnabled() else { return }
        let selection = ShieldStorage.shared.loadDelaySelection()
        do {
            try validateHardBlock(selection)
            try applyDelayAppsShield(selection: selection)
        } catch {
            clearDelayAppsShield()
            ShieldStorage.shared.saveDelayAppsEnabled(false)
            throw error
        }
    }

    private func applyDelayAppsShield(selection: FamilyActivitySelection) throws {
        let delayStore = ManagedSettingsStore(named: .init("delay-apps"))
        let applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        let categories: ShieldSettings.ActivityCategoryPolicy<Application>? = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        let webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        delayStore.shield.applications = applications
        delayStore.shield.applicationCategories = categories
        delayStore.shield.webDomains = webDomains

        guard delayStore.shield.applications == applications,
              delayStore.shield.applicationCategories == categories,
              delayStore.shield.webDomains == webDomains else {
            delayStore.clearAllSettings()
            throw ScheduleServiceError.managedSettingsNotApplied
        }
    }

    @discardableResult
    func addToActiveHardBlock(
        _ additionalSelection: FamilyActivitySelection,
        now: Date = Date()
    ) throws -> FamilyActivitySelection? {
        guard ShieldStorage.shared.loadActiveImmediateSession(now: now) != nil,
              let currentSelection = ShieldStorage.shared.loadActiveImmediateShieldSelection() else {
            return nil
        }

        var merged = currentSelection
        merged.applicationTokens.formUnion(additionalSelection.applicationTokens)
        merged.categoryTokens.formUnion(additionalSelection.categoryTokens)
        merged.webDomainTokens.formUnion(additionalSelection.webDomainTokens)
        try validateHardBlock(merged)

        // Persist the expanded session snapshot before changing enforcement so
        // the monitor extension can never reapply the older, smaller selection.
        do {
            try ShieldStorage.shared.saveActiveImmediateShieldSelection(merged)
            try applyHardShield(merged, storeName: SharedConfig.immediateStoreName)
            return merged
        } catch {
            // Keep the existing commitment intact if Screen Time rejects the
            // expanded rules or persistence fails partway through the update.
            try? ShieldStorage.shared.saveActiveImmediateShieldSelection(currentSelection)
            try? applyHardShield(currentSelection, storeName: SharedConfig.immediateStoreName)
            throw error
        }
    }

    func clearDelayAppsShield() {
        ManagedSettingsStore(named: .init("delay-apps")).clearAllSettings()
    }

    func setAdultWebFilterEnabled(_ isEnabled: Bool) {
        ShieldStorage.shared.saveAdultWebFilterEnabled(isEnabled)
        refreshAdultWebFilterIfNeeded()
        Task { try? await MacBlockPlanSyncService.shared.publishCurrentConfiguration() }
    }

    func refreshAdultWebFilterIfNeeded() {
        let adultStore = ManagedSettingsStore(named: .init("adult-web-content"))
        guard ShieldStorage.shared.loadAdultWebFilterEnabled() else {
            adultStore.webContent.blockedByFilter = nil
            return
        }
        adultStore.webContent.blockedByFilter = .auto()
    }
    #endif
}
