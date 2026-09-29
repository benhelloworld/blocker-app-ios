import Foundation
#if canImport(AppIntents)
import AppIntents

struct ShouldShowBlockerPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Should show Blocker pause"
    static var description = IntentDescription("Returns false once after AntiScroll opens a delayed app, so the Shortcuts automation does not immediately trigger the pause again.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let shouldShowPause = !(await ShortcutInterventionStore.shared.consumeNextAutomationPassIfActive())
        return .result(value: shouldShowPause)
    }
}

struct ActivateBlockerPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Blocker pause"
    static var description = IntentDescription("Shows a short intentional pause when a Shortcuts automation runs after opening a distracting app.")
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "Return URL",
        description: "Optional app URL to open when the pause finishes, for example youtube:// or instagram://. Leave empty if the app has no known URL scheme."
    )
    var returnURL: URL?

    func perform() async throws -> some IntentResult {
        await ShortcutInterventionStore.shared.recordTrigger(returnURL: returnURL)
        return .result()
    }
}

struct BlockerShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShouldShowBlockerPauseIntent(),
            phrases: [
                "Check \(.applicationName) pause",
                "Should show \(.applicationName) pause"
            ],
            shortTitle: "Should Pause?",
            systemImageName: "checkmark.shield.fill"
        )

        AppShortcut(
            intent: ActivateBlockerPauseIntent(),
            phrases: [
                "Pause with \(.applicationName)",
                "Start \(.applicationName) pause",
                "Open \(.applicationName) intervention"
            ],
            shortTitle: "Blocker Pause",
            systemImageName: "hourglass.circle.fill"
        )
    }
}
#endif
