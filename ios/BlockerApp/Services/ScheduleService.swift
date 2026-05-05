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

    func stopMonitoring() {
        #if canImport(DeviceActivity)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(SharedConfig.activityName)])
        #endif
    }
}
