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
