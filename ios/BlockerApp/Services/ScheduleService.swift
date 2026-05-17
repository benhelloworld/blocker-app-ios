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
        let activity = DeviceActivityName(SharedConfig.activityName)
        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.startHour, minute: schedule.startMinute),
            intervalEnd: DateComponents(hour: schedule.endHour, minute: schedule.endMinute),
            repeats: true
        )
        try center.startMonitoring(activity, during: deviceSchedule)
        #endif
    }

    func startImmediateBlock(durationMinutes: Int, start: Date = Date(), calendar: Calendar = .current) throws -> ImmediateBlockSession {
        let session = ImmediateBlockSession(start: start, durationMinutes: durationMinutes, calendar: calendar)

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
        DeviceActivityCenter().stopMonitoring([
            DeviceActivityName(SharedConfig.activityName),
            DeviceActivityName(SharedConfig.immediateActivityName)
        ])
        #endif
    }

    func stopImmediateBlock() {
        #if canImport(DeviceActivity)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(SharedConfig.immediateActivityName)])
        #endif
    }
}
