import XCTest
@testable import MacCompanionCore

final class HostsFileManagerTests: XCTestCase {
    func testUpdatedHostsAddsManagedBlock() throws {
        let manager = HostsFileManager()
        let hosts = "127.0.0.1 localhost\n255.255.255.255 broadcasthost\n"

        let updated = try manager.updatedHosts(existingHosts: hosts, domains: ["https://YouTube.com/watch?v=1", "www.youtube.com"])

        XCTAssertTrue(updated.contains(HostsFileManager.startMarker))
        XCTAssertTrue(updated.contains("0.0.0.0 youtube.com"))
        XCTAssertTrue(updated.contains("::1 www.youtube.com"))
        XCTAssertTrue(updated.contains("127.0.0.1 localhost"))
    }

    func testUpdatedHostsReplacesExistingManagedBlock() throws {
        let manager = HostsFileManager()
        let first = try manager.updatedHosts(existingHosts: "127.0.0.1 localhost\n", domains: ["youtube.com"])
        let second = try manager.updatedHosts(existingHosts: first, domains: ["reddit.com"])

        XCTAssertFalse(second.contains("youtube.com"))
        XCTAssertTrue(second.contains("reddit.com"))
        XCTAssertEqual(second.components(separatedBy: HostsFileManager.startMarker).count, 2)
    }

    func testClearedHostsRemovesOnlyManagedBlock() throws {
        let manager = HostsFileManager()
        let blocked = try manager.updatedHosts(existingHosts: "127.0.0.1 localhost\n", domains: ["youtube.com"])
        let cleared = manager.clearedHosts(existingHosts: blocked)

        XCTAssertTrue(cleared.contains("127.0.0.1 localhost"))
        XCTAssertFalse(cleared.contains(HostsFileManager.startMarker))
        XCTAssertFalse(cleared.contains("youtube.com"))
    }

    func testInvalidDomainThrows() {
        let manager = HostsFileManager()
        XCTAssertThrowsError(try manager.sanitizedDomains(["bad domain.com"]))
        XCTAssertThrowsError(try manager.sanitizedDomains(["localhost"]))
    }

    func testManagedDomainsReadsOnlyActiveBlockDomains() throws {
        let manager = HostsFileManager()
        let hosts = try manager.updatedHosts(existingHosts: "127.0.0.1 localhost\n", domains: ["youtube.com", "www.youtube.com"])

        XCTAssertEqual(HostsFileManager.managedDomains(in: hosts), ["www.youtube.com", "youtube.com"])
    }

    func testFirewallRulesBlockResolvedIPs() {
        let rules = PrivilegedHostsWriter.pfRules(for: ["57.144.120.1", "2a03:2880:f33c:1:face:b00c:0:25de"])

        XCTAssertTrue(rules.contains("table <blockerapp_blocked>"))
        XCTAssertTrue(rules.contains("block drop out quick to <blockerapp_blocked>"))
        XCTAssertTrue(rules.contains("57.144.120.1"))
    }

    func testHelperScriptAppliesFirewallAndFlushesCaches() {
        XCTAssertTrue(PrivilegedHostsWriter.helperScript.contains("pfctl -a com.blockerapp.maccompanion"))
        XCTAssertTrue(PrivilegedHostsWriter.helperScript.contains("dscacheutil -flushcache"))
    }

    func testHelperNeverInstallsPasswordlessSudoAuthorization() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent("Sources/MacCompanionCore/PrivilegedHostsWriter.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("NOPASSWD:"))
        XCTAssertFalse(source.contains("arguments: [\"-n\""))
    }

    func testPreexistingPersistentHelperSymlinkCannotBeOverwritten() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent("Sources/MacCompanionCore/PrivilegedHostsWriter.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("helper_file=\"$temp_dir/helper\""))
        XCTAssertTrue(source.contains("> \"$helper_file\""))
        XCTAssertFalse(source.contains("> '__HELPER_PATH__'"))
        XCTAssertFalse(source.contains("/bin/mkdir -p /usr/local/bin"))
    }

    func testPhonePublishedPlanTargetsThisMac() {
        let plan = SyncedMacBlockPlan(domains: ["youtube.com"], targetDeviceIDs: [MacCompanionDevice.currentDeviceID])
        let other = SyncedMacBlockPlan(domains: ["youtube.com"], targetDeviceIDs: ["other-mac"])

        XCTAssertTrue(MacCompanionDevice.planTargetsThisDevice(plan))
        XCTAssertFalse(MacCompanionDevice.planTargetsThisDevice(other))
    }

    func testSyncedImmediateSessionKeepsRemoteDuration() {
        let start = Date(timeIntervalSince1970: 100)
        let session = SyncedImmediateSession(start: start, durationMinutes: 120)

        XCTAssertTrue(session.isActive(at: Date(timeIntervalSince1970: 101)))
        XCTAssertFalse(session.isActive(at: Date(timeIntervalSince1970: 100 + 121 * 60)))
    }



    func testSyncedPlanPreservesEmptyPhoneDomainSelection() {
        let plan = SyncedMacBlockPlan(domains: [], targetDeviceIDs: [MacCompanionDevice.currentDeviceID])

        XCTAssertEqual(plan.domains, [])
        XCTAssertTrue(MacCompanionDevice.planTargetsThisDevice(plan))
    }

    func testSyncedPlanDoesNotAddStarterDomains() {
        let plan = SyncedMacBlockPlan(domains: ["instagram.com"], targetDeviceIDs: [MacCompanionDevice.currentDeviceID])

        XCTAssertEqual(plan.domains, ["instagram.com"])
        XCTAssertFalse(plan.domains.contains("youtube.com"))
    }

    func testAdultWebsitePresetContainsOneHundredUniqueBaseDomains() {
        XCTAssertEqual(AdultWebsitePreset.domains.count, 100)
        XCTAssertEqual(Set(AdultWebsitePreset.domains).count, 100)
        XCTAssertTrue(AdultWebsitePreset.domains.contains("pornhub.com"))
        XCTAssertTrue(AdultWebsitePreset.domains.contains("xvideos.com"))
    }

    func testAdultWebsitePresetExpandsAlongsideCustomDomains() {
        let plan = SyncedMacBlockPlan(
            domains: ["example.com", "pornhub.com"],
            targetDeviceIDs: [MacCompanionDevice.currentDeviceID],
            adultWebFilterEnabled: true
        )

        XCTAssertTrue(plan.effectiveDomains.contains("example.com"))
        XCTAssertTrue(plan.effectiveDomains.contains("pornhub.com"))
        XCTAssertTrue(plan.effectiveDomains.contains("www.pornhub.com"))
        XCTAssertEqual(Set(plan.effectiveDomains).count, plan.effectiveDomains.count)
    }

    func testLegacyPlanWithoutAdultFlagDecodesAsDisabled() throws {
        struct LegacyPlan: Encodable {
            let domains = ["youtube.com"]
            let durationMinutes = 45
            let updatedAt = Date(timeIntervalSince1970: 100)
            let activeSession: SyncedImmediateSession? = nil
            let targetDeviceIDs = [MacCompanionDevice.currentDeviceID]
        }

        let decoded = try JSONDecoder().decode(
            SyncedMacBlockPlan.self,
            from: JSONEncoder().encode(LegacyPlan())
        )

        XCTAssertFalse(decoded.adultWebFilterEnabled)
        XCTAssertEqual(decoded.effectiveDomains, ["youtube.com"])
    }

    func testScheduledPlanActivatesOnMatchingWeekdayUsingItsOwnDomains() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10))!
        let schedule = SyncedMacSchedule(
            domains: ["instagram.com"],
            startHour: 9,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            selectedWeekdays: [2],
            timeZoneIdentifier: "GMT"
        )
        let plan = SyncedMacBlockPlan(
            domains: ["youtube.com"],
            targetDeviceIDs: [MacCompanionDevice.currentDeviceID],
            schedules: [schedule]
        )

        let protection = plan.activeProtection(at: monday, calendar: calendar)

        XCTAssertEqual(protection?.domains, ["instagram.com"])
        XCTAssertEqual(protection?.source, .schedule)
        XCTAssertTrue(protection?.session.isActive(at: monday) == true)
    }

    func testOvernightScheduleUsesTheWeekdayOnWhichItStarted() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let tuesdayAfterMidnight = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 1))!
        let schedule = SyncedMacSchedule(
            domains: ["reddit.com"],
            startHour: 22,
            startMinute: 0,
            endHour: 6,
            endMinute: 0,
            selectedWeekdays: [2],
            timeZoneIdentifier: "GMT"
        )
        let plan = SyncedMacBlockPlan(domains: [], schedules: [schedule])

        XCTAssertEqual(plan.activeProtection(at: tuesdayAfterMidnight, calendar: calendar)?.domains, ["reddit.com"])
    }

    func testVersionTwoEmptyTargetsMeansNoMacIsSelected() {
        let plan = SyncedMacBlockPlan(domains: ["youtube.com"], targetDeviceIDs: [], schemaVersion: 2)

        XCTAssertFalse(MacCompanionDevice.planTargetsThisDevice(plan))
    }

    func testLegacyPlanWithoutSchedulesStillDecodes() throws {
        struct LegacyPlan: Encodable {
            let domains = ["youtube.com"]
            let durationMinutes = 45
            let updatedAt = Date(timeIntervalSince1970: 100)
            let activeSession: SyncedImmediateSession? = nil
            let targetDeviceIDs = [MacCompanionDevice.currentDeviceID]
        }

        let decoded = try JSONDecoder().decode(SyncedMacBlockPlan.self, from: JSONEncoder().encode(LegacyPlan()))

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.schedules, [])
        XCTAssertTrue(MacCompanionDevice.planTargetsThisDevice(decoded))
    }

    func testScheduleTargetsAreIndependentFromQuickBlockTargets() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10))!
        let schedule = SyncedMacSchedule(
            domains: ["instagram.com"],
            startHour: 9,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            selectedWeekdays: [2],
            timeZoneIdentifier: "GMT",
            targetDeviceIDs: [MacCompanionDevice.currentDeviceID]
        )
        let plan = SyncedMacBlockPlan(
            domains: ["youtube.com"],
            activeSession: SyncedImmediateSession(start: monday.addingTimeInterval(-60), durationMinutes: 120),
            targetDeviceIDs: ["other-mac"],
            schedules: [schedule],
            schemaVersion: 3
        )

        XCTAssertTrue(MacCompanionDevice.planTargetsThisDevice(plan))
        XCTAssertEqual(plan.activeProtection(at: monday, calendar: calendar, deviceID: MacCompanionDevice.currentDeviceID)?.domains, ["instagram.com"])
        XCTAssertNil(plan.activeProtection(at: monday, calendar: calendar, deviceID: "unselected-mac"))
    }

    func testVersionTwoScheduleInheritsPlanTargets() throws {
        struct VersionTwoSchedule: Encodable {
            let domains = ["reddit.com"]
            let startHour = 9
            let startMinute = 0
            let endHour = 12
            let endMinute = 0
            let selectedWeekdays = [2]
            let timeZoneIdentifier = "GMT"
        }
        struct VersionTwoPlan: Encodable {
            let domains: [String] = []
            let durationMinutes = 60
            let updatedAt = Date(timeIntervalSince1970: 100)
            let activeSession: SyncedImmediateSession? = nil
            let targetDeviceIDs = [MacCompanionDevice.currentDeviceID]
            let adultWebFilterEnabled = false
            let schedules = [VersionTwoSchedule()]
            let schemaVersion = 2
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10))!
        let plan = try JSONDecoder().decode(SyncedMacBlockPlan.self, from: JSONEncoder().encode(VersionTwoPlan()))

        XCTAssertEqual(plan.activeProtection(at: monday, calendar: calendar, deviceID: MacCompanionDevice.currentDeviceID)?.domains, ["reddit.com"])
    }

}
