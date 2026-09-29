import Foundation

enum SharedConfig {
    static let appGroupIdentifier = "group.com.benberther.BlockerApp"
    static let scheduleKey = "blockSchedule"
    static let scheduleEnabledKey = "blockScheduleEnabled"
    static let blocklistsKey = "namedBlocklists"
    static let scheduledShieldSelectionKey = "scheduledShieldSelection"
    static let activeHardShieldSelectionKey = "activeHardShieldSelection"
    static let shieldSelectionKey = "shieldSelection"
    static let delaySelectionKey = "delaySelection"
    static let delayAppsEnabledKey = "delayAppsEnabled"
    static let delayWaitStartedAtKey = "delayAppsWaitStartedAt"
    static let adultWebFilterEnabledKey = "adultWebFilterEnabled"
    static let automaticWebDomainsKey = "automaticWebDomains"
    static let activeImmediateSessionKey = "activeImmediateSession"
    static let focusCompletionPromptKey = "focusCompletionPrompt"
    static let focusStatsKey = "focusStats"
    static let scheduledFocusStatsKey = "scheduledFocusStats"
    static let scheduledFocusStartsKey = "scheduledFocusStarts"
    static let scheduledFocusDurationsKey = "scheduledFocusDurations"
    static let frictionUnlockHistoryKey = "frictionUnlockHistory"
    static let escapeTokenLedgerKey = "escapeTokenLedger"
    static let lastAccountabilityReceiptKey = "lastAccountabilityReceipt"
    static let premiumStatusKey = "isPremiumUser"
    static let activityName = "daily-block"
    static let immediateActivityName = "immediate-block"
    static let immediateStoreName = "immediate-block"
    static let scheduledStoreName = "scheduled-blocks"
    static let registeredScheduleActivityNamesKey = "registeredScheduleActivityNames"
    static let activeScheduleActivityNamesKey = "activeScheduleActivityNames"
    static let activeImmediateShieldSelectionKey = "activeImmediateShieldSelection"
    static let activeScheduledShieldSelectionKey = "activeScheduledShieldSelection"
    static let activeFocusTemplateKey = "activeFocusTemplate"

    static func dailyActivityName(for weekday: Int) -> String {
        "\(activityName)-weekday-\(weekday)"
    }

    static func dailyActivityName(for weekday: Int, periodID: UUID) -> String {
        "\(activityName)-w\(weekday)-\(periodID.uuidString.lowercased())"
    }

    static var legacyDailyActivityNames: [String] {
        Array(1...7).map { dailyActivityName(for: $0) } + [activityName]
    }
}
