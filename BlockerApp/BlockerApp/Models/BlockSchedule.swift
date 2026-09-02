import Foundation

struct ScheduleTimePeriod: Identifiable, Codable, Hashable {
    var id: UUID
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    init(id: UUID = UUID(), startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.id = id
        self.startHour = min(23, max(0, startHour))
        self.startMinute = min(59, max(0, startMinute))
        self.endHour = min(23, max(0, endHour))
        self.endMinute = min(59, max(0, endMinute))
    }

    var startTotalMinutes: Int { startHour * 60 + startMinute }
    var endTotalMinutes: Int { endHour * 60 + endMinute }
    var isZeroLength: Bool { startTotalMinutes == endTotalMinutes }
    var crossesMidnight: Bool { endTotalMinutes < startTotalMinutes }
    var durationMinutes: Int {
        guard !isZeroLength else { return 0 }
        return crossesMidnight ? (24 * 60 - startTotalMinutes + endTotalMinutes) : (endTotalMinutes - startTotalMinutes)
    }

    fileprivate var semanticKey: String {
        "\(startHour):\(startMinute)-\(endHour):\(endMinute)"
    }
}

nonisolated enum ScheduleValidationIssue: Equatable {
    case emptySchedule
    case zeroLengthPeriod
    case overlappingPeriods
    case monitorLimitExceeded(limit: Int)
}

struct ScheduleMonitoringDescriptor: Equatable, Identifiable {
    let id: String
    let periodID: UUID
    let startWeekday: Int
    let endWeekday: Int
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let durationMinutes: Int
}

struct ScheduleSummaryGroup: Equatable, Identifiable {
    let weekdays: [Int]
    let period: ScheduleTimePeriod

    var id: String { period.semanticKey }
}

struct BlockSchedule: Codable, Equatable {
    static let allWeekdays = Set(1...7)
    static let maximumRecurringMonitorCount = 19 // DeviceActivity allows 20; reserve one for Quick Block.
    static let orderedWeekdays: [(weekday: Int, shortName: String, fullName: String)] = [
        (2, "Mon", "Monday"),
        (3, "Tue", "Tuesday"),
        (4, "Wed", "Wednesday"),
        (5, "Thu", "Thursday"),
        (6, "Fri", "Friday"),
        (7, "Sat", "Saturday"),
        (1, "Sun", "Sunday")
    ]

    var periodsByWeekday: [Int: [ScheduleTimePeriod]]
    var selectedBlocklistID: UUID?
    /// `nil` marks schedules saved before per-schedule device selection existed.
    /// Those schedules inherit This iPhone plus the Device Sync Mac selection.
    var protectedDeviceIDs: Set<String>?

    init(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        selectedWeekdays: Set<Int> = BlockSchedule.allWeekdays,
        selectedBlocklistID: UUID? = nil,
        protectedDeviceIDs: Set<String>? = nil
    ) {
        let period = ScheduleTimePeriod(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute)
        self.periodsByWeekday = Dictionary(uniqueKeysWithValues: selectedWeekdays.filter { (1...7).contains($0) }.map { ($0, [period]) })
        self.selectedBlocklistID = selectedBlocklistID
        self.protectedDeviceIDs = protectedDeviceIDs.map { Set(MacBlockDevicePreset.sanitizedDeviceIDs(Array($0))) }
        normalizePeriods()
    }

    init(
        periodsByWeekday: [Int: [ScheduleTimePeriod]],
        selectedBlocklistID: UUID? = nil,
        protectedDeviceIDs: Set<String>? = nil
    ) {
        self.periodsByWeekday = periodsByWeekday
        self.selectedBlocklistID = selectedBlocklistID
        self.protectedDeviceIDs = protectedDeviceIDs.map { Set(MacBlockDevicePreset.sanitizedDeviceIDs(Array($0))) }
        normalizePeriods()
    }

    private enum CodingKeys: String, CodingKey {
        case periodsByWeekday
        case startHour
        case startMinute
        case endHour
        case endMinute
        case selectedWeekdays
        case selectedBlocklistID
        case protectedDeviceIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedBlocklistID = try container.decodeIfPresent(UUID.self, forKey: .selectedBlocklistID)
        protectedDeviceIDs = try container.decodeIfPresent(Set<String>.self, forKey: .protectedDeviceIDs)
            .map { Set(MacBlockDevicePreset.sanitizedDeviceIDs(Array($0))) }

        if let decodedPeriods = try container.decodeIfPresent([Int: [ScheduleTimePeriod]].self, forKey: .periodsByWeekday) {
            periodsByWeekday = decodedPeriods
        } else {
            let startHour = try container.decode(Int.self, forKey: .startHour)
            let startMinute = try container.decode(Int.self, forKey: .startMinute)
            let endHour = try container.decode(Int.self, forKey: .endHour)
            let endMinute = try container.decode(Int.self, forKey: .endMinute)
            let selectedWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .selectedWeekdays) ?? BlockSchedule.allWeekdays
            let period = ScheduleTimePeriod(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute)
            periodsByWeekday = Dictionary(uniqueKeysWithValues: selectedWeekdays.filter { (1...7).contains($0) }.map { ($0, [period]) })
        }
        normalizePeriods()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(periodsByWeekday, forKey: .periodsByWeekday)
        try container.encode(startHour, forKey: .startHour)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endHour, forKey: .endHour)
        try container.encode(endMinute, forKey: .endMinute)
        try container.encode(selectedWeekdays, forKey: .selectedWeekdays)
        try container.encodeIfPresent(selectedBlocklistID, forKey: .selectedBlocklistID)
        try container.encodeIfPresent(protectedDeviceIDs, forKey: .protectedDeviceIDs)
    }

    private mutating func normalizePeriods() {
        periodsByWeekday = periodsByWeekday.reduce(into: [:]) { result, pair in
            guard (1...7).contains(pair.key), !pair.value.isEmpty else { return }
            result[pair.key] = pair.value.sorted {
                if $0.startTotalMinutes == $1.startTotalMinutes { return $0.endTotalMinutes < $1.endTotalMinutes }
                return $0.startTotalMinutes < $1.startTotalMinutes
            }
        }
    }

    static func == (lhs: BlockSchedule, rhs: BlockSchedule) -> Bool {
        lhs.semanticPeriods == rhs.semanticPeriods
            && lhs.selectedBlocklistID == rhs.selectedBlocklistID
            && lhs.protectedDeviceIDs == rhs.protectedDeviceIDs
    }

    private var semanticPeriods: [Int: [String]] {
        periodsByWeekday.mapValues { $0.map(\.semanticKey) }
    }

    func effectiveProtectedDeviceIDs(defaultRemoteDeviceIDs: [String]) -> Set<String> {
        if let protectedDeviceIDs { return protectedDeviceIDs }
        return Set(MacBlockDevicePreset.sanitizedDeviceIDs(defaultRemoteDeviceIDs + [MacBlockDevicePreset.currentDeviceID]))
    }

    func protectsCurrentDevice(defaultRemoteDeviceIDs: [String]) -> Bool {
        effectiveProtectedDeviceIDs(defaultRemoteDeviceIDs: defaultRemoteDeviceIDs)
            .contains(MacBlockDevicePreset.currentDeviceID.lowercased())
    }

    var selectedWeekdays: Set<Int> { Set(periodsByWeekday.keys) }
    var selectedWeekdaySymbols: [String] {
        BlockSchedule.orderedWeekdays
            .filter { selectedWeekdays.contains($0.weekday) }
            .map(\.shortName)
    }

    var selectedWeekdaySummary: String {
        if selectedWeekdays == BlockSchedule.allWeekdays { return "Every day" }
        if selectedWeekdays == Set(2...6) { return "Weekdays" }
        if selectedWeekdays == Set([1, 7]) { return "Weekends" }
        return selectedWeekdaySymbols.joined(separator: ", ")
    }

    /// Legacy convenience properties retained for existing call sites and old sync payloads.
    private var firstPeriod: ScheduleTimePeriod? {
        BlockSchedule.orderedWeekdays.lazy.compactMap { periodsByWeekday[$0.weekday]?.first }.first
    }
    var startHour: Int { firstPeriod?.startHour ?? 9 }
    var startMinute: Int { firstPeriod?.startMinute ?? 0 }
    var endHour: Int { firstPeriod?.endHour ?? 17 }
    var endMinute: Int { firstPeriod?.endMinute ?? 0 }
    var startTotalMinutes: Int { firstPeriod?.startTotalMinutes ?? 9 * 60 }
    var endTotalMinutes: Int { firstPeriod?.endTotalMinutes ?? 17 * 60 }
    var crossesMidnight: Bool { firstPeriod?.crossesMidnight ?? false }

    func periods(for weekday: Int) -> [ScheduleTimePeriod] {
        periodsByWeekday[weekday] ?? []
    }

    var summaryGroups: [ScheduleSummaryGroup] {
        var groups: [ScheduleSummaryGroup] = []
        var groupIndexByPeriod: [String: Int] = [:]

        for day in Self.orderedWeekdays {
            for period in periods(for: day.weekday) {
                if let index = groupIndexByPeriod[period.semanticKey] {
                    if !groups[index].weekdays.contains(day.weekday) {
                        groups[index] = ScheduleSummaryGroup(
                            weekdays: groups[index].weekdays + [day.weekday],
                            period: groups[index].period
                        )
                    }
                } else {
                    groupIndexByPeriod[period.semanticKey] = groups.count
                    groups.append(ScheduleSummaryGroup(weekdays: [day.weekday], period: period))
                }
            }
        }
        return groups
    }

    func contains(hour: Int, minute: Int) -> Bool {
        selectedWeekdays.contains { contains(weekday: $0, hour: hour, minute: minute) }
    }

    func contains(weekday: Int, hour: Int, minute: Int) -> Bool {
        let currentMinutes = hour * 60 + minute
        if periods(for: weekday).contains(where: { period in
            guard !period.isZeroLength else { return false }
            return currentMinutes >= period.startTotalMinutes && (!period.crossesMidnight ? currentMinutes < period.endTotalMinutes : true)
        }) {
            return true
        }

        let previousWeekday = Self.previousWeekday(weekday)
        return periods(for: previousWeekday).contains { period in
            period.crossesMidnight && currentMinutes < period.endTotalMinutes
        }
    }

    func validationIssue(maximumMonitorCount: Int = BlockSchedule.maximumRecurringMonitorCount) -> ScheduleValidationIssue? {
        let occurrences = periodsByWeekday.flatMap { weekday, periods in periods.map { (weekday, $0) } }
        guard !occurrences.isEmpty else { return .emptySchedule }
        guard !occurrences.contains(where: { $0.1.isZeroLength }) else { return .zeroLengthPeriod }

        let weekMinutes = 7 * 24 * 60
        var segments: [(start: Int, end: Int)] = []
        for (weekday, period) in occurrences {
            let start = (weekday - 1) * 24 * 60 + period.startTotalMinutes
            let end = start + period.durationMinutes
            if end <= weekMinutes {
                segments.append((start, end))
            } else {
                segments.append((start, weekMinutes))
                segments.append((0, end - weekMinutes))
            }
        }
        segments.sort { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        for pair in zip(segments, segments.dropFirst()) where pair.1.start < pair.0.end {
            return .overlappingPeriods
        }
        guard occurrences.count <= maximumMonitorCount else { return .monitorLimitExceeded(limit: maximumMonitorCount) }
        return nil
    }

    var monitoringDescriptors: [ScheduleMonitoringDescriptor] {
        periodsByWeekday.flatMap { weekday, periods in
            periods.map { period in
                ScheduleMonitoringDescriptor(
                    id: SharedConfig.dailyActivityName(for: weekday, periodID: period.id),
                    periodID: period.id,
                    startWeekday: weekday,
                    endWeekday: period.crossesMidnight ? Self.nextWeekday(weekday) : weekday,
                    startHour: period.startHour,
                    startMinute: period.startMinute,
                    endHour: period.endHour,
                    endMinute: period.endMinute,
                    durationMinutes: period.durationMinutes
                )
            }
        }.sorted { $0.id < $1.id }
    }

    static func nextWeekday(_ weekday: Int) -> Int { weekday == 7 ? 1 : weekday + 1 }
    static func previousWeekday(_ weekday: Int) -> Int { weekday == 1 ? 7 : weekday - 1 }

    static let defaultFocus = BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
}



enum QuickBlockCommitmentMode: String, Codable, Equatable, CaseIterable {
    case normal
    case strong

    var title: String { self == .strong ? "Strong" : "Normal" }
    var requiresPremium: Bool { self == .strong }
    var systemImage: String { self == .strong ? "lock.shield.fill" : "timer" }
    var subtitle: String {
        self == .strong ? "Premium commitment with one emergency exit per day" : "30 sec pause + reflection"
    }
}

struct FrictionUnlockTiming: Codable, Equatable {
    var breathingSeconds: Int
    var finalWaitSeconds: Int
    var initialDelaySeconds: Int { breathingSeconds }
    var finalDelaySeconds: Int { finalWaitSeconds }

    static func forMode(_ mode: QuickBlockCommitmentMode) -> FrictionUnlockTiming {
        switch mode {
        case .normal:
            return FrictionUnlockTiming(breathingSeconds: 30, finalWaitSeconds: 10)
        case .strong:
            return FrictionUnlockTiming(breathingSeconds: 30, finalWaitSeconds: 20)
        }
    }
}

struct EscapeTokenLedger: Codable, Equatable {
    var spentDayStamps: [String]

    init(spentDayStamps: [String] = []) {
        self.spentDayStamps = spentDayStamps
    }
}

enum EscapeTokenPolicy {
    static let dailyLimit = 1

    static func remainingTokens(in ledger: EscapeTokenLedger, on date: Date = Date(), calendar: Calendar = .current) -> Int {
        canSpendToken(in: ledger, on: date, calendar: calendar) ? dailyLimit : 0
    }

    static func canSpendToken(in ledger: EscapeTokenLedger, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        !ledger.spentDayStamps.contains(dayStamp(for: date, calendar: calendar))
    }

    static func spendingToken(in ledger: EscapeTokenLedger, on date: Date = Date(), calendar: Calendar = .current) -> EscapeTokenLedger {
        let stamp = dayStamp(for: date, calendar: calendar)
        guard !ledger.spentDayStamps.contains(stamp) else { return ledger }
        return EscapeTokenLedger(spentDayStamps: ledger.spentDayStamps + [stamp])
    }

    private static func dayStamp(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

#if canImport(FamilyControls)
import FamilyControls
struct NamedBlocklist: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var createdAt: Date

    init(id: UUID = UUID(), name: String, selection: FamilyActivitySelection = FamilyActivitySelection(), createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.selection = selection
        self.createdAt = createdAt
    }
}
#endif

struct ActiveScheduledBlockWindow: Equatable {
    let start: Date
    let end: Date
    let activityName: String

    static func activeWindow(for schedule: BlockSchedule, now: Date = Date(), calendar: Calendar = .current) -> ActiveScheduledBlockWindow? {
        let today = calendar.startOfDay(for: now)
        let candidateStartDays = [today, calendar.date(byAdding: .day, value: -1, to: today)].compactMap { $0 }

        for startDay in candidateStartDays {
            let weekday = calendar.component(.weekday, from: startDay)
            for period in schedule.periods(for: weekday) {
                guard period.durationMinutes > 0 else { continue }
                let endDay = period.crossesMidnight
                    ? calendar.date(byAdding: .day, value: 1, to: startDay)
                    : startDay
                guard let endDay,
                      let start = calendar.date(bySettingHour: period.startHour, minute: period.startMinute, second: 0, of: startDay),
                      let end = calendar.date(bySettingHour: period.endHour, minute: period.endMinute, second: 0, of: endDay) else {
                    continue
                }
                if now >= start && now < end {
                    return ActiveScheduledBlockWindow(
                        start: start,
                        end: end,
                        activityName: SharedConfig.dailyActivityName(for: weekday, periodID: period.id)
                    )
                }
            }
        }
        return nil
    }

    func progress(at date: Date = Date()) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(start) / total))
    }

    func largeRemainingLabel(at date: Date = Date()) -> String {
        let seconds = max(0, Int(ceil(end.timeIntervalSince(date))))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        return String(format: "%dm", max(1, minutes))
    }
}


struct ImmediateBlockSession: Codable, Equatable {
    let start: Date
    let durationMinutes: Int
    let calendar: Calendar
    let commitmentMode: QuickBlockCommitmentMode

    init(start: Date = Date(), durationMinutes: Int, calendar: Calendar = .current, commitmentMode: QuickBlockCommitmentMode = .normal) {
        self.start = start
        self.durationMinutes = max(1, durationMinutes)
        self.calendar = calendar
        self.commitmentMode = commitmentMode
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


struct QuickBlockLaunchPolicy {
    static let countdownSeconds = 3
    static let cancellationGraceSeconds = 10

    static func countdownRemaining(startedAt: Date, now: Date = Date()) -> Int {
        remainingSeconds(
            until: startedAt.addingTimeInterval(TimeInterval(countdownSeconds)),
            now: now
        )
    }

    static func shouldActivate(startedAt: Date, now: Date = Date()) -> Bool {
        now >= startedAt.addingTimeInterval(TimeInterval(countdownSeconds))
    }

    static func graceRemaining(sessionStart: Date, now: Date = Date()) -> Int {
        guard now >= sessionStart else { return 0 }
        return remainingSeconds(
            until: sessionStart.addingTimeInterval(TimeInterval(cancellationGraceSeconds)),
            now: now
        )
    }

    static func canCancelWithoutFriction(sessionStart: Date, now: Date = Date()) -> Bool {
        graceRemaining(sessionStart: sessionStart, now: now) > 0
    }

    private static func remainingSeconds(until end: Date, now: Date) -> Int {
        max(0, Int(ceil(end.timeIntervalSince(now))))
    }
}


struct QuickBlockStartGuard: Equatable {
    static func canStartNewBlock(existing: ImmediateBlockSession?, now: Date = Date()) -> Bool {
        guard let existing else { return true }
        return !existing.isActive(at: now)
    }

    static func activeBlockMessage(existing: ImmediateBlockSession, now: Date = Date()) -> String {
        "Focus already active — \(existing.remainingMinutes(at: now)) min left."
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
        recordCompleted(session: session, completedAt: session.end, calendar: calendar)
    }

    mutating func recordCompleted(session: ImmediateBlockSession, completedAt: Date = Date(), calendar: Calendar = .current) {
        let elapsedSeconds = completedAt.timeIntervalSince(session.start)
        let elapsedMinutes = max(0, min(session.durationMinutes, Int(floor(elapsedSeconds / 60))))
        guard elapsedMinutes > 0 else { return }

        totalSessions += 1
        totalPlannedMinutes += elapsedMinutes
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

struct ScheduledFocusStats: Codable, Equatable {
    var totalProtectedMinutes: Int
    var focusDayStamps: Set<String>

    init(totalProtectedMinutes: Int = 0, focusDayStamps: Set<String> = []) {
        self.totalProtectedMinutes = totalProtectedMinutes
        self.focusDayStamps = focusDayStamps
    }

    mutating func recordProtection(
        start: Date,
        end: Date,
        maximumMinutes: Int? = nil,
        calendar: Calendar = .current
    ) {
        let cappedEnd: Date
        if let maximumMinutes {
            cappedEnd = min(end, start.addingTimeInterval(TimeInterval(max(0, maximumMinutes) * 60)))
        } else {
            cappedEnd = end
        }
        let elapsedMinutes = Int(floor(cappedEnd.timeIntervalSince(start) / 60))
        guard elapsedMinutes > 0 else { return }

        totalProtectedMinutes += elapsedMinutes
        var cursor = start
        while cursor < cappedEnd {
            focusDayStamps.insert(Self.dayStamp(for: cursor, calendar: calendar))
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart), nextDay > cursor else { break }
            cursor = nextDay
        }
    }

    private static func dayStamp(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

struct FocusProgressSummary: Equatable {
    let quickStats: FocusStats
    let scheduledStats: ScheduledFocusStats

    var totalMinutes: Int { quickStats.totalPlannedMinutes + scheduledStats.totalProtectedMinutes }
    var scheduledMinutes: Int { scheduledStats.totalProtectedMinutes }
    var completedSessions: Int { quickStats.totalSessions }
    var hasData: Bool { completedSessions > 0 || totalMinutes > 0 || !focusDayStamps.isEmpty }
    var totalHoursLabel: String { Self.hoursLabel(for: totalMinutes) }
    var scheduledHoursLabel: String { Self.hoursLabel(for: scheduledMinutes) }

    func currentStreakDays(asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        var combined = quickStats
        combined.focusDayStamps = focusDayStamps
        return combined.currentStreakDays(asOf: date, calendar: calendar)
    }

    private var focusDayStamps: Set<String> {
        quickStats.focusDayStamps.union(scheduledStats.focusDayStamps)
    }

    private static func hoursLabel(for minutes: Int) -> String {
        guard minutes > 0 else { return "0h" }
        let hours = Double(minutes) / 60.0
        if minutes % 60 == 0 { return "\(Int(hours))h" }
        return "\(hours.formatted(.number.precision(.fractionLength(1))))h"
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
        waitSeconds: 15,
        title: "Wait 15 seconds",
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



struct PremiumAccessPolicy: Codable, Equatable {
    static let premiumProductID = "com.benberther.BlockerApp.premium"
    static let maxFreeQuickBlockMinutes = 120

    static func canStartQuickBlock(durationMinutes: Int, isPremium: Bool, commitmentMode: QuickBlockCommitmentMode = .normal) -> Bool {
        guard commitmentMode == .normal || isPremium else { return false }
        return isPremium || durationMinutes <= maxFreeQuickBlockMinutes
    }

    static func requiresPremiumForQuickBlock(durationMinutes: Int) -> Bool {
        durationMinutes > maxFreeQuickBlockMinutes
    }
}

enum QuickBlockPresetMotionCue: String, CaseIterable, Codable, Equatable {
    case spark
    case focusPulse
    case pageFlip
    case moonDrift
}

enum QuickBlockPreset: String, CaseIterable, Codable, Equatable {
    case quickReset
    case deepWork
    case study
    case sleep

    static var mainRow: [QuickBlockPreset] { [.quickReset, .deepWork, .study, .sleep] }

    var title: String {
        switch self {
        case .quickReset: return "Quick Reset"
        case .deepWork: return "Deep Work"
        case .study: return "Study"
        case .sleep: return "Sleep"
        }
    }

    var subtitle: String {
        switch self {
        case .quickReset: return "30m"
        case .deepWork: return "2h"
        case .study: return "90m"
        case .sleep: return "8h"
        }
    }

    var systemImage: String {
        switch self {
        case .quickReset: return "arrow.clockwise"
        case .deepWork: return "shield.lefthalf.filled"
        case .study: return "book.closed.fill"
        case .sleep: return "moon.stars.fill"
        }
    }

    var durationMinutes: Int {
        switch self {
        case .quickReset: return 30
        case .deepWork: return 120
        case .study: return 90
        case .sleep: return 480
        }
    }

    var durationLabel: String {
        ImmediateBlockSession(durationMinutes: durationMinutes).durationLabel
    }

    var onePhraseExplanation: String {
        switch self {
        case .quickReset: return "Short reset"
        case .deepWork: return "Serious focus"
        case .study: return "Study session"
        case .sleep: return "Sleep shield"
        }
    }

    var motionCue: QuickBlockPresetMotionCue {
        switch self {
        case .quickReset: return .spark
        case .deepWork: return .focusPulse
        case .study: return .pageFlip
        case .sleep: return .moonDrift
        }
    }

    var accentName: String {
        switch self {
        case .quickReset: return "teal"
        case .deepWork: return "indigo"
        case .study: return "blue"
        case .sleep: return "violet"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .quickReset: return "Quick Reset started"
        case .deepWork: return "Deep Work started"
        case .study: return "Study block started"
        case .sleep: return "Sleep shield started"
        }
    }

    var confirmationSubtitle: String {
        switch self {
        case .quickReset: return "A clean 30-minute reset is active."
        case .deepWork: return "Two hours protected for focused work."
        case .study: return "Ninety minutes set aside for learning."
        case .sleep: return "Eight hours protected for a calmer night."
        }
    }
}

struct AppLaunchSlogan: Codable, Equatable {
    var title: String
    var subtitle: String

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    static let primary = AppLaunchSlogan(title: "You vs. you", subtitle: "Protect your attention before the scroll wins.")
    static let intention = AppLaunchSlogan(title: "Less impulse. More intention.", subtitle: "A calmer way back to focus.")
    static let attention = AppLaunchSlogan(title: "Choose your attention", subtitle: "Start small. Stay with it.")
    static var all: [AppLaunchSlogan] { [.primary, .intention, .attention] }
}


struct CoreFlowStep: Codable, Equatable, Identifiable {
    var id: String { tabName }
    var tabName: String
    var title: String
    var message: String
    var systemImage: String
    var accentName: String

    static let status = CoreFlowStep(
        tabName: "Status",
        title: "Start a Quick Block",
        message: "Choose apps and websites here, then start protection immediately.",
        systemImage: "bolt.shield.fill",
        accentName: "yellow"
    )

    static let schedule = CoreFlowStep(
        tabName: "Schedule",
        title: "Set a routine",
        message: "Choose days and times for automatic focus windows.",
        systemImage: "calendar.badge.shield",
        accentName: "orange"
    )

    static let modes = CoreFlowStep(
        tabName: "Modes",
        title: "Add friction",
        message: "Use Delay Apps and templates for softer, intentional blocking.",
        systemImage: "sparkles",
        accentName: "purple"
    )

    static let progress = CoreFlowStep(
        tabName: "Progress",
        title: "See proof",
        message: "Review sessions, streaks, and receipts that show momentum.",
        systemImage: "chart.line.uptrend.xyaxis",
        accentName: "green"
    )

    static let all: [CoreFlowStep] = [.status, .schedule, .modes, .progress]
}

struct ScreenTimePermissionExplainer: Codable, Equatable {
    var title: String
    var subtitle: String
    var bullets: [String]
    var privacyLine: String
    var ctaTitle: String

    static let standard = ScreenTimePermissionExplainer(
        title: "Why Screen Time access?",
        subtitle: "Apple requires this permission before Blocker can shield selected apps and websites.",
        bullets: [
            "Needed to show Apple’s app and website picker.",
            "Needed to apply shields during quick blocks and schedules.",
            "Blocker cannot read your messages, browsing history, or private app content."
        ],
        privacyLine: "Your choices stay on-device and are saved privately in the app group.",
        ctaTitle: "Allow Screen Time Access"
    )
}

struct BlockCoverageExplainer: Codable, Equatable {
    var title: String
    var subtitle: String
    var bullets: [String]
    var deviceRows: [String]
    var websiteReminder: String

    static let standard = BlockCoverageExplainer(
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

struct QuickBlockPresetSelection: Codable, Equatable {
    var selectedMinutes: Int

    init(selectedMinutes: Int = 60) {
        self.selectedMinutes = max(1, selectedMinutes)
    }

    func selecting(_ preset: QuickBlockPreset) -> QuickBlockPresetSelection {
        QuickBlockPresetSelection(selectedMinutes: preset.durationMinutes)
    }

    var durationLabel: String {
        ImmediateBlockSession(durationMinutes: selectedMinutes).durationLabel
    }

    var startButtonTitle: String {
        "Start \(durationLabel) focus"
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
    /// True when the user has enough history for suggestions to feel personal
    /// instead of generic. Used to hide the Smart Suggestions section entirely
    /// for brand-new users.
    static func hasPersonalizedSignals(stats: FocusStats, frictionUnlocks: [FrictionUnlockReflection], calendar: Calendar = .current) -> Bool {
        if stats.totalSessions >= 3 { return true }
        if let last = stats.lastSessionStart,
           (calendar.component(.hour, from: last) >= 21 || calendar.component(.hour, from: last) <= 4) {
            return true
        }
        let lateEarlyStops = frictionUnlocks.filter { reflection in
            let hour = calendar.component(.hour, from: reflection.completedAt)
            return hour >= 22 || hour <= 4
        }
        return lateEarlyStops.count >= 2
    }

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

struct DelayAppsPauseProgress: Equatable {
    var waitSeconds: Int
    var remainingSeconds: Int
    var segments: Int

    init(waitSeconds: Int = DelayModeConfiguration.default.waitSeconds, remainingSeconds: Int, segments: Int = 10) {
        self.waitSeconds = max(1, waitSeconds)
        self.remainingSeconds = max(0, min(remainingSeconds, max(1, waitSeconds)))
        self.segments = max(1, segments)
    }

    var progressFraction: Double {
        Double(remainingSeconds) / Double(waitSeconds)
    }

    var filledSegments: Int {
        Int(ceil(progressFraction * Double(segments)))
    }

    var barText: String {
        let filled = String(repeating: "█", count: filledSegments)
        let empty = String(repeating: "░", count: segments - filledSegments)
        return filled + empty
    }

    var statusText: String {
        remainingSeconds == 0 ? "Ready" : "\(remainingSeconds)s left"
    }
}


enum DelayAppsWaitDecision: Equatable {
    case startWaiting(unlockAt: Date)
    case keepWaiting(remainingSeconds: Int)
    case allowAccess
}

struct DelayAppsWaitGate: Equatable {
    var waitSeconds: Int

    init(waitSeconds: Int = 15) {
        self.waitSeconds = max(1, waitSeconds)
    }

    func decision(now: Date = Date(), waitStartedAt: Date?) -> DelayAppsWaitDecision {
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

    func remainingSeconds(now: Date = Date(), unlockAt: Date) -> Int {
        max(0, Int(ceil(unlockAt.timeIntervalSince(now))))
    }
}


struct FirstLaunchOnboardingStep: Codable, Equatable, Identifiable {
    var id: String { "\(tabName)-\(cardTitle)" }
    let tabName: String
    let cardTitle: String
    let targetID: String
    let body: String
    let systemImage: String
    let requestsScreenTimePermission: Bool

    init(tabName: String, cardTitle: String, targetID: String? = nil, body: String, systemImage: String, requestsScreenTimePermission: Bool = false) {
        self.tabName = tabName
        self.cardTitle = cardTitle
        self.targetID = targetID ?? cardTitle
        self.body = body
        self.systemImage = systemImage
        self.requestsScreenTimePermission = requestsScreenTimePermission
    }

    var buttonTitle: String {
        self == Self.all.last ? "Start Focusing" : "Next"
    }

    static let all: [FirstLaunchOnboardingStep] = [
        FirstLaunchOnboardingStep(tabName: "Status", cardTitle: "Block distractions", targetID: "Screen Time Access", body: "AntiScroll blocks the apps and websites you choose, only when you start a focus block.", systemImage: "shield.lefthalf.filled"),
        FirstLaunchOnboardingStep(tabName: "Status", cardTitle: "Allow Screen Time", targetID: "Screen Time Access", body: "iOS needs Screen Time permission so AntiScroll can show Apple’s picker and apply shields. AntiScroll cannot see private content.", systemImage: "lock.shield", requestsScreenTimePermission: true),
        FirstLaunchOnboardingStep(tabName: "Status", cardTitle: "Choose what to block", targetID: "App Selection", body: "Pick distracting apps, categories, and websites. You can change this anytime.", systemImage: "app.badge"),
        FirstLaunchOnboardingStep(tabName: "Status", cardTitle: "Start your first block", targetID: "Quick Block", body: "Use Quick Block when you want protection right now. Choose a length, then start focusing.", systemImage: "bolt.shield.fill")
    ]
}

struct FirstLaunchOnboardingState: Equatable {
    var hasCompletedOnboarding: Bool

    var shouldPresent: Bool { !hasCompletedOnboarding }

    mutating func markCompleted() {
        hasCompletedOnboarding = true
    }
}


enum ActiveScheduleMotivation {
    static func quote(for date: Date = Date()) -> String {
        let quotes = [
            "Small steps beat big distractions.",
            "Your focus window is protected.",
            "Keep going. This time is yours."
        ]
        let day = Calendar.current.component(.day, from: date)
        return quotes[day % quotes.count]
    }
}
