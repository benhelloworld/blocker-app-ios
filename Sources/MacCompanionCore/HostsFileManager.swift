import Foundation

public struct MacBlockDomain: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { domain }
    public let domain: String

    public init(_ domain: String) {
        self.domain = domain
    }

    public static let starterSet: [MacBlockDomain] = [
        MacBlockDomain("youtube.com"),
        MacBlockDomain("www.youtube.com"),
        MacBlockDomain("m.youtube.com"),
        MacBlockDomain("youtu.be"),
        MacBlockDomain("facebook.com"),
        MacBlockDomain("www.facebook.com"),
        MacBlockDomain("instagram.com"),
        MacBlockDomain("www.instagram.com"),
        MacBlockDomain("x.com"),
        MacBlockDomain("twitter.com"),
        MacBlockDomain("www.twitter.com"),
        MacBlockDomain("reddit.com"),
        MacBlockDomain("www.reddit.com"),
        MacBlockDomain("tiktok.com"),
        MacBlockDomain("www.tiktok.com")
    ]
}

public enum HostsFileManagerError: LocalizedError, Equatable {
    case emptyDomainList
    case invalidDomain(String)
    case scriptFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyDomainList:
            return "Choose at least one website to block."
        case .invalidDomain(let domain):
            return "Invalid domain: \(domain)"
        case .scriptFailed(let message):
            return message
        }
    }
}

public struct HostsFileManager: Sendable {
    public static let startMarker = "# BEGIN BLOCKER APP MAC COMPANION"
    public static let endMarker = "# END BLOCKER APP MAC COMPANION"

    public init() {}

    public func sanitizedDomains(_ domains: [String]) throws -> [String] {
        var seen = Set<String>()
        let cleaned = try domains.compactMap { raw -> String? in
            let domain = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .split(separator: "/")
                .first
                .map(String.init) ?? ""

            guard !domain.isEmpty else { return nil }
            guard Self.isValidDomain(domain) else { throw HostsFileManagerError.invalidDomain(raw) }
            guard !seen.contains(domain) else { return nil }
            seen.insert(domain)
            return domain
        }

        guard !cleaned.isEmpty else { throw HostsFileManagerError.emptyDomainList }
        return cleaned.sorted()
    }

    public func updatedHosts(existingHosts: String, domains: [String]) throws -> String {
        let domains = try sanitizedDomains(domains)
        let managedBlock = Self.managedBlock(for: domains)
        let removed = Self.removingManagedBlock(from: existingHosts)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return removed + "\n\n" + managedBlock + "\n"
    }

    public func clearedHosts(existingHosts: String) -> String {
        let removed = Self.removingManagedBlock(from: existingHosts)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return removed + "\n"
    }

    public static func managedBlock(for domains: [String]) -> String {
        let lines = domains.flatMap { domain in
            ["0.0.0.0 \(domain)", "::1 \(domain)"]
        }
        return ([startMarker, "# Managed by Blocker Mac Companion. Remove from the app, not manually."] + lines + [endMarker]).joined(separator: "\n")
    }

    public static func removingManagedBlock(from hosts: String) -> String {
        var lines = hosts.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(of: startMarker),
              let end = lines[start...].firstIndex(of: endMarker) else {
            return hosts
        }
        lines.removeSubrange(start...end)
        return lines.joined(separator: "\n")
    }

    public static func managedDomains(in hosts: String) -> [String] {
        let lines = hosts.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(of: startMarker),
              let end = lines[start...].firstIndex(of: endMarker),
              start < end else { return [] }

        var seen = Set<String>()
        return lines[(start + 1)..<end].compactMap { line in
            let parts = line.split(separator: " ").map(String.init)
            guard parts.count == 2, parts[0] == "0.0.0.0", !seen.contains(parts[1]) else { return nil }
            seen.insert(parts[1])
            return parts[1]
        }.sorted()
    }

    public static func isValidDomain(_ domain: String) -> Bool {
        guard domain.count <= 253, domain.contains("."), !domain.contains(" ") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard domain.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return domain.split(separator: ".").allSatisfy { label in
            !label.isEmpty && label.count <= 63 && !label.hasPrefix("-") && !label.hasSuffix("-")
        }
    }
}
