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
    func testWeeklyFocusShowsSevenAccessibleDaysAndCombinedActivity() throws {
        let app = weeklyFocusApp(language: "en", locale: "en_US")
        app.launch()

        XCTAssertTrue(app.staticTexts["Last 7 days"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["3 of 7 days with focus"].exists)
        // Fixture: Quick Blocks four and two days ago, scheduled focus two days ago and today.
        let expectedDays = [
            (4, "Focus recorded", false),
            (3, "No focus recorded", false),
            (2, "Focus recorded", false),
            (1, "No focus recorded", false),
            (0, "Focus recorded", true)
        ]
        for index in 0..<7 {
            let day = app.otherElements["weekly-focus-day-\(index)"]
            XCTAssertTrue(day.exists, "Each day needs a single, accessible summary.")
            XCTAssertFalse(day.label.isEmpty)
            guard let (daysAgo, status, isToday) = expectedDays.first(where: { $0.0 == 6 - index }) else {
                XCTAssertTrue(day.label.contains("No focus recorded"), "Day \(index) should report no recorded focus.")
                continue
            }
            XCTAssertTrue(day.label.contains(status), "Day \(index) should report '\(status)' but said '\(day.label)'.")
            XCTAssertEqual(day.label.contains("Today"), isToday, "Only today should be announced as today.")
            let expectedDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: Date()))!
            // Pinned to the app's en-US launch environment so the spoken date is deterministic.
            let expectedSpokenDate = expectedDate.formatted(
                Date.FormatStyle(date: .complete, time: .omitted, locale: Locale(identifier: "en_US"))
            )
            XCTAssertTrue(day.label.contains(expectedSpokenDate), "Day \(index) should announce its real date but said '\(day.label)'.")
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "weekly-focus-en"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testWeeklyFocusHandlesAnInactiveWeekWithoutInventingActivity() throws {
        let app = weeklyFocusApp(language: "en", locale: "en_US", inactive: true)
        app.launch()
        XCTAssertTrue(app.staticTexts["0 of 7 days with focus"].waitForExistence(timeout: 8))
        for index in 0..<7 {
            XCTAssertTrue(app.otherElements["weekly-focus-day-\(index)"].label.contains("No focus recorded"))
        }
    }

    @MainActor
    func testWeeklyFocusSupportsLongCopyDynamicTypeAndRTL() throws {
        for (language, locale, title) in [
            ("de", "de_DE", "Letzte 7 Tage"),
            ("es", "es_ES", "Últimos 7 días"),
            ("ar", "ar_SA", "آخر 7 أيام")
        ] {
            let app = weeklyFocusApp(language: language, locale: locale)
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            let titleElement = app.staticTexts[title]
            XCTAssertTrue(titleElement.waitForExistence(timeout: 8))
            for _ in 0..<8 where !titleElement.isHittable { app.swipeUp() }
            XCTAssertTrue(titleElement.isHittable)
            for index in 0..<7 {
                let day = app.otherElements["weekly-focus-day-\(index)"]
                for _ in 0..<8 where !day.isHittable { app.swipeUp() }
                XCTAssertTrue(day.isHittable, "Large text must leave all seven days reachable.")
            }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "weekly-focus-\(language)-accessibility"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    private func weeklyFocusApp(language: String, locale: String, inactive: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
            "--ui-testing-skip-onboarding", "--ui-testing-tab-progress",
            inactive ? "--ui-testing-focus-week-inactive" : "--ui-testing-focus-week"
        ]
        return app
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
    func testFocusCompleteOffersDoneContinueAndProgressWithoutClutter() throws {
        let app = focusCompleteApp(language: "en", locale: "en_US")
        app.launch()

        let screen = app.descendants(matching: .any)["focus-complete-screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Focus complete"].exists)
        XCTAssertTrue(app.buttons["keep-going-15-minutes-button"].exists)
        XCTAssertTrue(app.buttons["view-focus-progress-button"].exists)
        XCTAssertTrue(app.buttons["dismiss-focus-complete-button"].exists)
        XCTAssertFalse(app.buttons["start-focus-button"].exists, "The simple completion state should replace the normal Home controls while it is available.")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "focus-complete"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["keep-going-15-minutes-button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["quick-block-countdown-overlay"].waitForExistence(timeout: 3))
        XCTAssertFalse(screen.exists)
    }

    @MainActor
    func testFocusCompleteDoneReturnsToHome() throws {
        let app = focusCompleteApp(language: "en", locale: "en_US")
        app.launch()

        XCTAssertTrue(app.buttons["dismiss-focus-complete-button"].waitForExistence(timeout: 8))
        app.buttons["dismiss-focus-complete-button"].tap()

        XCTAssertTrue(app.buttons["start-focus-button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["focus-complete-screen"].exists)
    }

    @MainActor
    func testCancellingKeepGoingCountdownRestoresFocusComplete() throws {
        let app = focusCompleteApp(language: "en", locale: "en_US")
        app.launch()

        XCTAssertTrue(app.buttons["keep-going-15-minutes-button"].waitForExistence(timeout: 8))
        app.buttons["keep-going-15-minutes-button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["quick-block-countdown-overlay"].waitForExistence(timeout: 3))

        app.buttons["cancel-quick-block-countdown-button"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["focus-complete-screen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["keep-going-15-minutes-button"].isHittable)
    }

    @MainActor
    func testFocusCompleteViewProgressOpensProgressTab() throws {
        let app = focusCompleteApp(language: "en", locale: "en_US")
        app.launch()

        XCTAssertTrue(app.buttons["view-focus-progress-button"].waitForExistence(timeout: 8))
        app.buttons["view-focus-progress-button"].tap()

        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["focus-complete-screen"].exists)
    }

    @MainActor
    func testFocusCompleteFitsLongGermanAndSpanishCopy() throws {
        for (language, locale, title) in [
            ("de", "de_DE", "Fokus abgeschlossen"),
            ("es", "es_ES", "Sesión de concentración completada")
        ] {
            let app = focusCompleteApp(language: language, locale: locale)
            app.launch()

            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["keep-going-15-minutes-button"].isHittable)
            XCTAssertTrue(app.buttons["view-focus-progress-button"].isHittable)
            XCTAssertTrue(app.buttons["dismiss-focus-complete-button"].isHittable)
            app.terminate()
        }
    }

    private func focusCompleteApp(language: String, locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
            "--ui-testing-skip-onboarding", "--ui-testing-show-focus-complete"
        ]
        return app
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
