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


struct FocusStats: Codable, Equatable {
    var totalSessions: Int
    var totalPlannedMinutes: Int
    var focusDayStamps: Set<String>
    var lastSessionStart: Date?

    init(totalSessions: Int = 0, totalPlannedMinutes: Int = 0, focusDayStamps: Set<String> = [], lastSessionStart: Date? = nil) {
        self.totalSessions = totalSessions
        self.totalPlannedMinutes = totalPlannedMinutes
        self.focusDayStamps = focusDayStamps
        self.lastSessionStart = lastSessionStart
    }

    var focusDayCount: Int { focusDayStamps.count }

    var totalHoursLabel: String {
        guard totalPlannedMinutes > 0 else { return "0h" }
        let hours = Double(totalPlannedMinutes) / 60.0
        if totalPlannedMinutes % 60 == 0 {
            return "\(Int(hours))h"
        }
        return "\(hours.formatted(.number.precision(.fractionLength(1))))h"
    }

    mutating func record(session: ImmediateBlockSession, calendar: Calendar = .current) {
        totalSessions += 1
        totalPlannedMinutes += session.durationMinutes
        lastSessionStart = session.start
        focusDayStamps.insert(Self.dayStamp(for: session.start, calendar: calendar))
    }

    func currentStreakDays(asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: date)
        while focusDayStamps.contains(Self.dayStamp(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    private static func dayStamp(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}


enum FrictionUnlockReason: String, CaseIterable, Codable, Equatable {
    case bored
    case stressed
    case tired
    case habit
    case needSomethingImportant
    case other

    static var allOptions: [FrictionUnlockReason] { allCases }

    var title: String {
        switch self {
        case .bored: return "Bored"
        case .stressed: return "Stressed"
        case .tired: return "Tired"
        case .habit: return "Habit"
        case .needSomethingImportant: return "Need something important"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .bored: return "face.dashed"
        case .stressed: return "cloud.bolt.fill"
        case .tired: return "bed.double.fill"
        case .habit: return "repeat"
        case .needSomethingImportant: return "exclamationmark.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct FrictionUnlockReflection: Codable, Equatable {
    var blockReason: String
    var stopReason: FrictionUnlockReason?
    var otherStopReason: String
    var completedAt: Date

    init(blockReason: String, stopReason: FrictionUnlockReason? = nil, otherStopReason: String = "", completedAt: Date = Date()) {
        self.blockReason = blockReason
        self.stopReason = stopReason
        self.otherStopReason = otherStopReason
        self.completedAt = completedAt
    }

    var isComplete: Bool {
        let hasBlockReason = !blockReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasBlockReason, let stopReason else { return false }
        if stopReason == .other {
            return !otherStopReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
}


struct DelayModeConfiguration: Codable, Equatable {
    var waitSeconds: Int
    var title: String
    var message: String

    static let `default` = DelayModeConfiguration(
        waitSeconds: 30,
        title: "Wait 30 seconds",
        message: "If you still want it, continue."
    )
}


struct DelayAppsConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var appCount: Int
    var categoryCount: Int
    var webDomainCount: Int
    var waitSeconds: Int

    init(isEnabled: Bool = false, appCount: Int = 0, categoryCount: Int = 0, webDomainCount: Int = 0, waitSeconds: Int = DelayModeConfiguration.default.waitSeconds) {
        self.isEnabled = isEnabled
        self.appCount = max(0, appCount)
        self.categoryCount = max(0, categoryCount)
        self.webDomainCount = max(0, webDomainCount)
        self.waitSeconds = max(1, waitSeconds)
    }

    var totalSelectionCount: Int { appCount + categoryCount + webDomainCount }
    var hasSelection: Bool { totalSelectionCount > 0 }

    func clearedSelection() -> DelayAppsConfiguration {
        DelayAppsConfiguration(isEnabled: isEnabled, waitSeconds: waitSeconds)
    }
}

enum FocusTemplate: String, CaseIterable, Codable, Equatable {
    case work
    case sleep
    case morning
    case study
    case gym

    static var allPresets: [FocusTemplate] { [.work, .sleep, .morning, .study, .gym] }

    var name: String {
        switch self {
        case .work: return "Work Mode"
        case .sleep: return "Sleep Mode"
        case .morning: return "Morning Mode"
        case .study: return "Study Mode"
        case .gym: return "Gym Mode"
        }
    }

    var systemImage: String {
        switch self {
        case .work: return "briefcase.fill"
        case .sleep: return "moon.stars.fill"
        case .morning: return "sunrise.fill"
        case .study: return "book.closed.fill"
        case .gym: return "figure.strengthtraining.traditional"
        }
    }

    var accentName: String {
        switch self {
        case .work: return "Deep work"
        case .sleep: return "Wind down"
        case .morning: return "Quiet start"
        case .study: return "Study sprint"
        case .gym: return "Move first"
        }
    }

    var blockingIntent: String {
        switch self {
        case .work: return "Blocks social + entertainment."
        case .sleep: return "Blocks everything except essentials."
        case .morning: return "Blocks social/news until 10 AM."
        case .study: return "Blocks social + YouTube."
        case .gym: return "Blocks social, keeps music apps."
        }
    }

    var defaultDurationMinutes: Int {
        switch self {
        case .work: return 60
        case .sleep: return 480
        case .morning: return 120
        case .study: return 90
        case .gym: return 75
        }
    }

    var scheduleHint: String? {
        switch self {
        case .morning: return "Until 10 AM"
        case .work: return "Weekdays 9–12"
        case .sleep: return "Nightly wind down"
        default: return nil
        }
    }
}

struct AccountabilityReceipt: Codable, Equatable {
    var protectedMinutes: Int
    var completedAt: Date
    var lines: [String]

    init(protectedMinutes: Int, completedAt: Date = Date(), lines: [String] = ["Apps stayed blocked.", "Commitment kept."]) {
        self.protectedMinutes = max(1, protectedMinutes)
        self.completedAt = completedAt
        self.lines = lines
    }

    var headline: String {
        if protectedMinutes % 60 == 0 {
            let hours = protectedMinutes / 60
            return "You protected \(hours == 1 ? "1 hour" : "\(hours) hours")."
        }
        return "You protected \(protectedMinutes) minutes."
    }
}

struct SmartSuggestion: Codable, Equatable, Identifiable {
    var id: String { title }
    var title: String
    var message: String
    var template: FocusTemplate?
}

enum SmartSuggestionEngine {
    static func suggestions(stats: FocusStats, frictionUnlocks: [FrictionUnlockReflection], calendar: Calendar = .current) -> [SmartSuggestion] {
        var result: [SmartSuggestion] = []

        if let last = stats.lastSessionStart,
           (calendar.component(.hour, from: last) >= 21 || calendar.component(.hour, from: last) <= 4) {
            result.append(SmartSuggestion(title: "Try a Sleep Block preset", message: "You often start quick blocks at night. Want a calmer wind-down preset?", template: .sleep))
        }

        if stats.totalSessions >= 3 {
            result.append(SmartSuggestion(title: "Schedule a Work Block", message: "You completed 3 work blocks this week. Want to schedule weekdays 9–12?", template: .work))
        }

        let lateEarlyStops = frictionUnlocks.filter { reflection in
            let hour = calendar.component(.hour, from: reflection.completedAt)
            return hour >= 22 || hour <= 4
        }
        if lateEarlyStops.count >= 2 {
            result.append(SmartSuggestion(title: "Try a shorter 30 min block", message: "You stopped early twice after 22:00. A shorter block may fit better tonight.", template: nil))
        }

        if result.isEmpty {
            result.append(SmartSuggestion(title: "Protect your next session", message: "Start with a small 30 minute block and keep it easy to complete.", template: nil))
        }

        return result
    }
}
