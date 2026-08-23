//
//  BlockerAppUITests.swift
//  BlockerAppUITests
//
//  Created by Ben Berther on 08.05.2026.
//

import XCTest

final class BlockerAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testDebugRunStartsWithPremiumUnlocked() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let premiumBadge = app.descendants(matching: .any)["premium-status-badge"]
        XCTAssertTrue(premiumBadge.waitForExistence(timeout: 8), "Debug local runs should start with Premium unlocked, not show the free/paywall state.")
    }

    @MainActor
    func testScheduleTabIsUnlockedInDebugRun() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-testing-skip-onboarding"]
        app.launch()

        app.tabBars.buttons["Schedule"].tap()

        XCTAssertFalse(app.buttons["premium-subscribe-button"].waitForExistence(timeout: 2), "Schedule tab should not show the Premium paywall in Debug local runs.")
        XCTAssertTrue(app.staticTexts["Daily Schedule"].waitForExistence(timeout: 3), "Schedule tab should show the schedule editor, not a premium lock screen.")
    }


    @MainActor
    func testScheduleEditorOffersProtectedDeviceSelection() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-testing-skip-onboarding"]
        app.launch()

        app.tabBars.buttons["Schedule"].tap()
        let createButton = app.buttons["Create Schedule"]
        let editButton = app.buttons["Edit Schedule"]
        if createButton.waitForExistence(timeout: 3) {
            createButton.tap()
        } else {
            XCTAssertTrue(editButton.waitForExistence(timeout: 3))
            editButton.tap()
        }

        let protectedSection = app.descendants(matching: .any)["schedule-protected-devices-section"]
        let protectedTitle = app.staticTexts["Protected devices"]
        for _ in 0..<6 where !protectedTitle.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(protectedSection.waitForExistence(timeout: 5), "Schedule setup should include per-schedule protected-device selection.")
        XCTAssertTrue(protectedTitle.isHittable)
        XCTAssertTrue(app.staticTexts["This iPhone"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "schedule-protected-devices"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testShortcutSetupInstructionsButtonOpensFullGuide() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-testing-skip-onboarding"]
        app.launch()

        app.tabBars.buttons["Modes"].tap()

        let setupButton = app.descendants(matching: .any)["shortcut-setup-instructions-button"]
        if !setupButton.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5), "Modes should show a compact Setup instructions button instead of the full Shortcuts instruction card.")
        setupButton.tap()

        XCTAssertTrue(app.staticTexts["Shortcut pause setup"].waitForExistence(timeout: 5), "Tapping the setup instructions button should open the full Shortcuts setup guide.")
        XCTAssertTrue(app.staticTexts["Create a new app automation"].exists)
        XCTAssertTrue(app.staticTexts["Add Blocker Pause"].exists)
    }

    @MainActor
    func testDeviceSyncShowsMacConnectionGuide() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-testing-skip-onboarding"]
        app.launch()

        let settingsButton = app.buttons["settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 8), "Home should expose Settings.")
        settingsButton.tap()

        let deviceSyncButton = app.buttons["device-sync-settings-button"]
        if !deviceSyncButton.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(deviceSyncButton.waitForExistence(timeout: 5), "Settings should expose Device Sync.")
        deviceSyncButton.tap()

        let guideButton = app.buttons["mac-connection-guide-button"]
        if !guideButton.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(guideButton.waitForExistence(timeout: 5), "Device Sync should include compact Mac connection instructions.")

        let rowScreenshot = XCTAttachment(screenshot: app.screenshot())
        rowScreenshot.name = "device-sync-with-mac-guide-row"
        rowScreenshot.lifetime = .keepAlways
        add(rowScreenshot)

        guideButton.tap()

        XCTAssertTrue(app.staticTexts["Mac connection guide"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open the Mac Companion"].exists)
        XCTAssertTrue(app.staticTexts["Select your Mac here"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "device-sync-mac-connection-guide"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testDeviceSyncMacGuideGermanLayout() throws {
        captureLocalizedMacConnectionGuide(language: "de", locale: "de_DE", expectedTitle: "Anleitung zur Mac-Verbindung")
    }

    @MainActor
    func testDeviceSyncMacGuideSpanishLayout() throws {
        captureLocalizedMacConnectionGuide(language: "es", locale: "es_ES", expectedTitle: "Guía de conexión del Mac")
    }

    @MainActor
    private func captureLocalizedMacConnectionGuide(language: String, locale: String, expectedTitle: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "--ui-testing-skip-onboarding"]
        app.launch()

        let settingsButton = app.buttons["settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 8))
        settingsButton.tap()

        let deviceSyncButton = app.buttons["device-sync-settings-button"]
        if !deviceSyncButton.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(deviceSyncButton.waitForExistence(timeout: 5))
        deviceSyncButton.tap()

        let guideButton = app.buttons["mac-connection-guide-button"]
        if !guideButton.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(guideButton.waitForExistence(timeout: 5))
        guideButton.tap()

        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "device-sync-mac-guide-\(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testAdultFilterLivesInsideBlockedContentSelection() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-testing-skip-onboarding", "--ui-testing-reset-free"]
        app.launch()

        let adultToggle = app.switches["adult-web-filter-toggle"]
        XCTAssertFalse(adultToggle.exists, "The adult website filter should not be a separate Quick Block control.")

        let selectionButton = app.buttons["blocked-content-selection-button"]
        XCTAssertTrue(selectionButton.waitForExistence(timeout: 8), "Quick Block should provide one entry point for choosing blocked content.")
        selectionButton.tap()
        XCTAssertTrue(adultToggle.waitForExistence(timeout: 5), "The adult website filter should live with the app and website selection controls.")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "adult-filter-inside-blocked-content-selection"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
