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


public struct FocusStats: Codable, Equatable, Sendable {
    public var totalSessions: Int
    public var totalPlannedMinutes: Int
    public var focusDayStamps: Set<String>
    public var lastSessionStart: Date?

    public init(totalSessions: Int = 0, totalPlannedMinutes: Int = 0, focusDayStamps: Set<String> = [], lastSessionStart: Date? = nil) {
        self.totalSessions = totalSessions
        self.totalPlannedMinutes = totalPlannedMinutes
        self.focusDayStamps = focusDayStamps
        self.lastSessionStart = lastSessionStart
    }

    public var focusDayCount: Int { focusDayStamps.count }

    public var totalHoursLabel: String {
        guard totalPlannedMinutes > 0 else { return "0h" }
        let hours = Double(totalPlannedMinutes) / 60.0
        if totalPlannedMinutes % 60 == 0 {
            return "\(Int(hours))h"
        }
        return "\(hours.formatted(.number.precision(.fractionLength(1))))h"
    }

    public mutating func record(session: ImmediateBlockSession, calendar: Calendar = .current) {
        totalSessions += 1
        totalPlannedMinutes += session.durationMinutes
        lastSessionStart = session.start
        focusDayStamps.insert(Self.dayStamp(for: session.start, calendar: calendar))
    }

    public func currentStreakDays(asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
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


public enum FrictionUnlockReason: String, CaseIterable, Codable, Equatable, Sendable {
    case bored
    case stressed
    case tired
    case habit
    case needSomethingImportant
    case other

    public static var allOptions: [FrictionUnlockReason] { allCases }

    public var title: String {
        switch self {
        case .bored: return "Bored"
        case .stressed: return "Stressed"
        case .tired: return "Tired"
        case .habit: return "Habit"
        case .needSomethingImportant: return "Need something important"
        case .other: return "Other"
        }
    }
}

public struct FrictionUnlockReflection: Codable, Equatable, Sendable {
    public var blockReason: String
    public var stopReason: FrictionUnlockReason?
    public var otherStopReason: String
    public var completedAt: Date

    public init(blockReason: String, stopReason: FrictionUnlockReason? = nil, otherStopReason: String = "", completedAt: Date = Date()) {
        self.blockReason = blockReason
        self.stopReason = stopReason
        self.otherStopReason = otherStopReason
        self.completedAt = completedAt
    }

    public var isComplete: Bool {
        let hasBlockReason = !blockReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasBlockReason, let stopReason else { return false }
        if stopReason == .other {
            return !otherStopReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
}


public struct DelayModeConfiguration: Codable, Equatable, Sendable {
    public var waitSeconds: Int
    public var title: String
    public var message: String

    public static let `default` = DelayModeConfiguration(
        waitSeconds: 15,
        title: "Wait 15 seconds",
        message: "If you still want it, continue."
    )
}


public struct DelayAppsConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var appCount: Int
    public var categoryCount: Int
    public var webDomainCount: Int
    public var waitSeconds: Int

    public init(isEnabled: Bool = false, appCount: Int = 0, categoryCount: Int = 0, webDomainCount: Int = 0, waitSeconds: Int = DelayModeConfiguration.default.waitSeconds) {
        self.isEnabled = isEnabled
        self.appCount = max(0, appCount)
        self.categoryCount = max(0, categoryCount)
        self.webDomainCount = max(0, webDomainCount)
        self.waitSeconds = max(1, waitSeconds)
    }

    public var totalSelectionCount: Int { appCount + categoryCount + webDomainCount }
    public var hasSelection: Bool { totalSelectionCount > 0 }

    public func clearedSelection() -> DelayAppsConfiguration {
        DelayAppsConfiguration(isEnabled: isEnabled, waitSeconds: waitSeconds)
    }
}

public enum FocusTemplate: String, CaseIterable, Codable, Equatable, Sendable {
    case work
    case sleep
    case morning
    case study
    case gym

    public static var allPresets: [FocusTemplate] { [.work, .sleep, .morning, .study, .gym] }

    public var name: String {
        switch self {
        case .work: return "Work Mode"
        case .sleep: return "Sleep Mode"
        case .morning: return "Morning Mode"
        case .study: return "Study Mode"
        case .gym: return "Gym Mode"
        }
    }

    public var blockingIntent: String {
        switch self {
        case .work: return "Blocks social + entertainment."
        case .sleep: return "Blocks everything except essentials."
        case .morning: return "Blocks social/news until 10 AM."
        case .study: return "Blocks social + YouTube."
        case .gym: return "Blocks social, keeps music apps."
        }
    }

    public var defaultDurationMinutes: Int {
        switch self {
        case .work: return 60
        case .sleep: return 480
        case .morning: return 120
        case .study: return 90
        case .gym: return 75
        }
    }

    public var scheduleHint: String? {
        switch self {
        case .morning: return "Until 10 AM"
        case .work: return "Weekdays 9–12"
        case .sleep: return "Nightly wind down"
        default: return nil
        }
    }
}

public struct AccountabilityReceipt: Codable, Equatable, Sendable {
    public var protectedMinutes: Int
    public var completedAt: Date
    public var lines: [String]

    public init(protectedMinutes: Int, completedAt: Date = Date(), lines: [String] = ["Apps stayed blocked.", "Commitment kept."]) {
        self.protectedMinutes = max(1, protectedMinutes)
        self.completedAt = completedAt
        self.lines = lines
    }

    public var headline: String {
        if protectedMinutes % 60 == 0 {
            let hours = protectedMinutes / 60
            return "You protected \(hours == 1 ? "1 hour" : "\(hours) hours")."
        }
        return "You protected \(protectedMinutes) minutes."
    }
}

public struct SmartSuggestion: Codable, Equatable, Identifiable, Sendable {
    public var id: String { title }
    public var title: String
    public var message: String
    public var template: FocusTemplate?

    public init(title: String, message: String, template: FocusTemplate? = nil) {
        self.title = title
        self.message = message
        self.template = template
    }
}

public enum SmartSuggestionEngine {
    public static func suggestions(stats: FocusStats, frictionUnlocks: [FrictionUnlockReflection], calendar: Calendar = .current) -> [SmartSuggestion] {
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

public struct DelayAppsPauseProgress: Equatable, Sendable {
    public var waitSeconds: Int
    public var remainingSeconds: Int
    public var segments: Int

    public init(waitSeconds: Int = DelayModeConfiguration.default.waitSeconds, remainingSeconds: Int, segments: Int = 10) {
        self.waitSeconds = max(1, waitSeconds)
        self.remainingSeconds = max(0, min(remainingSeconds, max(1, waitSeconds)))
        self.segments = max(1, segments)
    }

    public var progressFraction: Double {
        Double(remainingSeconds) / Double(waitSeconds)
    }

    public var filledSegments: Int {
        Int(ceil(progressFraction * Double(segments)))
    }

    public var barText: String {
        let filled = String(repeating: "█", count: filledSegments)
        let empty = String(repeating: "░", count: segments - filledSegments)
        return filled + empty
    }

    public var statusText: String {
        remainingSeconds == 0 ? "Ready" : "\(remainingSeconds)s left"
    }
}


public enum DelayAppsWaitDecision: Equatable {
    case startWaiting(unlockAt: Date)
    case keepWaiting(remainingSeconds: Int)
    case allowAccess
}

public struct DelayAppsWaitGate: Equatable {
    public var waitSeconds: Int

    public init(waitSeconds: Int = 15) {
        self.waitSeconds = max(1, waitSeconds)
    }

    public func decision(now: Date = Date(), waitStartedAt: Date?) -> DelayAppsWaitDecision {
        guard let waitStartedAt else {
            return .startWaiting(unlockAt: now.addingTimeInterval(TimeInterval(waitSeconds)))
        }

        let unlockAt = waitStartedAt.addingTimeInterval(TimeInterval(waitSeconds))
        let remaining = remainingSeconds(now: now, unlockAt: unlockAt)
        if remaining <= 0 {
            return .allowAccess
        }
        return .keepWaiting(remainingSeconds: remaining)
    }

    public func remainingSeconds(now: Date = Date(), unlockAt: Date) -> Int {
        max(0, Int(ceil(unlockAt.timeIntervalSince(now))))
    }
}
