import Foundation

public struct BlockSchedule: Codable, Equatable, Sendable {
    public let startHour: Int
    public let startMinute: Int
    public let endHour: Int
    public let endMinute: Int

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) throws {
        guard (0...23).contains(startHour), (0...23).contains(endHour) else {
            throw ValidationError.invalidHour
        }
        guard (0...59).contains(startMinute), (0...59).contains(endMinute) else {
            throw ValidationError.invalidMinute
        }
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    public enum ValidationError: Error, Equatable {
        case invalidHour
        case invalidMinute
    }

    public var startTotalMinutes: Int { startHour * 60 + startMinute }
    public var endTotalMinutes: Int { endHour * 60 + endMinute }

    public var crossesMidnight: Bool {
        endTotalMinutes <= startTotalMinutes
    }

    public func contains(hour: Int, minute: Int) -> Bool {
        let current = hour * 60 + minute
        if crossesMidnight {
            return current >= startTotalMinutes || current < endTotalMinutes
        }
        return current >= startTotalMinutes && current < endTotalMinutes
    }
}

public struct ImmediateBlockSession: Equatable, Sendable {
    public let start: Date
    public let durationMinutes: Int
    public let calendar: Calendar

    public init(start: Date = Date(), durationMinutes: Int, calendar: Calendar = .current) {
        self.start = start
        self.durationMinutes = durationMinutes
        self.calendar = calendar
    }

    public var end: Date {
        calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
    }

    public var schedule: BlockSchedule {
        let startParts = calendar.dateComponents([.hour, .minute], from: start)
        let endParts = calendar.dateComponents([.hour, .minute], from: end)
        return try! BlockSchedule(
            startHour: startParts.hour ?? 0,
            startMinute: startParts.minute ?? 0,
            endHour: endParts.hour ?? 0,
            endMinute: endParts.minute ?? 0
        )
    }

    public var durationLabel: String {
        if durationMinutes % 60 == 0 {
            let hours = durationMinutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }

        if durationMinutes > 60 {
            let value = Double(durationMinutes) / 60.0
            return "\(value.formatted(.number.precision(.fractionLength(1)))) hours"
        }

        return durationMinutes == 1 ? "1 minute" : "\(durationMinutes) minutes"
    }
}
