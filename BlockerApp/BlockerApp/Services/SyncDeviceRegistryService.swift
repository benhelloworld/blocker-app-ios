import CloudKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A device registered by the user's AntiScroll app on iPhone/iPad/Mac.
/// Stored in the user's private CloudKit database — never visible to other users.
struct SyncDevice: Identifiable, Codable, Equatable {
    var id: String          // stable device identifier
    var deviceType: String  // "iphone" | "ipad" | "mac"
    var displayName: String // generic localized name
    var lastSeen: Date

    var systemImage: String {
        switch deviceType {
        case "mac": return "desktopcomputer"
        case "ipad": return "ipad"
        default: return "iphone"
        }
    }
}

enum SyncDeviceRegistryService {
    static let containerIdentifier = "iCloud.com.benberther.BlockerApp"
    private static let recordType = "SyncDevice"

    // MARK: - This device

    static var currentDeviceID: String {
        #if canImport(UIKit)
        if let vendor = UIDevice.current.identifierForVendor?.uuidString {
            return vendor
        }
        #endif
        return "this-ios-device"
    }

    static var currentDeviceType: String {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #else
        return "ios"
        #endif
    }

    static var currentDisplayName: String {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
            ? L10n.string("This iPad")
            : L10n.string("This iPhone")
        #else
        return L10n.string("This Device")
        #endif
    }

    // MARK: - CloudKit

    private static func database() throws -> CKDatabase {
        #if targetEnvironment(simulator)
        throw CKError(.notAuthenticated)
        #else
        return CKContainer(identifier: containerIdentifier).privateCloudDatabase
        #endif
    }

    /// Register (or refresh) this device so it appears in the user's device list.
    static func upsertCurrentDevice() async throws {
        let db = try database()
        let recordID = CKRecord.ID(recordName: currentDeviceID)
        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }
        record["deviceType"] = currentDeviceType as CKRecordValue
        record["displayName"] = currentDisplayName as CKRecordValue
        record["lastSeen"] = Date() as CKRecordValue
        try await db.save(record)
    }

    /// All devices registered by this user (private DB = only this user's devices).
    static func fetchDevices() async throws -> [SyncDevice] {
        var devices = try await cloudKitDevices()

        // File fallback: devices registered by companions without CloudKit
        // entitlements (e.g. the adhoc-signed Mac build) write JSON into the
        // shared iCloud container Documents/devices folder.
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            let devicesDir = containerURL.appendingPathComponent("Documents/devices", isDirectory: true)
            if let files = try? FileManager.default.contentsOfDirectory(at: devicesDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf: file),
                       let record = try? JSONDecoder().decode(SyncDevice.self, from: data) {
                        devices.append(record)
                    }
                }
            }
        }

        var seen = Set<String>()
        let unique = devices.filter { seen.insert($0.id).inserted }
        return unique.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func cloudKitDevices() async throws -> [SyncDevice] {
        let db = try database()
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
        let (matchResults, _) = try await db.records(matching: query, resultsLimit: 50)
        var devices: [SyncDevice] = []
        for (_, result) in matchResults {
            guard let record = try? result.get() else { continue }
            guard let deviceID = record.recordID.recordName as String? else { continue }
            let type = (record["deviceType"] as? String) ?? "ios"
            let name = (record["displayName"] as? String) ?? L10n.string("This Device")
            let lastSeen = (record["lastSeen"] as? Date) ?? Date.distantPast
            devices.append(SyncDevice(id: deviceID, deviceType: type, displayName: name, lastSeen: lastSeen))
        }
        return devices
    }
}
