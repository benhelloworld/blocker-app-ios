import SwiftUI

@main
struct BlockerApp: App {
    init() {
        configureForUITestingIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}


private func configureForUITestingIfNeeded() {
    let arguments = ProcessInfo.processInfo.arguments
    let defaults = UserDefaults(suiteName: SharedConfig.appGroupIdentifier)

    if arguments.contains("--ui-testing-skip-onboarding") {
        defaults?.set(true, forKey: "hasCompletedFirstLaunchOnboarding")
        defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
        defaults?.removeObject(forKey: SharedConfig.focusCompletionPromptKey)
    }

    if arguments.contains("--ui-testing-show-focus-complete") {
        let session = ImmediateBlockSession(
            start: Date().addingTimeInterval(-31 * 60),
            durationMinutes: 30
        )
        try? ShieldStorage.shared.saveFocusCompletionPrompt(
            FocusCompletionPrompt(session: session, progressRecorded: true)
        )
    }

    #if DEBUG && targetEnvironment(simulator)
    if arguments.contains("--ui-testing-focus-week") || arguments.contains("--ui-testing-focus-week-inactive") {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let inactive = arguments.contains("--ui-testing-focus-week-inactive")
        var quick = FocusStats()
        var scheduled = ScheduledFocusStats()
        // Deterministic simulator-only fixtures; never replace real device history.
        for offset in (inactive ? [-10] : [-4, -2]) {
            if let start = calendar.date(byAdding: .day, value: offset, to: today) {
                quick.record(session: ImmediateBlockSession(start: start, durationMinutes: 30), calendar: calendar)
            }
        }
        if !inactive {
            for offset in [-2, 0] {
                if let start = calendar.date(byAdding: .day, value: offset, to: today) {
                    scheduled.recordProtection(start: start, end: start.addingTimeInterval(30 * 60), calendar: calendar)
                }
            }
        }
        try? ShieldStorage.shared.saveFocusStats(quick)
        try? ShieldStorage.shared.saveScheduledFocusStats(scheduled)
    }
    #endif

    guard arguments.contains("--ui-testing-reset-free") else { return }
    defaults?.set(true, forKey: "hasCompletedFirstLaunchOnboarding")
    defaults?.set(false, forKey: SharedConfig.premiumStatusKey)
    defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
}
