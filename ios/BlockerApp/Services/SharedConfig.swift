import Foundation

enum SharedConfig {
    static let appGroupIdentifier = "group.com.benberther.BlockerApp"
    static let scheduleKey = "blockSchedule"
    static let shieldSelectionKey = "shieldSelection"
    static let delaySelectionKey = "delaySelection"
    static let delayAppsEnabledKey = "delayAppsEnabled"
    static let activeImmediateSessionKey = "activeImmediateSession"
    static let focusStatsKey = "focusStats"
    static let frictionUnlockHistoryKey = "frictionUnlockHistory"
    static let lastAccountabilityReceiptKey = "lastAccountabilityReceipt"
    static let activityName = "daily-block"
    static let immediateActivityName = "immediate-block"

    static func dailyActivityName(for weekday: Int) -> String {
        "\(activityName)-weekday-\(weekday)"
    }

    static var allDailyActivityNames: [String] {
        Array(1...7).map { dailyActivityName(for: $0) } + [activityName]
    }
}
