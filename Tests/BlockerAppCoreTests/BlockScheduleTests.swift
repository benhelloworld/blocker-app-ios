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
}
