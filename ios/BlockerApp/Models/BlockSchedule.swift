import Foundation

struct BlockSchedule: Codable, Equatable {
    static let allWeekdays = Set(1...7)
    static let orderedWeekdays: [(weekday: Int, shortName: String, fullName: String)] = [
        (2, "Mon", "Monday"),
        (3, "Tue", "Tuesday"),
        (4, "Wed", "Wednesday"),
        (5, "Thu", "Thursday"),
        (6, "Fri", "Friday"),
        (7, "Sat", "Saturday"),
        (1, "Sun", "Sunday")
    ]

    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var selectedWeekdays: Set<Int>

    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, selectedWeekdays: Set<Int> = BlockSchedule.allWeekdays) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.selectedWeekdays = selectedWeekdays.filter { (1...7).contains($0) }
    }

    enum CodingKeys: String, CodingKey {
        case startHour
        case startMinute
        case endHour
        case endMinute
        case selectedWeekdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startHour = try container.decode(Int.self, forKey: .startHour)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endHour = try container.decode(Int.self, forKey: .endHour)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        selectedWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .selectedWeekdays) ?? BlockSchedule.allWeekdays
        selectedWeekdays = selectedWeekdays.filter { (1...7).contains($0) }
    }

    var startTotalMinutes: Int { startHour * 60 + startMinute }
    var endTotalMinutes: Int { endHour * 60 + endMinute }
    var crossesMidnight: Bool { endTotalMinutes <= startTotalMinutes }

    var selectedWeekdaySymbols: [String] {
        BlockSchedule.orderedWeekdays
            .filter { selectedWeekdays.contains($0.weekday) }
            .map(\.shortName)
    }

    var selectedWeekdaySummary: String {
        if selectedWeekdays == BlockSchedule.allWeekdays {
            return "Every day"
        }

        let weekdaySet = Set(2...6)
        if selectedWeekdays == weekdaySet {
            return "Weekdays"
        }

        let weekendSet: Set<Int> = [1, 7]
        if selectedWeekdays == weekendSet {
            return "Weekends"
        }

        return selectedWeekdaySymbols.joined(separator: ", ")
    }

    func contains(hour: Int, minute: Int) -> Bool {
        let current = hour * 60 + minute
        if crossesMidnight {
            return current >= startTotalMinutes || current < endTotalMinutes
        }
        return current >= startTotalMinutes && current < endTotalMinutes
    }

    func contains(weekday: Int, hour: Int, minute: Int) -> Bool {
        selectedWeekdays.contains(weekday) && contains(hour: hour, minute: minute)
    }

    static let defaultFocus = BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
}

struct ImmediateBlockSession: Codable, Equatable {
    let start: Date
    let durationMinutes: Int
    let calendar: Calendar

    init(start: Date = Date(), durationMinutes: Int, calendar: Calendar = .current) {
        self.start = start
        self.durationMinutes = max(1, durationMinutes)
        self.calendar = calendar
    }

    var end: Date {
        calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
    }

    var schedule: BlockSchedule {
        let startParts = calendar.dateComponents([.hour, .minute], from: start)
        let endParts = calendar.dateComponents([.hour, .minute], from: end)
        return BlockSchedule(
            startHour: startParts.hour ?? 0,
            startMinute: startParts.minute ?? 0,
            endHour: endParts.hour ?? 0,
            endMinute: endParts.minute ?? 0
        )
    }

    var durationLabel: String {
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

    func isActive(at date: Date = Date()) -> Bool {
        date >= start && date < end
    }

    func remainingMinutes(at date: Date = Date()) -> Int {
        guard date < end else { return 0 }
        let seconds = end.timeIntervalSince(date)
        return max(0, Int(ceil(seconds / 60)))
    }

    func progress(at date: Date = Date()) -> Double {
        guard durationMinutes > 0 else { return 1 }
        if date <= start { return 0 }
        if date >= end { return 1 }
        let elapsedSeconds = date.timeIntervalSince(start)
        let totalSeconds = TimeInterval(durationMinutes * 60)
        return min(1, max(0, elapsedSeconds / totalSeconds))
    }

    func endTimeLabel(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = calendar.isDate(end, inSameDayAs: date) ? .none : .medium
        return formatter.string(from: end)
    }
}
