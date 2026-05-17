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
}
