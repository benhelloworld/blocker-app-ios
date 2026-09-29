import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

public struct DeviceRegistryRecord: Codable {
    public var id: String
    public var deviceType: String
    public var displayName: String
    public var lastSeen: Date
}

/// Stable, per-Mac identity shared by device registration and plan targeting.
/// Existing development installs keep the legacy ID so they remain selected;
/// new installs receive a generated ID that is persisted in UserDefaults.
public enum MacCompanionIdentity {
    private static let defaultsKey = "AntiScrollMacCompanion.deviceID"
    private static let legacyDeviceID = "ben-macbook-air"

    public static var deviceID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: defaultsKey), isValid(existing) {
            return existing
        }

        if legacyRegistryFileExists {
            defaults.set(legacyDeviceID, forKey: defaultsKey)
            return legacyDeviceID
        }

        let generated = "mac-\(UUID().uuidString.lowercased())"
        defaults.set(generated, forKey: defaultsKey)
        return generated
    }

    public static var displayName: String {
        let localizedName = Host.current().localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return localizedName?.isEmpty == false ? localizedName! : "This Mac"
    }

    private static var legacyRegistryFileExists: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let legacyURL = home.appendingPathComponent(
            "Library/Mobile Documents/iCloud~com~benberther~BlockerApp/Documents/devices/\(legacyDeviceID).json"
        )
        return FileManager.default.fileExists(atPath: legacyURL.path)
    }

    private static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 100 else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || "-._".unicodeScalars.contains($0)
        }
    }
}

/// Registers this Mac in the user's device registry so the iPhone app can show
/// it in the device list with a sync toggle.
///
/// Two paths are used:
/// 1. iCloud Drive file (works in the adhoc-signed Desktop build — no CloudKit
///    entitlement needed to write into the user's own Mobile Documents folder).
/// 2. CloudKit private database (used when the app is signed with the iCloud
///    container entitlement).
public enum DeviceRegistry {
    public static var deviceID: String { MacCompanionIdentity.deviceID }
    public static let deviceType = "mac"
    public static var displayName: String { MacCompanionIdentity.displayName }

    /// iCloud app container path — synced to the iPhone via iCloud Drive.
    public static var fileURL: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(
            "Library/Mobile Documents/iCloud~com~benberther~BlockerApp/Documents/devices",
            isDirectory: true
        )
        return dir.appendingPathComponent("\(deviceID).json")
    }

    public static func upsertCurrentDevice() async {
        let record = DeviceRegistryRecord(
            id: deviceID,
            deviceType: deviceType,
            displayName: displayName,
            lastSeen: Date()
        )

        if let url = fileURL {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let data = try JSONEncoder().encode(record)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("DeviceRegistry file upsert failed: %@", error.localizedDescription)
            }
        }

        #if canImport(CloudKit)
        guard MacCompanionEntitlements.hasICloudContainer else { return }
        do {
            let container = CKContainer(identifier: "iCloud.com.benberther.BlockerApp")
            let db = container.privateCloudDatabase
            let recordID = CKRecord.ID(recordName: deviceID)
            let record: CKRecord
            do {
                record = try await db.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: "SyncDevice", recordID: recordID)
            }
            record["deviceType"] = deviceType as CKRecordValue
            record["displayName"] = displayName as CKRecordValue
            record["lastSeen"] = Date() as CKRecordValue
            try await db.save(record)
        } catch {
            NSLog("DeviceRegistry CloudKit upsert failed: %@", error.localizedDescription)
        }
        #endif
    }
}
