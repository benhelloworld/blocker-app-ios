import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

enum MacBlockPlanSyncError: LocalizedError, Equatable {
    case cloudKitUnavailable
    case iCloudAccountUnavailable
    case malformedRecord

    var errorDescription: String? {
        switch self {
        case .cloudKitUnavailable:
            return "iCloud sync is not available in this build."
        case .iCloudAccountUnavailable:
            return "Sign into iCloud with your Apple ID, then reopen Blocker."
        case .malformedRecord:
            return "The Mac sync plan in iCloud could not be read."
        }
    }
}

#if canImport(CloudKit)
final class MacBlockPlanSyncService {
    static let shared = MacBlockPlanSyncService()
    static let containerIdentifier = "iCloud.com.benberther.BlockerApp"
    static let iCloudDrivePlanFileName = "currentMacBlockPlan.json"

    private let container: CKContainer
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: "currentMacBlockPlan")

    private struct SyncedPeriodKey: Hashable {
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
    }

    private func currentSchedules(domains: [String]) -> [SyncedMacSchedule] {
        guard ShieldStorage.shared.loadScheduleEnabled() else { return [] }
        let schedule = ShieldStorage.shared.loadSchedule()
        let protectedDeviceIDs = schedule.effectiveProtectedDeviceIDs(
            defaultRemoteDeviceIDs: ShieldStorage.shared.loadSelectedMacDeviceIDs()
        )

        var weekdaysByPeriod: [SyncedPeriodKey: Set<Int>] = [:]
        for (weekday, periods) in schedule.periodsByWeekday {
            for period in periods {
                let key = SyncedPeriodKey(
                    startHour: period.startHour,
                    startMinute: period.startMinute,
                    endHour: period.endHour,
                    endMinute: period.endMinute
                )
                weekdaysByPeriod[key, default: []].insert(weekday)
            }
        }

        return weekdaysByPeriod.map { key, weekdays in
            SyncedMacSchedule(
                domains: domains,
                startHour: key.startHour,
                startMinute: key.startMinute,
                endHour: key.endHour,
                endMinute: key.endMinute,
                selectedWeekdays: Array(weekdays),
                timeZoneIdentifier: TimeZone.current.identifier,
                targetDeviceIDs: Array(protectedDeviceIDs)
            )
        }.sorted {
            if $0.startHour == $1.startHour { return $0.startMinute < $1.startMinute }
            return $0.startHour < $1.startHour
        }
    }

    private func activeSession() -> SyncedMacImmediateSession? {
        guard let session = ShieldStorage.shared.loadActiveImmediateSession() else { return nil }
        return SyncedMacImmediateSession(start: session.start, durationMinutes: session.durationMinutes)
    }

    init(containerIdentifier: String = MacBlockPlanSyncService.containerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }

    func loadPlan() async throws -> SyncedMacBlockPlan? {
        var lastError: Error?

        do {
            let status = try await container.accountStatus()
            guard status == .available else { throw MacBlockPlanSyncError.iCloudAccountUnavailable }
            let record = try await database.record(for: recordID)
            guard let data = record["payload"] as? Data else { throw MacBlockPlanSyncError.malformedRecord }
            return try JSONDecoder().decode(SyncedMacBlockPlan.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            // Fall through to the iCloud Drive copy below. New devices can receive
            // the file before the private CloudKit record becomes visible.
            lastError = error
        } catch {
            lastError = error
        }

        if let drivePlan = try? loadPlanFromICloudDrive() {
            return drivePlan
        }

        if let lastError {
            throw lastError
        }
        return nil
    }

    func savePlan(_ plan: SyncedMacBlockPlan) async throws {
        let payload = try JSONEncoder().encode(plan)
        var savedToICloudDrive = false
        var lastError: Error?

        do {
            try savePlanToICloudDrive(payload)
            savedToICloudDrive = true
        } catch {
            lastError = error
        }

        do {
            let status = try await container.accountStatus()
            guard status == .available else { throw MacBlockPlanSyncError.iCloudAccountUnavailable }

            let record: CKRecord
            do {
                record = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: "MacBlockPlan", recordID: recordID)
            }

            record["payload"] = payload as CKRecordValue
            record["updatedAt"] = plan.updatedAt as CKRecordValue
            try await database.save(record)
        } catch {
            lastError = error
        }

        if !savedToICloudDrive, let lastError {
            throw lastError
        }
    }

    private func savePlanToICloudDrive(_ payload: Data) throws {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: Self.containerIdentifier) else {
            throw MacBlockPlanSyncError.iCloudAccountUnavailable
        }
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let planURL = documentsURL.appendingPathComponent(Self.iCloudDrivePlanFileName)
        try payload.write(to: planURL, options: [.atomic])
    }


    private func loadPlanFromICloudDrive() throws -> SyncedMacBlockPlan? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: Self.containerIdentifier) else {
            throw MacBlockPlanSyncError.iCloudAccountUnavailable
        }
        let planURL = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(Self.iCloudDrivePlanFileName)
        guard FileManager.default.fileExists(atPath: planURL.path) else { return nil }
        let payload = try Data(contentsOf: planURL)
        return try JSONDecoder().decode(SyncedMacBlockPlan.self, from: payload)
    }

    func saveCurrentSelection(domains: [String], durationMinutes: Int, targetDeviceIDs: [String], adultWebFilterEnabled: Bool) async throws {
        let plan = SyncedMacBlockPlan(domains: domains, durationMinutes: durationMinutes, updatedAt: Date(), activeSession: activeSession(), targetDeviceIDs: targetDeviceIDs, adultWebFilterEnabled: adultWebFilterEnabled, schedules: currentSchedules(domains: domains))
        try await savePlan(plan)
    }

    func saveActiveSession(domains: [String], session: ImmediateBlockSession, targetDeviceIDs: [String], adultWebFilterEnabled: Bool = false) async throws {
        let plan = SyncedMacBlockPlan(
            domains: domains,
            durationMinutes: session.durationMinutes,
            updatedAt: Date(),
            activeSession: SyncedMacImmediateSession(start: session.start, durationMinutes: session.durationMinutes),
            targetDeviceIDs: targetDeviceIDs,
            adultWebFilterEnabled: adultWebFilterEnabled,
            schedules: currentSchedules(domains: domains)
        )
        try await savePlan(plan)
    }

    func clearActiveSessionKeepingSelection(domains: [String], durationMinutes: Int, targetDeviceIDs: [String], adultWebFilterEnabled: Bool = false) async throws {
        let plan = SyncedMacBlockPlan(domains: domains, durationMinutes: durationMinutes, updatedAt: Date(), activeSession: nil, targetDeviceIDs: targetDeviceIDs, adultWebFilterEnabled: adultWebFilterEnabled, schedules: currentSchedules(domains: domains))
        try await savePlan(plan)
    }

    func publishCurrentConfiguration() async throws {
        AutoWebsiteSync.shared.refreshSharedDomains()
        let domains = AutoWebsiteSync.shared.mergedDomains(withManual: ShieldStorage.shared.loadMacBlockDomains())
        try await saveCurrentSelection(
            domains: domains,
            durationMinutes: ShieldStorage.shared.loadActiveImmediateSession()?.durationMinutes ?? 60,
            targetDeviceIDs: ShieldStorage.shared.loadSelectedMacDeviceIDs(),
            adultWebFilterEnabled: ShieldStorage.shared.loadAdultWebFilterEnabled()
        )
    }
}
#else
final class MacBlockPlanSyncService {
    static let shared = MacBlockPlanSyncService()
    func loadPlan() async throws -> SyncedMacBlockPlan? { throw MacBlockPlanSyncError.cloudKitUnavailable }
    func savePlan(_ plan: SyncedMacBlockPlan) async throws { throw MacBlockPlanSyncError.cloudKitUnavailable }
    func saveCurrentSelection(domains: [String], durationMinutes: Int, targetDeviceIDs: [String], adultWebFilterEnabled: Bool) async throws { throw MacBlockPlanSyncError.cloudKitUnavailable }
    func saveActiveSession(domains: [String], session: ImmediateBlockSession, targetDeviceIDs: [String], adultWebFilterEnabled: Bool = false) async throws { throw MacBlockPlanSyncError.cloudKitUnavailable }
    func clearActiveSessionKeepingSelection(domains: [String], durationMinutes: Int, targetDeviceIDs: [String], adultWebFilterEnabled: Bool = false) async throws { throw MacBlockPlanSyncError.cloudKitUnavailable }
    func publishCurrentConfiguration() async throws { throw MacBlockPlanSyncError.cloudKitUnavailable }
}
#endif
