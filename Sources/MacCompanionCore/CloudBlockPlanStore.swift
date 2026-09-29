import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

public struct SyncedMacBlockPlan: Codable, Equatable, Sendable {
    public var domains: [String]
    public var durationMinutes: Int
    public var updatedAt: Date
    public var activeSession: SyncedImmediateSession?
    public var targetDeviceIDs: [String]
    public var adultWebFilterEnabled: Bool
    public var schedules: [SyncedMacSchedule]
    public var schemaVersion: Int

    public init(domains: [String], durationMinutes: Int = 60, updatedAt: Date = Date(), activeSession: SyncedImmediateSession? = nil, targetDeviceIDs: [String] = [MacCompanionDevice.currentDeviceID], adultWebFilterEnabled: Bool = false, schedules: [SyncedMacSchedule] = [], schemaVersion: Int = 3) {
        self.domains = domains
        self.durationMinutes = max(1, durationMinutes)
        self.updatedAt = updatedAt
        self.activeSession = activeSession
        self.targetDeviceIDs = targetDeviceIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }.sorted()
        self.adultWebFilterEnabled = adultWebFilterEnabled
        self.schedules = schedules
        self.schemaVersion = max(1, schemaVersion)
    }

    public var effectiveDomains: [String] {
        guard adultWebFilterEnabled else { return domains }
        return AdultWebsitePreset.expandedDomains(merging: domains)
    }

    private enum CodingKeys: String, CodingKey {
        case domains, durationMinutes, updatedAt, activeSession, targetDeviceIDs, adultWebFilterEnabled, schedules, schemaVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            domains: try container.decode([String].self, forKey: .domains),
            durationMinutes: try container.decode(Int.self, forKey: .durationMinutes),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            activeSession: try container.decodeIfPresent(SyncedImmediateSession.self, forKey: .activeSession),
            targetDeviceIDs: try container.decodeIfPresent([String].self, forKey: .targetDeviceIDs) ?? [],
            adultWebFilterEnabled: try container.decodeIfPresent(Bool.self, forKey: .adultWebFilterEnabled) ?? false,
            schedules: try container.decodeIfPresent([SyncedMacSchedule].self, forKey: .schedules) ?? [],
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        )
    }

    public func targetsQuickBlockDevice(_ deviceID: String) -> Bool {
        if schemaVersion <= 1 && targetDeviceIDs.isEmpty { return true }
        return targetDeviceIDs.contains(deviceID)
    }

    public func targetsDevice(_ deviceID: String) -> Bool {
        targetsQuickBlockDevice(deviceID) || schedules.contains {
            $0.targets(deviceID: deviceID, planSchemaVersion: schemaVersion, legacyPlanTargetDeviceIDs: targetDeviceIDs)
        }
    }

    public func activeProtection(at date: Date = Date(), calendar: Calendar = .current, deviceID: String = MacCompanionDevice.currentDeviceID) -> SyncedMacProtection? {
        var domains: [String] = []
        var sessions: [SyncedImmediateSession] = []
        var hasQuickBlock = false
        var hasSchedule = false

        if targetsQuickBlockDevice(deviceID), let activeSession, activeSession.isActive(at: date) {
            domains.append(contentsOf: effectiveDomains)
            sessions.append(activeSession)
            hasQuickBlock = true
        }

        for schedule in schedules {
            guard schedule.targets(deviceID: deviceID, planSchemaVersion: schemaVersion, legacyPlanTargetDeviceIDs: targetDeviceIDs) else { continue }
            guard let session = schedule.activeSession(at: date, calendar: calendar) else { continue }
            domains.append(contentsOf: schedule.domains)
            sessions.append(session)
            hasSchedule = true
        }

        guard let start = sessions.map(\.start).min(), let end = sessions.map(\.end).max() else { return nil }
        if adultWebFilterEnabled {
            domains = AdultWebsitePreset.expandedDomains(merging: domains)
        }
        let uniqueDomains = Array(Set(domains.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })).sorted()
        let minutes = max(1, Int(ceil(end.timeIntervalSince(start) / 60)))
        let source: SyncedMacProtection.Source = hasQuickBlock && hasSchedule ? .combined : (hasQuickBlock ? .quickBlock : .schedule)
        return SyncedMacProtection(domains: uniqueDomains, session: SyncedImmediateSession(start: start, durationMinutes: minutes), source: source)
    }
}

public struct SyncedMacSchedule: Codable, Equatable, Sendable {
    public var domains: [String]
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var selectedWeekdays: [Int]
    public var timeZoneIdentifier: String
    public var targetDeviceIDs: [String]?

    public init(domains: [String], startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, selectedWeekdays: [Int], timeZoneIdentifier: String = TimeZone.current.identifier, targetDeviceIDs: [String]? = nil) {
        self.domains = Array(Set(domains.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })).sorted()
        self.startHour = min(23, max(0, startHour))
        self.startMinute = min(59, max(0, startMinute))
        self.endHour = min(23, max(0, endHour))
        self.endMinute = min(59, max(0, endMinute))
        self.selectedWeekdays = Array(Set(selectedWeekdays.filter { (1...7).contains($0) })).sorted()
        self.timeZoneIdentifier = TimeZone(identifier: timeZoneIdentifier)?.identifier ?? TimeZone.current.identifier
        self.targetDeviceIDs = targetDeviceIDs.map {
            Array(Set($0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })).sorted()
        }
    }

    public func targets(deviceID: String, planSchemaVersion: Int, legacyPlanTargetDeviceIDs: [String]) -> Bool {
        if let targetDeviceIDs { return targetDeviceIDs.contains(deviceID) }
        if planSchemaVersion <= 1 && legacyPlanTargetDeviceIDs.isEmpty { return true }
        return legacyPlanTargetDeviceIDs.contains(deviceID)
    }

    public func activeSession(at date: Date = Date(), calendar baseCalendar: Calendar = .current) -> SyncedImmediateSession? {
        var calendar = baseCalendar
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? baseCalendar.timeZone
        let now = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = now.weekday, let hour = now.hour, let minute = now.minute else { return nil }
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        let crossesMidnight = endMinutes <= startMinutes

        let startDayOffset: Int
        let startWeekday: Int
        if crossesMidnight && currentMinutes < endMinutes {
            startDayOffset = -1
            startWeekday = weekday == 1 ? 7 : weekday - 1
        } else {
            startDayOffset = 0
            startWeekday = weekday
        }
        guard selectedWeekdays.contains(startWeekday) else { return nil }

        let isWithinWindow = crossesMidnight
            ? (currentMinutes >= startMinutes || currentMinutes < endMinutes)
            : (currentMinutes >= startMinutes && currentMinutes < endMinutes)
        guard isWithinWindow else { return nil }

        let startDay = calendar.date(byAdding: .day, value: startDayOffset, to: date) ?? date
        var startComponents = calendar.dateComponents([.year, .month, .day], from: startDay)
        startComponents.hour = startHour
        startComponents.minute = startMinute
        startComponents.second = 0
        guard let start = calendar.date(from: startComponents) else { return nil }

        let endDay = crossesMidnight ? (calendar.date(byAdding: .day, value: 1, to: start) ?? start) : start
        var endComponents = calendar.dateComponents([.year, .month, .day], from: endDay)
        endComponents.hour = endHour
        endComponents.minute = endMinute
        endComponents.second = 0
        guard let end = calendar.date(from: endComponents), end > start else { return nil }
        return SyncedImmediateSession(start: start, durationMinutes: max(1, Int(ceil(end.timeIntervalSince(start) / 60))))
    }
}

public struct SyncedMacProtection: Equatable, Sendable {
    public enum Source: Equatable, Sendable { case quickBlock, schedule, combined }
    public var domains: [String]
    public var session: SyncedImmediateSession
    public var source: Source
}

public enum AdultWebsitePreset {
    /// A conservative Mac-side seed list. iPhone/iPad use Apple's broader,
    /// continuously updated automatic adult-content filter instead.
    public static let domains: [String] = [
        "pornhub.com", "xvideos.com", "xnxx.com", "xhamster.com", "redtube.com",
        "youporn.com", "tube8.com", "spankbang.com", "beeg.com", "tnaflix.com",
        "hqporner.com", "eporner.com", "pornhd.com", "drtuber.com", "nuvid.com",
        "porntrex.com", "porn.com", "thumbzilla.com", "porndoe.com", "fapvid.com",
        "brazzers.com", "naughtyamerica.com", "realitykings.com", "bangbros.com", "mofos.com",
        "digitalplayground.com", "teamskeet.com", "vixen.com", "blacked.com", "tushy.com",
        "sexart.com", "evilangel.com", "kink.com", "adulttime.com", "wicked.com",
        "hustler.com", "penthouse.com", "playboy.com", "onlyfans.com", "fansly.com",
        "manyvids.com", "chaturbate.com", "stripchat.com", "cam4.com", "camsoda.com",
        "livejasmin.com", "bongacams.com", "myfreecams.com", "flirt4free.com", "streamate.com",
        "jerkmate.com", "adultfriendfinder.com", "fetlife.com", "literotica.com", "asstr.org",
        "sex.com", "theporndude.com", "pornpics.com", "imagefap.com", "motherless.com",
        "erome.com", "rule34.xxx", "rule34video.com", "gelbooru.com", "hentaihaven.xxx",
        "hanime.tv", "nhentai.net", "hentai2read.com", "hentaifox.com", "hentaigasm.com",
        "fakku.net", "gaymaletube.com", "boyfriendtv.com", "gayboystube.com", "gaytube.com",
        "f95zone.to", "lushstories.com", "sexstories.com", "sexvid.xxx", "javhub.net",
        "javlibrary.com", "jav.guru", "javguru.com", "missav.com", "njav.tv",
        "supjav.com", "javmost.com", "javhd.com", "javdb.com", "adultempire.com",
        "iafd.com", "indexxx.com", "freeones.com", "babepedia.com", "pornmd.com",
        "pornone.com", "porngo.com", "porntube.com", "gotporn.com", "xfantazy.com"
    ]

    public static func expandedDomains(merging customDomains: [String]) -> [String] {
        var seen = Set<String>()
        return (customDomains + domains.flatMap { [$0, "www.\($0)"] }).compactMap { raw in
            let domain = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !domain.isEmpty, seen.insert(domain).inserted else { return nil }
            return domain
        }.sorted()
    }
}

public struct SyncedImmediateSession: Codable, Equatable, Sendable {
    public var start: Date
    public var durationMinutes: Int

    public init(start: Date = Date(), durationMinutes: Int) {
        self.start = start
        self.durationMinutes = max(1, durationMinutes)
    }

    public var end: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
    }

    public func isActive(at date: Date = Date()) -> Bool {
        date >= start && date < end
    }
}

public enum MacCompanionDevice {
    public static var currentDeviceID: String { MacCompanionIdentity.deviceID }
    public static var currentDeviceName: String { MacCompanionIdentity.displayName }

    public static func planTargetsThisDevice(_ plan: SyncedMacBlockPlan) -> Bool {
        plan.targetsDevice(currentDeviceID)
    }
}

public enum CloudBlockPlanStoreError: LocalizedError, Equatable {
    case cloudKitUnavailable
    case iCloudAccountUnavailable
    case malformedRecord

    public var errorDescription: String? {
        switch self {
        case .cloudKitUnavailable:
            return "CloudKit is not available on this device."
        case .iCloudAccountUnavailable:
            return "Please sign into iCloud in System Settings, then reopen AntiScroll Mac Companion."
        case .malformedRecord:
            return "The iCloud block plan could not be read."
        }
    }
}


public final class ICloudDriveBlockPlanStore {
    public static let appContainerPath = "Library/Mobile Documents/iCloud~com~benberther~BlockerApp/Documents/currentMacBlockPlan.json"
    public static let visibleDrivePath = "Library/Mobile Documents/com~apple~CloudDocs/BlockerApp/currentMacBlockPlan.json"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var candidatePlanURLs: [URL] {
        [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(Self.appContainerPath),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(Self.visibleDrivePath)
        ]
    }

    public func loadPlan() throws -> SyncedMacBlockPlan? {
        for url in candidatePlanURLs where fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SyncedMacBlockPlan.self, from: data)
        }
        return nil
    }
}

#if canImport(CloudKit)
public final class CloudBlockPlanStore {
    public static let defaultContainerIdentifier = "iCloud.com.benberther.BlockerApp"

    private let container: CKContainer
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: "currentMacBlockPlan")

    public init(containerIdentifier: String = CloudBlockPlanStore.defaultContainerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }

    public func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    public func loadPlan() async throws -> SyncedMacBlockPlan? {
        let status = try await accountStatus()
        guard status == .available else { throw CloudBlockPlanStoreError.iCloudAccountUnavailable }

        do {
            let record = try await database.record(for: recordID)
            guard let data = record["payload"] as? Data else { throw CloudBlockPlanStoreError.malformedRecord }
            return try JSONDecoder().decode(SyncedMacBlockPlan.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    public func savePlan(_ plan: SyncedMacBlockPlan) async throws {
        let status = try await accountStatus()
        guard status == .available else { throw CloudBlockPlanStoreError.iCloudAccountUnavailable }

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "MacBlockPlan", recordID: recordID)
        }

        record["payload"] = try JSONEncoder().encode(plan) as CKRecordValue
        record["updatedAt"] = plan.updatedAt as CKRecordValue
        try await database.save(record)
    }
}
#else
public final class CloudBlockPlanStore {
    public init(containerIdentifier: String = "") {}
    public func loadPlan() async throws -> SyncedMacBlockPlan? { throw CloudBlockPlanStoreError.cloudKitUnavailable }
    public func savePlan(_ plan: SyncedMacBlockPlan) async throws { throw CloudBlockPlanStoreError.cloudKitUnavailable }
}
#endif
