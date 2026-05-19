import Foundation
#if canImport(DeviceActivity)
import DeviceActivity
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
}
