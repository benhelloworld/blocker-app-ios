//
//  ScreenshotCaptureUITests.swift
//  BlockerAppUITests
//
//  Captures the two marketing screenshots:
//  1. FrictionUnlockView — the 30-second pause when trying to end a block
//  2. ShortcutInterventionView — the 15-second anti-impulse pause
//  PNGs are written to the app's tmp dir for extraction via simctl.
//

import XCTest

final class ScreenshotCaptureUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-testing-skip-onboarding"]
        app.launch()
        // Grant Screen Time authorization if the system dialog appears.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 4) {
            allowButton.tap()
        }
        return app
    }

    private func save(_ screenshot: XCUIScreenshot, name: String) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("shots", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: url)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCaptureFrictionUnlock30Seconds() throws {
        let app = launchApp()

        // Start a Quick Block.
        let startButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Start ' AND label CONTAINS 'focus'")
        ).firstMatch
        if !startButton.waitForExistence(timeout: 6) {
            app.swipeUp()
        }
        XCTAssertTrue(startButton.waitForExistence(timeout: 8), "Quick Block start button should appear")
        startButton.tap()

        // Wait for the active session, then open the friction unlock.
        let stopButton = app.buttons["Stop with friction unlock"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 12), "Active session should show the stop button")
        stopButton.tap()

        // Let the 30s breathing countdown reach a mid number (~26s left).
        let heading = app.staticTexts["Pause first"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        sleep(4)

        try save(XCUIScreen.main.screenshot(), name: "anti-scroll-pause-30s")
    }

    @MainActor
    func testCaptureAntiImpulse15Seconds() throws {
        // The pending shortcut trigger is seeded by the host before launch
        // (see screenshot-prep script). The overlay appears on launch.
        let app = launchApp()

        let heading = app.staticTexts["Do you really want to open the app?"]
        XCTAssertTrue(heading.waitForExistence(timeout: 8), "15s anti-impulse overlay should appear")
        sleep(2) // ~13s left

        try save(XCUIScreen.main.screenshot(), name: "anti-scroll-anti-impulse-15s")
    }
}
