import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct SyncedMacBlockPlan: Codable, Equatable, Sendable {
    var domains: [String]
    var durationMinutes: Int
    var updatedAt: Date
    var activeSession: SyncedMacImmediateSession?
    var targetDeviceIDs: [String]
    var adultWebFilterEnabled: Bool
    var schedules: [SyncedMacSchedule]
    var schemaVersion: Int

    init(domains: [String], durationMinutes: Int = 60, updatedAt: Date = Date(), activeSession: SyncedMacImmediateSession? = nil, targetDeviceIDs: [String] = MacBlockDevicePreset.defaultSelectedDeviceIDs, adultWebFilterEnabled: Bool = false, schedules: [SyncedMacSchedule] = [], schemaVersion: Int = 3) {
        self.domains = MacBlockDomainPreset.sanitized(domains)
        self.durationMinutes = max(1, durationMinutes)
        self.updatedAt = updatedAt
        self.activeSession = activeSession
        self.targetDeviceIDs = MacBlockDevicePreset.sanitizedDeviceIDs(targetDeviceIDs)
        self.adultWebFilterEnabled = adultWebFilterEnabled
        self.schedules = schedules
        self.schemaVersion = max(1, schemaVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case domains, durationMinutes, updatedAt, activeSession, targetDeviceIDs, adultWebFilterEnabled, schedules, schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            domains: try container.decode([String].self, forKey: .domains),
            durationMinutes: try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 60,
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(),
            activeSession: try container.decodeIfPresent(SyncedMacImmediateSession.self, forKey: .activeSession),
            targetDeviceIDs: try container.decodeIfPresent([String].self, forKey: .targetDeviceIDs) ?? [],
            adultWebFilterEnabled: try container.decodeIfPresent(Bool.self, forKey: .adultWebFilterEnabled) ?? false,
            schedules: try container.decodeIfPresent([SyncedMacSchedule].self, forKey: .schedules) ?? [],
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        )
    }
}

struct SyncedMacSchedule: Codable, Equatable, Sendable {
    var domains: [String]
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var selectedWeekdays: [Int]
    var timeZoneIdentifier: String
    var targetDeviceIDs: [String]?

    init(domains: [String], startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, selectedWeekdays: [Int], timeZoneIdentifier: String = TimeZone.current.identifier, targetDeviceIDs: [String]? = nil) {
        self.domains = MacBlockDomainPreset.sanitized(domains)
        self.startHour = min(23, max(0, startHour))
        self.startMinute = min(59, max(0, startMinute))
        self.endHour = min(23, max(0, endHour))
        self.endMinute = min(59, max(0, endMinute))
        self.selectedWeekdays = Array(Set(selectedWeekdays.filter { (1...7).contains($0) })).sorted()
        self.timeZoneIdentifier = TimeZone(identifier: timeZoneIdentifier)?.identifier ?? TimeZone.current.identifier
        self.targetDeviceIDs = targetDeviceIDs.map(MacBlockDevicePreset.sanitizedDeviceIDs)
    }
}

struct SyncedMacImmediateSession: Codable, Equatable, Sendable {
    var start: Date
    var durationMinutes: Int

    init(start: Date = Date(), durationMinutes: Int) {
        self.start = start
        self.durationMinutes = max(1, durationMinutes)
    }

    var end: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
    }

    func isActive(at date: Date = Date()) -> Bool {
        date >= start && date < end
    }
}

struct MacBlockDeviceOption: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var subtitle: String
    var systemImage: String

    init(id: String, name: String, subtitle: String, systemImage: String = "desktopcomputer") {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

enum MacBlockDevicePreset {
    private static let fallbackDeviceID = "this-ios-device"

    static var currentDeviceID: String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? fallbackDeviceID
        #else
        return fallbackDeviceID
        #endif
    }

    static var availableDevices: [MacBlockDeviceOption] {
        [
            MacBlockDeviceOption(
                id: currentDeviceID,
                name: L10n.string("This iPhone"),
                subtitle: L10n.string("Use Screen Time protection on this device"),
                systemImage: "iphone"
            )
        ]
    }

    static let defaultSelectedDeviceIDs: [String] = []

    /// Accepts any well-formed device ID (registry IDs like "ben-macbook-air"
    /// are valid even before the CloudKit device list has loaded).
    nonisolated static func sanitizedDeviceIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.compactMap { raw in
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !id.isEmpty, id.count <= 100, !seen.contains(id) else { return nil }
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-._")
            guard id.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
            seen.insert(id)
            return id
        }.sorted()
    }
}

enum MacBlockDomainPreset {
    static let starterDomains = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
        "facebook.com", "www.facebook.com",
        "instagram.com", "www.instagram.com",
        "x.com", "twitter.com", "www.twitter.com",
        "reddit.com", "www.reddit.com",
        "tiktok.com", "www.tiktok.com"
    ]

    static func sanitized(_ domains: [String]) -> [String] {
        var seen = Set<String>()
        return domains.compactMap { raw in
            let domain = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .split(separator: "/")
                .first
                .map(String.init) ?? ""
            guard isValid(domain), !seen.contains(domain) else { return nil }
            seen.insert(domain)
            return domain
        }.sorted()
    }

    static func isValid(_ domain: String) -> Bool {
        guard domain.count <= 253, domain.contains("."), !domain.contains(" ") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard domain.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return domain.split(separator: ".").allSatisfy { label in
            !label.isEmpty && label.count <= 63 && !label.hasPrefix("-") && !label.hasSuffix("-")
        }
    }
}
