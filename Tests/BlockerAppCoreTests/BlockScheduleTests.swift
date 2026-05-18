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
}
