import XCTest
@testable import BlockerAppCore

final class BlockScheduleTests: XCTestCase {
    func testContainsTimeInsideSameDaySchedule() throws {
        let schedule = try BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        XCTAssertTrue(schedule.contains(hour: 12, minute: 30))
    }

    func testExcludesTimeOutsideSameDaySchedule() throws {
        let schedule = try BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        XCTAssertFalse(schedule.contains(hour: 8, minute: 59))
        XCTAssertFalse(schedule.contains(hour: 17, minute: 0))
    }

    func testContainsTimeAcrossMidnight() throws {
        let schedule = try BlockSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
        XCTAssertTrue(schedule.contains(hour: 23, minute: 30))
        XCTAssertTrue(schedule.contains(hour: 5, minute: 59))
        XCTAssertFalse(schedule.contains(hour: 12, minute: 0))
    }

    func testRejectsInvalidHourAndMinute() {
        XCTAssertThrowsError(try BlockSchedule(startHour: 24, startMinute: 0, endHour: 6, endMinute: 0))
        XCTAssertThrowsError(try BlockSchedule(startHour: 22, startMinute: 60, endHour: 6, endMinute: 0))
    }

    func testImmediateBlockSessionBuildsScheduleFromStartDateAndDuration() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 14, minute: 30))!

        let session = ImmediateBlockSession(start: start, durationMinutes: 90, calendar: calendar)

        XCTAssertEqual(session.schedule, try BlockSchedule(startHour: 14, startMinute: 30, endHour: 16, endMinute: 0))
        XCTAssertEqual(session.durationLabel, "1.5 hours")
    }

    func testImmediateBlockSessionCanCrossMidnight() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 23, minute: 45))!

        let session = ImmediateBlockSession(start: start, durationMinutes: 45, calendar: calendar)

        XCTAssertEqual(session.schedule, try BlockSchedule(startHour: 23, startMinute: 45, endHour: 0, endMinute: 30))
        XCTAssertTrue(session.schedule.crossesMidnight)
    }

    func testImmediateBlockSessionReportsActiveStateAndRemainingMinutes() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 10, minute: 0))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 120, calendar: calendar)
        let halfway = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 11, minute: 0))!
        let afterEnd = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 12, minute: 1))!

        XCTAssertTrue(session.isActive(at: halfway))
        XCTAssertEqual(session.remainingMinutes(at: halfway), 60)
        XCTAssertEqual(session.progress(at: halfway), 0.5)
        XCTAssertFalse(session.isActive(at: afterEnd))
        XCTAssertEqual(session.remainingMinutes(at: afterEnd), 0)
    }

    func testImmediateBlockSessionSupportsOvernightStatusText() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 23, minute: 30))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 90, calendar: calendar)
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 0, minute: 15))!

        XCTAssertTrue(session.isActive(at: now))
        XCTAssertEqual(session.remainingMinutes(at: now), 45)
        XCTAssertEqual(session.progress(at: now), 0.5)
    }


    func testScheduleDefaultsToAllWeekdaysForExistingDailyBlocks() throws {
        let schedule = try BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        XCTAssertEqual(schedule.selectedWeekdays, Set(1...7))
        XCTAssertEqual(schedule.selectedWeekdaySymbols, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
    }

    func testScheduleOnlyContainsSelectedWeekdays() throws {
        let schedule = try BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, selectedWeekdays: [2, 4, 6])

        XCTAssertTrue(schedule.contains(weekday: 2, hour: 10, minute: 0))
        XCTAssertTrue(schedule.contains(weekday: 4, hour: 10, minute: 0))
        XCTAssertFalse(schedule.contains(weekday: 3, hour: 10, minute: 0))
        XCTAssertFalse(schedule.contains(weekday: 6, hour: 18, minute: 0))
        XCTAssertEqual(schedule.selectedWeekdaySymbols, ["Mon", "Wed", "Fri"])
    }


    func testFocusStatsRecordsQuickBlockSessionsAndMinutes() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 14, minute: 30))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 90, calendar: calendar)

        var stats = FocusStats()
        stats.record(session: session, calendar: calendar)

        XCTAssertEqual(stats.totalSessions, 1)
        XCTAssertEqual(stats.totalPlannedMinutes, 90)
        XCTAssertEqual(stats.totalHoursLabel, "1.5h")
        XCTAssertEqual(stats.focusDayCount, 1)
    }

    func testFocusStatsCalculatesCurrentStreakAcrossConsecutiveDays() {
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 9, minute: 0))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 19, hour: 9, minute: 0))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 9, minute: 0))!

        var stats = FocusStats()
        stats.record(session: ImmediateBlockSession(start: monday, durationMinutes: 30, calendar: calendar), calendar: calendar)
        stats.record(session: ImmediateBlockSession(start: tuesday, durationMinutes: 30, calendar: calendar), calendar: calendar)

        XCTAssertEqual(stats.currentStreakDays(asOf: tuesday, calendar: calendar), 2)
        XCTAssertEqual(stats.currentStreakDays(asOf: wednesday, calendar: calendar), 0)
    }



    func testFrictionUnlockReasonsMatchTheReflectionOptions() {
        XCTAssertEqual(FrictionUnlockReason.allOptions.map(\.title), ["Bored", "Stressed", "Tired", "Habit", "Need something important", "Other"])
    }

    func testFrictionUnlockReflectionRequiresABlockReasonAndStopReason() {
        XCTAssertFalse(FrictionUnlockReflection(blockReason: "", stopReason: .bored).isComplete)
        XCTAssertFalse(FrictionUnlockReflection(blockReason: "Study", stopReason: nil).isComplete)
        XCTAssertTrue(FrictionUnlockReflection(blockReason: "Study", stopReason: .needSomethingImportant).isComplete)
    }



    func testDelayModeUsesFifteenSecondWaitAndCalmCopy() {
        let delay = DelayModeConfiguration.default

        XCTAssertEqual(delay.waitSeconds, 15)
        XCTAssertEqual(delay.title, "Wait 15 seconds")
        XCTAssertEqual(delay.message, "If you still want it, continue.")
    }

    func testFocusTemplatesExposeTheRequestedPresets() {
        XCTAssertEqual(FocusTemplate.allPresets.map(\.name), ["Work Mode", "Sleep Mode", "Morning Mode", "Study Mode", "Gym Mode"])
        XCTAssertEqual(FocusTemplate.work.defaultDurationMinutes, 60)
        XCTAssertTrue(FocusTemplate.sleep.blockingIntent.contains("everything except essentials"))
        XCTAssertEqual(FocusTemplate.morning.scheduleHint, "Until 10 AM")
    }

    func testAccountabilityReceiptUsesPositiveCompletionCopy() {
        let receipt = AccountabilityReceipt(protectedMinutes: 60)

        XCTAssertEqual(receipt.headline, "You protected 1 hour.")
        XCTAssertEqual(receipt.lines, ["Apps stayed blocked.", "Commitment kept."])
    }

    func testSmartSuggestionsReactToNightBlocksAndEarlyStops() {
        var stats = FocusStats(totalSessions: 3, totalPlannedMinutes: 180)
        let calendar = Calendar(identifier: .gregorian)
        let night = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 22, minute: 30))!
        stats.lastSessionStart = night
        let reflections = [
            FrictionUnlockReflection(blockReason: "Sleep", stopReason: .habit, completedAt: night),
            FrictionUnlockReflection(blockReason: "Sleep", stopReason: .bored, completedAt: night)
        ]

        let suggestions = SmartSuggestionEngine.suggestions(stats: stats, frictionUnlocks: reflections, calendar: calendar)

        XCTAssertTrue(suggestions.map(\.title).contains("Try a Sleep Block preset"))
        XCTAssertTrue(suggestions.map(\.title).contains("Try a shorter 30 min block"))
    }


    func testDelayAppsConfigurationIsIndependentFromBlockingSelection() throws {
        let delayApps = DelayAppsConfiguration(isEnabled: true, appCount: 2, categoryCount: 1, webDomainCount: 0)
        let blockSchedule = try BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let immediateBlock = ImmediateBlockSession(durationMinutes: 60)

        XCTAssertTrue(delayApps.isEnabled)
        XCTAssertEqual(delayApps.totalSelectionCount, 3)
        XCTAssertEqual(delayApps.waitSeconds, 15)
        XCTAssertEqual(blockSchedule, try BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0))
        XCTAssertEqual(immediateBlock.durationMinutes, 60)
    }

    func testDelayAppsConfigurationCanBeClearedWithoutTouchingBlockState() {
        let enabled = DelayAppsConfiguration(isEnabled: true, appCount: 4, categoryCount: 2, webDomainCount: 1)
        let cleared = enabled.clearedSelection()

        XCTAssertEqual(enabled.totalSelectionCount, 7)
        XCTAssertTrue(cleared.isEnabled)
        XCTAssertEqual(cleared.totalSelectionCount, 0)
        XCTAssertEqual(cleared.waitSeconds, 15)
    }



    func testDelayAppsWaitGateStartsWaitInsteadOfBlockingCompletionThread() throws {
        let gate = DelayAppsWaitGate()
        let start = Date(timeIntervalSince1970: 1_000)

        let decision = gate.decision(now: start, waitStartedAt: nil)

        XCTAssertEqual(decision, .startWaiting(unlockAt: start.addingTimeInterval(15)))
        XCTAssertEqual(gate.remainingSeconds(now: start.addingTimeInterval(12), unlockAt: start.addingTimeInterval(15)), 3)
    }

    func testDelayAppsWaitGateAllowsOnlyAfterFifteenSecondPause() throws {
        let gate = DelayAppsWaitGate()
        let start = Date(timeIntervalSince1970: 2_000)
        let unlockAt = start.addingTimeInterval(15)

        XCTAssertEqual(gate.decision(now: start.addingTimeInterval(14), waitStartedAt: start), .keepWaiting(remainingSeconds: 1))
        XCTAssertEqual(gate.decision(now: unlockAt, waitStartedAt: start), .allowAccess)
        XCTAssertEqual(gate.decision(now: start.addingTimeInterval(30), waitStartedAt: start), .allowAccess)
    }


    func testDelayAppsPauseProgressShowsDescendingBarAndRemainingSeconds() {
        let full = DelayAppsPauseProgress(waitSeconds: 15, remainingSeconds: 15)
        let mid = DelayAppsPauseProgress(waitSeconds: 15, remainingSeconds: 7)
        let done = DelayAppsPauseProgress(waitSeconds: 15, remainingSeconds: 0)

        XCTAssertEqual(full.barText, "██████████")
        XCTAssertEqual(mid.barText, "█████░░░░░")
        XCTAssertEqual(done.barText, "░░░░░░░░░░")
        XCTAssertEqual(mid.statusText, "7s left")
        XCTAssertEqual(done.statusText, "Ready")
    }

}