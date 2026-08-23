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
    }

    guard arguments.contains("--ui-testing-reset-free") else { return }
    defaults?.set(true, forKey: "hasCompletedFirstLaunchOnboarding")
    defaults?.set(false, forKey: SharedConfig.premiumStatusKey)
    defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
}
