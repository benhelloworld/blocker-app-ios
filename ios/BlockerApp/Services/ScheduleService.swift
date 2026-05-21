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

final class ScheduleService {
    static let shared = ScheduleService()

    func startMonitoring(schedule: BlockSchedule) throws {
        try ShieldStorage.shared.saveSchedule(schedule)

        #if canImport(DeviceActivity)
        let center = DeviceActivityCenter()
        center.stopMonitoring(SharedConfig.allDailyActivityNames.map { DeviceActivityName($0) })

        for weekday in schedule.selectedWeekdays.sorted() {
            let activity = DeviceActivityName(SharedConfig.dailyActivityName(for: weekday))
            let deviceSchedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: schedule.startHour, minute: schedule.startMinute, weekday: weekday),
                intervalEnd: DateComponents(hour: schedule.endHour, minute: schedule.endMinute, weekday: weekday),
                repeats: true
            )
            try center.startMonitoring(activity, during: deviceSchedule)
        }
        #endif
    }

    @discardableResult
    func startImmediateBlock(durationMinutes: Int, start: Date = Date(), calendar: Calendar = .current) throws -> ImmediateBlockSession {
        let session = ImmediateBlockSession(start: start, durationMinutes: durationMinutes, calendar: calendar)

        try ShieldStorage.shared.saveActiveImmediateSession(session)
        var stats = ShieldStorage.shared.loadFocusStats()
        stats.record(session: session, calendar: calendar)
        try ShieldStorage.shared.saveFocusStats(stats)

        #if canImport(DeviceActivity)
        let center = DeviceActivityCenter()
        let activity = DeviceActivityName(SharedConfig.immediateActivityName)
        center.stopMonitoring([activity])
        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: session.start),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: session.end),
            repeats: false
        )
        try center.startMonitoring(activity, during: deviceSchedule)
        #endif

        return session
    }

    func stopMonitoring() {
        #if canImport(DeviceActivity)
        let dailyActivities = SharedConfig.allDailyActivityNames.map { DeviceActivityName($0) }
        DeviceActivityCenter().stopMonitoring(dailyActivities + [DeviceActivityName(SharedConfig.immediateActivityName)])
        #endif
        ShieldStorage.shared.clearActiveImmediateSession()
    }

    func stopImmediateBlock() {
        #if canImport(DeviceActivity)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(SharedConfig.immediateActivityName)])
        #endif
        ShieldStorage.shared.clearActiveImmediateSession()
    }

    #if canImport(FamilyControls) && canImport(ManagedSettings)
    func setDelayAppsEnabled(_ isEnabled: Bool, selection: FamilyActivitySelection? = nil) throws {
        ShieldStorage.shared.saveDelayAppsEnabled(isEnabled)
        if isEnabled {
            try applyDelayAppsShield(selection: selection ?? ShieldStorage.shared.loadDelaySelection())
        } else {
            clearDelayAppsShield()
        }
    }

    func updateDelayAppsSelection(_ selection: FamilyActivitySelection) throws {
        try ShieldStorage.shared.saveDelaySelection(selection)
        if ShieldStorage.shared.loadDelayAppsEnabled() {
            try applyDelayAppsShield(selection: selection)
        }
    }

    private func applyDelayAppsShield(selection: FamilyActivitySelection) throws {
        let delayStore = ManagedSettingsStore(named: .init("delay-apps"))
        delayStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        delayStore.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        delayStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func clearDelayAppsShield() {
        let delayStore = ManagedSettingsStore(named: .init("delay-apps"))
        delayStore.clearAllSettings()
    }
    #endif

}
