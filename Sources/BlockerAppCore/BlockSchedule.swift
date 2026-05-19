import Foundation

public struct BlockSchedule: Codable, Equatable, Sendable {
    public static let allWeekdays = Set(1...7)
    public static let orderedWeekdays: [(weekday: Int, shortName: String, fullName: String)] = [
        (2, "Mon", "Monday"),
        (3, "Tue", "Tuesday"),
        (4, "Wed", "Wednesday"),
        (5, "Thu", "Thursday"),
        (6, "Fri", "Friday"),
        (7, "Sat", "Saturday"),
        (1, "Sun", "Sunday")
    ]

    public let startHour: Int
    public let startMinute: Int
    public let endHour: Int
    public let endMinute: Int
    public let selectedWeekdays: Set<Int>

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, selectedWeekdays: Set<Int> = BlockSchedule.allWeekdays) throws {
        guard (0...23).contains(startHour), (0...23).contains(endHour) else {
            throw ValidationError.invalidHour
        }
        guard (0...59).contains(startMinute), (0...59).contains(endMinute) else {
            throw ValidationError.invalidMinute
        }
        let filteredWeekdays = selectedWeekdays.filter { (1...7).contains($0) }
        guard filteredWeekdays.count == selectedWeekdays.count else {
            throw ValidationError.invalidWeekday
        }
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.selectedWeekdays = filteredWeekdays
    }

    public enum ValidationError: Error, Equatable {
        case invalidHour
        case invalidMinute
        case invalidWeekday
    }

    enum CodingKeys: String, CodingKey {
        case startHour
        case startMinute
        case endHour
        case endMinute
        case selectedWeekdays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startHour = try container.decode(Int.self, forKey: .startHour)
        let startMinute = try container.decode(Int.self, forKey: .startMinute)
        let endHour = try container.decode(Int.self, forKey: .endHour)
        let endMinute = try container.decode(Int.self, forKey: .endMinute)
        let selectedWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .selectedWeekdays) ?? BlockSchedule.allWeekdays
        try self.init(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute, selectedWeekdays: selectedWeekdays)
    }

    public var startTotalMinutes: Int { startHour * 60 + startMinute }
    public var endTotalMinutes: Int { endHour * 60 + endMinute }

    public var crossesMidnight: Bool {
        endTotalMinutes <= startTotalMinutes
    }

    public var selectedWeekdaySymbols: [String] {
        BlockSchedule.orderedWeekdays
            .filter { selectedWeekdays.contains($0.weekday) }
            .map(\.shortName)
    }

    public var selectedWeekdaySummary: String {
        if selectedWeekdays == BlockSchedule.allWeekdays {
            return "Every day"
        }
        if selectedWeekdays == Set(2...6) {
            return "Weekdays"
        }
        if selectedWeekdays == Set([1, 7]) {
            return "Weekends"
        }
        return selectedWeekdaySymbols.joined(separator: ", ")
    }

    public func contains(hour: Int, minute: Int) -> Bool {
        let current = hour * 60 + minute
        if crossesMidnight {
            return current >= startTotalMinutes || current < endTotalMinutes
        }
        return current >= startTotalMinutes && current < endTotalMinutes
    }

    public func contains(weekday: Int, hour: Int, minute: Int) -> Bool {
        selectedWeekdays.contains(weekday) && contains(hour: hour, minute: minute)
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

    public func endTimeLabel(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = calendar.isDate(end, inSameDayAs: date) ? .none : .medium
        return formatter.string(from: end)
    }
}
