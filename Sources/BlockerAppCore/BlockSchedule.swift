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

public struct ImmediateBlockSession: Codable, Equatable, Sendable {
    public let start: Date
    public let durationMinutes: Int
    public let calendar: Calendar

    public init(start: Date = Date(), durationMinutes: Int, calendar: Calendar = .current) {
        self.start = start
        self.durationMinutes = max(1, durationMinutes)
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

    public func isActive(at date: Date = Date()) -> Bool {
        date >= start && date < end
    }

    public func remainingMinutes(at date: Date = Date()) -> Int {
        guard date < end else { return 0 }
        let seconds = end.timeIntervalSince(date)
        return max(0, Int(ceil(seconds / 60)))
    }

    public func progress(at date: Date = Date()) -> Double {
        guard durationMinutes > 0 else { return 1 }
        if date <= start { return 0 }
        if date >= end { return 1 }
        let elapsedSeconds = date.timeIntervalSince(start)
        let totalSeconds = TimeInterval(durationMinutes * 60)
        return min(1, max(0, elapsedSeconds / totalSeconds))
    }
}
