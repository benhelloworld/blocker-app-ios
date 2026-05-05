import Foundation

struct BlockSchedule: Codable, Equatable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    var startTotalMinutes: Int { startHour * 60 + startMinute }
    var endTotalMinutes: Int { endHour * 60 + endMinute }
    var crossesMidnight: Bool { endTotalMinutes <= startTotalMinutes }

    func contains(hour: Int, minute: Int) -> Bool {
        let current = hour * 60 + minute
        if crossesMidnight {
            return current >= startTotalMinutes || current < endTotalMinutes
        }
        return current >= startTotalMinutes && current < endTotalMinutes
    }

    static let defaultFocus = BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
}
