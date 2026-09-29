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


public struct QuickBlockStartGuard: Equatable, Sendable {
    public static func canStartNewBlock(existing: ImmediateBlockSession?, now: Date = Date()) -> Bool {
        guard let existing else { return true }
        return !existing.isActive(at: now)
    }

    public static func activeBlockMessage(existing: ImmediateBlockSession, now: Date = Date()) -> String {
        "Focus already active — \(existing.remainingMinutes(at: now)) min left."
    }
}

public struct FocusCompletionPolicy: Equatable, Sendable {
    public static let availabilitySeconds: TimeInterval = 60 * 60
    public static let continuationMinutes = 15

    public static func isAvailable(completedAt: Date, now: Date = Date()) -> Bool {
        now >= completedAt && now < completedAt.addingTimeInterval(availabilitySeconds)
    }
}


public struct FocusStats: Codable, Equatable, Sendable {
    public var totalSessions: Int
    public var totalPlannedMinutes: Int
    public var focusDayStamps: Set<String>
    public var lastSessionStart: Date?
    private var recordedSessionStarts: Set<Date>?

    public init(totalSessions: Int = 0, totalPlannedMinutes: Int = 0, focusDayStamps: Set<String> = [], lastSessionStart: Date? = nil) {
        self.totalSessions = totalSessions
        self.totalPlannedMinutes = totalPlannedMinutes
        self.focusDayStamps = focusDayStamps
        self.lastSessionStart = lastSessionStart
        self.recordedSessionStarts = nil
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
        recordCompleted(session: session, completedAt: session.end, calendar: calendar)
    }

    public mutating func recordCompleted(session: ImmediateBlockSession, completedAt: Date = Date(), calendar: Calendar = .current) {
        let elapsedSeconds = completedAt.timeIntervalSince(session.start)
        let elapsedMinutes = max(0, min(session.durationMinutes, Int(floor(elapsedSeconds / 60))))
        guard elapsedMinutes > 0 else { return }

        var recordedStarts = recordedSessionStarts ?? []
        guard !recordedStarts.contains(session.start) else { return }
        recordedStarts.insert(session.start)
        if recordedStarts.count > 128 {
            recordedStarts = Set(recordedStarts.sorted(by: >).prefix(128))
        }
        recordedSessionStarts = recordedStarts

        totalSessions += 1
        totalPlannedMinutes += elapsedMinutes
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



public struct PremiumAccessPolicy: Codable, Equatable, Sendable {
    public static let premiumProductID = "com.benberther.BlockerApp.premium"
    public static let maxFreeQuickBlockMinutes = 120

    public init() {}

    public static func canStartQuickBlock(durationMinutes: Int, isPremium: Bool) -> Bool {
        isPremium || durationMinutes <= maxFreeQuickBlockMinutes
    }

    public static func requiresPremiumForQuickBlock(durationMinutes: Int) -> Bool {
        durationMinutes > maxFreeQuickBlockMinutes
    }
}

public enum QuickBlockPresetMotionCue: String, CaseIterable, Codable, Equatable, Sendable {
    case spark
    case focusPulse
    case pageFlip
    case moonDrift
}

public enum QuickBlockPreset: String, CaseIterable, Codable, Equatable, Sendable {
    case quickReset
    case deepWork
    case study
    case sleep

    public static var mainRow: [QuickBlockPreset] { [.quickReset, .deepWork, .study, .sleep] }

    public var title: String {
        switch self {
        case .quickReset: return "Quick Reset"
        case .deepWork: return "Deep Work"
        case .study: return "Study"
        case .sleep: return "Sleep"
        }
    }

    public var subtitle: String {
        switch self {
        case .quickReset: return "30m"
        case .deepWork: return "2h"
        case .study: return "90m"
        case .sleep: return "8h"
        }
    }

    public var systemImage: String {
        switch self {
        case .quickReset: return "arrow.clockwise"
        case .deepWork: return "shield.lefthalf.filled"
        case .study: return "book.closed.fill"
        case .sleep: return "moon.stars.fill"
        }
    }

    public var durationMinutes: Int {
        switch self {
        case .quickReset: return 30
        case .deepWork: return 120
        case .study: return 90
        case .sleep: return 480
        }
    }

    public var durationLabel: String {
        ImmediateBlockSession(durationMinutes: durationMinutes).durationLabel
    }

    public var onePhraseExplanation: String {
        switch self {
        case .quickReset: return "Short reset"
        case .deepWork: return "Serious focus"
        case .study: return "Study session"
        case .sleep: return "Sleep shield"
        }
    }

    public var motionCue: QuickBlockPresetMotionCue {
        switch self {
        case .quickReset: return .spark
        case .deepWork: return .focusPulse
        case .study: return .pageFlip
        case .sleep: return .moonDrift
        }
    }

    public var accentName: String {
        switch self {
        case .quickReset: return "teal"
        case .deepWork: return "indigo"
        case .study: return "blue"
        case .sleep: return "violet"
        }
    }

    public var confirmationTitle: String {
        switch self {
        case .quickReset: return "Quick Reset started"
        case .deepWork: return "Deep Work started"
        case .study: return "Study block started"
        case .sleep: return "Sleep shield started"
        }
    }

    public var confirmationSubtitle: String {
        switch self {
        case .quickReset: return "A clean 30-minute reset is active."
        case .deepWork: return "Two hours protected for focused work."
        case .study: return "Ninety minutes set aside for learning."
        case .sleep: return "Eight hours protected for a calmer night."
        }
    }
}

public struct AppLaunchSlogan: Codable, Equatable, Sendable {
    public var title: String
    public var subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public static let primary = AppLaunchSlogan(title: "You vs. you", subtitle: "Protect your attention before the scroll wins.")
    public static let intention = AppLaunchSlogan(title: "Less impulse. More intention.", subtitle: "A calmer way back to focus.")
    public static let attention = AppLaunchSlogan(title: "Choose your attention", subtitle: "Start small. Stay with it.")
    public static var all: [AppLaunchSlogan] { [.primary, .intention, .attention] }
}

public struct QuickBlockPresetSelection: Codable, Equatable, Sendable {
    public var selectedMinutes: Int

    public init(selectedMinutes: Int = 60) {
        self.selectedMinutes = max(1, selectedMinutes)
    }

    public func selecting(_ preset: QuickBlockPreset) -> QuickBlockPresetSelection {
        QuickBlockPresetSelection(selectedMinutes: preset.durationMinutes)
    }

    public var durationLabel: String {
        ImmediateBlockSession(durationMinutes: selectedMinutes).durationLabel
    }

    public var startButtonTitle: String {
        "Start \(durationLabel) focus"
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


public struct CoreFlowStep: Codable, Equatable, Identifiable, Sendable {
    public var id: String { tabName }
    public var tabName: String
    public var title: String
    public var message: String
    public var systemImage: String
    public var accentName: String

    public init(tabName: String, title: String, message: String, systemImage: String, accentName: String) {
        self.tabName = tabName
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accentName = accentName
    }

    public static let status = CoreFlowStep(
        tabName: "Status",
        title: "Start a Quick Block",
        message: "Choose apps and websites here, then start protection immediately.",
        systemImage: "bolt.fill",
        accentName: "gold"
    )

    public static let schedule = CoreFlowStep(
        tabName: "Schedule",
        title: "Automate your routine",
        message: "Create recurring blocks for work, study, sleep, or mornings.",
        systemImage: "calendar",
        accentName: "orange"
    )

    public static let modes = CoreFlowStep(
        tabName: "Modes",
        title: "Add friction",
        message: "Use templates and delay apps when you need a softer nudge.",
        systemImage: "sparkles",
        accentName: "purple"
    )

    public static let progress = CoreFlowStep(
        tabName: "Progress",
        title: "See proof",
        message: "Check protected minutes, completed blocks, and streaks.",
        systemImage: "chart.line.uptrend.xyaxis",
        accentName: "green"
    )

    public static let all: [CoreFlowStep] = [.status, .schedule, .modes, .progress]
}

public struct ScreenTimePermissionExplainer: Codable, Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var bullets: [String]
    public var privacyLine: String
    public var ctaTitle: String

    public init(title: String, subtitle: String, bullets: [String], privacyLine: String, ctaTitle: String) {
        self.title = title
        self.subtitle = subtitle
        self.bullets = bullets
        self.privacyLine = privacyLine
        self.ctaTitle = ctaTitle
    }

    public static let standard = ScreenTimePermissionExplainer(
        title: "Why Screen Time access?",
        subtitle: "Blocker uses Apple's Screen Time tools to shield the apps and websites you choose.",
        bullets: [
            "Needed to start quick blocks and scheduled focus windows.",
            "Lets you pick apps, categories, and websites from Apple's picker.",
            "Blocker cannot read your messages, browsing history, or app content."
        ],
        privacyLine: "Your choices stay on-device and are only used to apply your blocks.",
        ctaTitle: "Allow Screen Time Access"
    )
}


public struct BlockCoverageExplainer: Codable, Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var bullets: [String]
    public var deviceRows: [String]
    public var websiteReminder: String

    public init(title: String, subtitle: String, bullets: [String], deviceRows: [String], websiteReminder: String) {
        self.title = title
        self.subtitle = subtitle
        self.bullets = bullets
        self.deviceRows = deviceRows
        self.websiteReminder = websiteReminder
    }

    public static let standard = BlockCoverageExplainer(
        title: "Coverage",
        subtitle: "Blocker protects apps, categories, and websites selected in Apple’s Screen Time picker on this device.",
        bullets: [
            "To block YouTube in Safari too, add youtube.com in Websites when choosing apps.",
            "Apple does not let an iPhone app silently choose the matching website for an app token.",
            "Mac blocking uses the Mac companion: the iPhone sends selected website domains automatically when Quick Block starts."
        ],
        deviceRows: ["This iPhone: Screen Time", "MacBook: auto-sync companion"],
        websiteReminder: "Add websites in the same picker so app + web stay covered together."
    )
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
