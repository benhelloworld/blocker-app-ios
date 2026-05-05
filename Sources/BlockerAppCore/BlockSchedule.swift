import Foundation

public struct BlockSchedule: Codable, Equatable, Sendable {
    public let startHour: Int
    public let startMinute: Int
    public let endHour: Int
    public let endMinute: Int

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) throws {
        guard (0...23).contains(startHour), (0...23).contains(endHour) else {
            throw ValidationError.invalidHour
        }
        guard (0...59).contains(startMinute), (0...59).contains(endMinute) else {
            throw ValidationError.invalidMinute
        }
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    public enum ValidationError: Error, Equatable {
        case invalidHour
        case invalidMinute
    }

    public var startTotalMinutes: Int { startHour * 60 + startMinute }
    public var endTotalMinutes: Int { endHour * 60 + endMinute }

    public var crossesMidnight: Bool {
        endTotalMinutes <= startTotalMinutes
    }

    public func contains(hour: Int, minute: Int) -> Bool {
        let current = hour * 60 + minute
        if crossesMidnight {
            return current >= startTotalMinutes || current < endTotalMinutes
        }
        return current >= startTotalMinutes && current < endTotalMinutes
    }
}
