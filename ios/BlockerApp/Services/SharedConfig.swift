import Foundation

enum SharedConfig {
    static let appGroupIdentifier = "group.com.benberther.BlockerApp"
    static let scheduleKey = "blockSchedule"
    static let shieldSelectionKey = "shieldSelection"
    static let activeImmediateSessionKey = "activeImmediateSession"
    static let activityName = "daily-block"
    static let immediateActivityName = "immediate-block"

    static func dailyActivityName(for weekday: Int) -> String {
        "\(activityName)-weekday-\(weekday)"
    }

    static var allDailyActivityNames: [String] {
        Array(1...7).map { dailyActivityName(for: $0) } + [activityName]
    }
}
