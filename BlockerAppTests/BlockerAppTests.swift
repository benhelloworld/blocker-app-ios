import Foundation
import Testing
#if canImport(FamilyControls)
import FamilyControls
#endif
@testable import BlockerApp

@MainActor
struct BlockerAppTests {


    @Test func onboardingStepsAreAllOnStatusTabAndPointAtFreeFeatures() async throws {
        #expect(FirstLaunchOnboardingStep.all.map(\.tabName) == ["Status", "Status", "Status", "Status"])
        #expect(FirstLaunchOnboardingStep.all.map(\.targetID) == ["Screen Time Access", "Screen Time Access", "App Selection", "Quick Block"])
        #expect(!FirstLaunchOnboardingStep.all.contains { ["Schedule", "Progress", "Modes"].contains($0.tabName) })
    }

    @Test func premiumPaywallUsesFallbackPricesWithoutImmediateUnavailableMessage() async throws {
        let manager = PremiumEntitlementStore(startListeningForTransactions: false, automaticallyRefresh: false)
        #expect(manager.displayPrice(for: .monthly) == L10n.string("€2/month"))
        #expect(manager.displayPrice(for: .yearly) == L10n.string("€20/year"))
        #expect(manager.message == nil)
    }

    @Test func germanOnboardingCopyIsActuallyTranslated() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("BlockerApp/BlockerApp")
        let url = root.appendingPathComponent("de.lproj/Localizable.strings")
        let dictionary = NSDictionary(contentsOf: url) as? [String: String] ?? [:]
        let keys = FirstLaunchOnboardingStep.all.flatMap { [$0.cardTitle, $0.body, $0.buttonTitle] } + ["Skip"]
        for key in keys {
            let value = dictionary[key]
            #expect(value != nil)
            #expect(value?.isEmpty == false)
            #expect(value != key)
        }
    }



    @Test func premiumSubscriptionPlansUseRequestedProductIDsAndValueOrder() async throws {
        #expect(PremiumSubscriptionPlan.monthly.productID == "focusblocker.premium_monthly")
        #expect(PremiumSubscriptionPlan.yearly.productID == "focusblocker.premium.yearly")
        #expect(PremiumSubscriptionPlan.all.map(\.productID) == ["focusblocker.premium_monthly", "focusblocker.premium.yearly"])
        #expect(PremiumSubscriptionPlan.yearly.isBestValue)
        #expect(!PremiumSubscriptionPlan.monthly.isBestValue)
        #expect(PremiumSubscriptionPlan.monthly.fallbackPriceKey == "€2/month")
        #expect(PremiumSubscriptionPlan.yearly.fallbackPriceKey == "€20/year")
    }

    @Test func subscriptionEntitlementPolicyRequiresActiveSubscriptionTransaction() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(PremiumSubscriptionEntitlementPolicy.isActive(productID: "focusblocker.premium_monthly", expirationDate: now.addingTimeInterval(3600), revocationDate: nil, now: now))
        #expect(PremiumSubscriptionEntitlementPolicy.isActive(productID: "focusblocker.premium.yearly", expirationDate: now.addingTimeInterval(3600), revocationDate: nil, now: now))
        #expect(!PremiumSubscriptionEntitlementPolicy.isActive(productID: "focusblocker.premium_monthly", expirationDate: now.addingTimeInterval(-1), revocationDate: nil, now: now))
        #expect(!PremiumSubscriptionEntitlementPolicy.isActive(productID: "focusblocker.premium_monthly", expirationDate: now.addingTimeInterval(3600), revocationDate: now, now: now))
        #expect(!PremiumSubscriptionEntitlementPolicy.isActive(productID: "legacy.fake.premium", expirationDate: now.addingTimeInterval(3600), revocationDate: nil, now: now))
    }

    @Test func subscriptionManagerIgnoresUserDefaultsAsPremiumSourceOfTruth() async throws {
        ShieldStorage.shared.savePremiumStatus(true)
        let managerWithCachedPremium = PremiumEntitlementStore(startListeningForTransactions: false, automaticallyRefresh: false)
        ShieldStorage.shared.savePremiumStatus(false)
        let managerWithoutCachedPremium = PremiumEntitlementStore(startListeningForTransactions: false, automaticallyRefresh: false)

        #expect(managerWithCachedPremium.isPremium == managerWithoutCachedPremium.isPremium)
        #expect(managerWithCachedPremium.activeProductID == managerWithoutCachedPremium.activeProductID)
        #expect(managerWithoutCachedPremium.selectedPlan.productID == PremiumSubscriptionPlan.yearly.productID)
    }

    @Test func delayShieldActionNeverTreatsAnInactiveSavedSelectionAsAHardBlock() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent("BlockerShieldActionExtension/ShieldActionExtension.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("loadSelection(forKey: activeHardShieldSelectionKey)"))
        #expect(!source.contains("shieldSelection"))
        #expect(!source.contains("return normalSelection"))
    }

    @Test func onboardingAndFrictionCopyHaveLocalizationKeys() async throws {
        let requiredKeys = FirstLaunchOnboardingStep.all.flatMap { [$0.cardTitle, $0.body, $0.buttonTitle] } + [
            "Skip",
            "Pause first",
            "Keep block",
            "Take a slow breath before unlocking.",
            "Questions unlock after the breathing timer.",
            "Unlock and stop block"
        ]

        for key in requiredKeys {
            #expect(L10n.string(key).isEmpty == false)
        }
    }



    @Test func supportedLocalizationFilesAreParseableAndContainCoreNavigation() async throws {
        let supportedLocales = ["en", "zh-Hans", "hi", "es", "fr", "ar", "bn", "pt", "ru", "ur", "de"]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("BlockerApp/BlockerApp")
        let coreKeys = ["Status", "Schedule", "Progress", "Modes", "Settings", "Delay"]

        for locale in supportedLocales {
            let url = root.appendingPathComponent("\(locale).lproj/Localizable.strings")
            let dictionary = NSDictionary(contentsOf: url) as? [String: String]
            #expect(dictionary != nil, "\(locale).lproj must contain a valid strings dictionary")
            #expect((dictionary?.count ?? 0) >= 175)
            for key in coreKeys {
                #expect(dictionary?[key]?.isEmpty == false, "Missing core localization key '\(key)' in \(locale).lproj")
            }
        }
    }


    @Test func immediateBlockSessionBuildsScheduleFromStartDateAndDuration() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 14, minute: 30))!

        let session = ImmediateBlockSession(start: start, durationMinutes: 90, calendar: calendar)

        #expect(session.schedule == BlockSchedule(startHour: 14, startMinute: 30, endHour: 16, endMinute: 0))
        #expect(session.durationLabel == "1.5 hours")
    }

    @Test func immediateBlockSessionCanCrossMidnight() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 23, minute: 45))!

        let session = ImmediateBlockSession(start: start, durationMinutes: 45, calendar: calendar)

        #expect(session.schedule == BlockSchedule(startHour: 23, startMinute: 45, endHour: 0, endMinute: 30))
        #expect(session.schedule.crossesMidnight)
    }

    @Test func immediateBlockSessionReportsActiveStateAndRemainingMinutes() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 10, minute: 0))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 120, calendar: calendar)
        let halfway = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 11, minute: 0))!
        let afterEnd = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 12, minute: 1))!

        #expect(session.isActive(at: halfway))
        #expect(session.remainingMinutes(at: halfway) == 60)
        #expect(session.progress(at: halfway) == 0.5)
        #expect(!session.isActive(at: afterEnd))
        #expect(session.remainingMinutes(at: afterEnd) == 0)
    }

    @Test func immediateBlockSessionSupportsOvernightStatusText() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 23, minute: 30))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 90, calendar: calendar)
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 0, minute: 15))!

        #expect(session.isActive(at: now))
        #expect(session.remainingMinutes(at: now) == 45)
        #expect(session.progress(at: now) == 0.5)
    }


    @Test func scheduleDefaultsToAllWeekdaysForExistingDailyBlocks() async throws {
        let schedule = BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        #expect(schedule.selectedWeekdays == Set(1...7))
        #expect(schedule.selectedWeekdaySymbols == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
    }

    @Test func scheduleOnlyContainsSelectedWeekdays() async throws {
        let schedule = BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, selectedWeekdays: [2, 4, 6])

        #expect(schedule.contains(weekday: 2, hour: 10, minute: 0))
        #expect(schedule.contains(weekday: 4, hour: 10, minute: 0))
        #expect(!schedule.contains(weekday: 3, hour: 10, minute: 0))
        #expect(!schedule.contains(weekday: 6, hour: 18, minute: 0))
        #expect(schedule.selectedWeekdaySymbols == ["Mon", "Wed", "Fri"])
    }

    @Test func scheduleSupportsIndependentMultiplePeriodsPerWeekday() throws {
        let mondayMorning = ScheduleTimePeriod(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, startHour: 9, startMinute: 0, endHour: 15, endMinute: 0)
        let mondayEvening = ScheduleTimePeriod(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, startHour: 16, startMinute: 0, endHour: 20, endMinute: 0)
        let tuesdayMorning = ScheduleTimePeriod(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, startHour: 8, startMinute: 30, endHour: 12, endMinute: 0)
        let schedule = BlockSchedule(periodsByWeekday: [
            2: [mondayMorning, mondayEvening],
            3: [tuesdayMorning]
        ])

        #expect(schedule.periods(for: 2) == [mondayMorning, mondayEvening])
        #expect(schedule.periods(for: 3) == [tuesdayMorning])
        #expect(schedule.contains(weekday: 2, hour: 10, minute: 0))
        #expect(!schedule.contains(weekday: 2, hour: 15, minute: 30))
        #expect(schedule.contains(weekday: 2, hour: 17, minute: 0))
        #expect(schedule.contains(weekday: 3, hour: 9, minute: 0))
        #expect(!schedule.contains(weekday: 3, hour: 17, minute: 0))
        #expect(schedule.validationIssue() == nil)
    }

    @Test func overnightPeriodsBelongToTheirStartDayAndRemainActiveAfterMidnight() {
        let overnight = ScheduleTimePeriod(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, startHour: 21, startMinute: 0, endHour: 2, endMinute: 0)
        let schedule = BlockSchedule(periodsByWeekday: [2: [overnight]])

        #expect(schedule.contains(weekday: 2, hour: 22, minute: 0))
        #expect(schedule.contains(weekday: 3, hour: 1, minute: 30))
        #expect(!schedule.contains(weekday: 3, hour: 2, minute: 0))
        #expect(!schedule.contains(weekday: 1, hour: 22, minute: 0))
        #expect(schedule.monitoringDescriptors.first?.startWeekday == 2)
        #expect(schedule.monitoringDescriptors.first?.endWeekday == 3)
    }

    @Test func scheduleRejectsSameDayAndCrossMidnightOverlaps() {
        let first = ScheduleTimePeriod(id: UUID(), startHour: 9, startMinute: 0, endHour: 15, endMinute: 0)
        let overlapping = ScheduleTimePeriod(id: UUID(), startHour: 14, startMinute: 30, endHour: 16, endMinute: 0)
        #expect(BlockSchedule(periodsByWeekday: [2: [first, overlapping]]).validationIssue() == .overlappingPeriods)

        let mondayOvernight = ScheduleTimePeriod(id: UUID(), startHour: 22, startMinute: 0, endHour: 2, endMinute: 0)
        let tuesdayEarly = ScheduleTimePeriod(id: UUID(), startHour: 1, startMinute: 0, endHour: 3, endMinute: 0)
        #expect(BlockSchedule(periodsByWeekday: [2: [mondayOvernight], 3: [tuesdayEarly]]).validationIssue() == .overlappingPeriods)
    }

    @Test func scheduleRejectsZeroLengthPeriodsAndTooManyDeviceActivityMonitors() {
        let zeroLength = ScheduleTimePeriod(id: UUID(), startHour: 9, startMinute: 0, endHour: 9, endMinute: 0)
        #expect(BlockSchedule(periodsByWeekday: [2: [zeroLength]]).validationIssue() == .zeroLengthPeriod)

        var periods: [Int: [ScheduleTimePeriod]] = [:]
        for weekday in 1...7 {
            periods[weekday] = (0..<3).map { index in
                ScheduleTimePeriod(startHour: index * 4, startMinute: 0, endHour: index * 4 + 1, endMinute: 0)
            }
        }
        #expect(BlockSchedule(periodsByWeekday: periods).validationIssue(maximumMonitorCount: 19) == .monitorLimitExceeded(limit: 19))
    }

    @Test func legacySingleIntervalScheduleDecodesIntoEachSelectedWeekday() throws {
        struct LegacySchedule: Encodable {
            let startHour = 9
            let startMinute = 0
            let endHour = 17
            let endMinute = 0
            let selectedWeekdays: Set<Int> = [2, 4]
            let selectedBlocklistID: UUID? = nil
            let protectedDeviceIDs: Set<String>? = nil
        }
        let decoded = try JSONDecoder().decode(BlockSchedule.self, from: JSONEncoder().encode(LegacySchedule()))

        #expect(decoded.periods(for: 2).count == 1)
        #expect(decoded.periods(for: 4).count == 1)
        #expect(decoded.periods(for: 3).isEmpty)
        #expect(decoded.periods(for: 2).first?.startHour == 9)
        #expect(decoded.periods(for: 4).first?.endHour == 17)
    }

    @Test func activeScheduledWindowFindsTheCorrectSecondAndOvernightPeriods() {
        let calendar = Calendar(identifier: .gregorian)
        let secondPeriodNow = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 17, minute: 0))!
        let overnightNow = calendar.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 1, minute: 0))!
        let schedule = BlockSchedule(periodsByWeekday: [
            2: [
                ScheduleTimePeriod(startHour: 9, startMinute: 0, endHour: 15, endMinute: 0),
                ScheduleTimePeriod(startHour: 16, startMinute: 0, endHour: 20, endMinute: 0),
                ScheduleTimePeriod(startHour: 21, startMinute: 0, endHour: 2, endMinute: 0)
            ]
        ])

        #expect(ActiveScheduledBlockWindow.activeWindow(for: schedule, now: secondPeriodNow, calendar: calendar)?.end == calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 20, minute: 0)))
        #expect(ActiveScheduledBlockWindow.activeWindow(for: schedule, now: overnightNow, calendar: calendar)?.start == calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 21, minute: 0)))
    }

    @Test func hardBlockPreflightRequiresAuthorizationAndARealSelection() {
        #expect(HardBlockActivationPreflight.failure(isAuthorized: false, applicationCount: 1, categoryCount: 0, webDomainCount: 0) == .authorizationRequired)
        #expect(HardBlockActivationPreflight.failure(isAuthorized: true, applicationCount: 0, categoryCount: 0, webDomainCount: 0) == .emptySelection)
        #expect(HardBlockActivationPreflight.failure(isAuthorized: true, applicationCount: 1, categoryCount: 2, webDomainCount: 3) == nil)
    }


    @Test func focusStatsRecordsOnlyElapsedProtectedMinutes() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 24, hour: 10, minute: 0))!
        let stopped = calendar.date(from: DateComponents(year: 2026, month: 5, day: 24, hour: 10, minute: 25))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 480, calendar: calendar)

        var stats = FocusStats()
        stats.recordCompleted(session: session, completedAt: stopped, calendar: calendar)

        #expect(stats.totalSessions == 1)
        #expect(stats.totalPlannedMinutes == 25)
        #expect(stats.totalHoursLabel == "0.4h")
    }

    @Test func focusStatsRecordsFullMinutesOnlyWhenTimerFinishes() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 24, hour: 10, minute: 0))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 30, calendar: calendar)

        var stats = FocusStats()
        stats.recordCompleted(session: session, completedAt: session.end, calendar: calendar)

        #expect(stats.totalSessions == 1)
        #expect(stats.totalPlannedMinutes == 30)
    }

    @Test func focusStatsRecordsQuickBlockSessionsAndMinutes() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 14, minute: 30))!
        let session = ImmediateBlockSession(start: start, durationMinutes: 90, calendar: calendar)

        var stats = FocusStats()
        stats.record(session: session, calendar: calendar)

        #expect(stats.totalSessions == 1)
        #expect(stats.totalPlannedMinutes == 90)
        #expect(stats.totalHoursLabel == "1.5h")
        #expect(stats.focusDayCount == 1)
    }

    @Test func focusStatsCalculatesCurrentStreakAcrossConsecutiveDays() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 9, minute: 0))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 19, hour: 9, minute: 0))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 9, minute: 0))!

        var stats = FocusStats()
        stats.record(session: ImmediateBlockSession(start: monday, durationMinutes: 30, calendar: calendar), calendar: calendar)
        stats.record(session: ImmediateBlockSession(start: tuesday, durationMinutes: 30, calendar: calendar), calendar: calendar)

        #expect(stats.currentStreakDays(asOf: tuesday, calendar: calendar) == 2)
        #expect(stats.currentStreakDays(asOf: wednesday, calendar: calendar) == 0)
    }



    @Test func frictionUnlockReasonsMatchTheReflectionOptions() async throws {
        #expect(FrictionUnlockReason.allOptions.map(\.title) == ["Bored", "Stressed", "Tired", "Habit", "Need something important", "Other"])
    }

    @Test func frictionUnlockReflectionRequiresABlockReasonAndStopReason() async throws {
        #expect(!FrictionUnlockReflection(blockReason: "", stopReason: .bored).isComplete)
        #expect(!FrictionUnlockReflection(blockReason: "Study", stopReason: nil).isComplete)
        #expect(FrictionUnlockReflection(blockReason: "Study", stopReason: .needSomethingImportant).isComplete)
    }



    @Test func delayModeUsesFifteenSecondWaitAndCalmCopy() async throws {
        let delay = DelayModeConfiguration.default

        #expect(delay.waitSeconds == 15)
        #expect(delay.title == "Wait 15 seconds")
        #expect(delay.message == "If you still want it, continue.")
    }


    @Test func quickBlockStartGuardBlocksReplacementWhileSessionIsActive() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 24, hour: 10, minute: 0))!
        let activeSession = ImmediateBlockSession(start: start, durationMinutes: 480, calendar: calendar)
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 24, hour: 10, minute: 30))!
        let afterEnd = calendar.date(from: DateComponents(year: 2026, month: 5, day: 24, hour: 18, minute: 1))!

        #expect(!QuickBlockStartGuard.canStartNewBlock(existing: activeSession, now: now))
        #expect(QuickBlockStartGuard.canStartNewBlock(existing: activeSession, now: afterEnd))
        #expect(QuickBlockStartGuard.activeBlockMessage(existing: activeSession, now: now) == "Focus already active — 450 min left.")
    }

    @Test func quickBlockPresetsOfferFourCompactDurations() async throws {
        #expect(QuickBlockPreset.mainRow.map(\.title) == ["Quick Reset", "Deep Work", "Study", "Sleep"])
        #expect(QuickBlockPreset.mainRow.map(\.durationMinutes) == [30, 120, 90, 480])
        #expect(QuickBlockPreset.study.durationLabel == "1.5 hours")
        #expect(QuickBlockPreset.sleep.subtitle == "8h")
    }

    @Test func quickBlockPresetSelectionKeepsStartAsASeparateConfirmation() async throws {
        let selection = QuickBlockPresetSelection()

        #expect(selection.selectedMinutes == 60)
        #expect(selection.startButtonTitle == "Start 1 hour focus")
        #expect(selection.selecting(.study).selectedMinutes == 90)
        #expect(selection.selecting(.study).startButtonTitle == "Start 1.5 hours focus")
    }


    @Test func quickBlockPresetsHaveDistinctPremiumMotionCues() async throws {
        #expect(QuickBlockPreset.quickReset.motionCue == .spark)
        #expect(QuickBlockPreset.deepWork.motionCue == .focusPulse)
        #expect(QuickBlockPreset.study.motionCue == .pageFlip)
        #expect(QuickBlockPreset.sleep.motionCue == .moonDrift)
        #expect(Set(QuickBlockPreset.mainRow.map(\.accentName)).count == 4)
        #expect(QuickBlockPreset.deepWork.confirmationTitle == "Deep Work started")
    }

    @Test func launchSplashUsesCalmPremiumSlogan() async throws {
        #expect(AppLaunchSlogan.primary.title == "You vs. you")
        #expect(AppLaunchSlogan.primary.subtitle == "Protect your attention before the scroll wins.")
        #expect(AppLaunchSlogan.all.contains(.primary))
    }


    @Test func firstLaunchOnboardingKeepsNewUsersOnTheMainStatusFlow() async throws {
        let steps = FirstLaunchOnboardingStep.all

        #expect(steps.count == 4)
        #expect(steps.map(\.tabName) == ["Status", "Status", "Status", "Status"])
        #expect(steps.map(\.targetID) == ["Screen Time Access", "Screen Time Access", "App Selection", "Quick Block"])
        #expect(steps.contains { $0.requestsScreenTimePermission })
        #expect(steps[2].body.contains("apps, categories, and websites"))
        #expect(steps.last?.body.contains("Quick Block") == true)
        #expect(steps.last?.buttonTitle == "Start Focusing")
    }

    @Test func firstLaunchOnboardingStateOnlyShowsBeforeCompletion() async throws {
        var state = FirstLaunchOnboardingState(hasCompletedOnboarding: false)

        #expect(state.shouldPresent)
        state.markCompleted()
        #expect(!state.shouldPresent)
    }

    @Test func focusTemplatesExposeTheRequestedPresets() async throws {
        #expect(FocusTemplate.allPresets.map(\.name) == ["Work Mode", "Sleep Mode", "Morning Mode", "Study Mode", "Gym Mode"])
        #expect(FocusTemplate.work.defaultDurationMinutes == 60)
        #expect(FocusTemplate.sleep.blockingIntent.contains("everything except essentials"))
        #expect(FocusTemplate.morning.scheduleHint == "Until 10 AM")
    }

    @Test func accountabilityReceiptUsesPositiveCompletionCopy() async throws {
        let receipt = AccountabilityReceipt(protectedMinutes: 60)

        #expect(receipt.headline == "You protected 1 hour.")
        #expect(receipt.lines == ["Apps stayed blocked.", "Commitment kept."])
    }

    @Test func smartSuggestionsReactToNightBlocksAndEarlyStops() async throws {
        var stats = FocusStats(totalSessions: 3, totalPlannedMinutes: 180)
        let calendar = Calendar(identifier: .gregorian)
        let night = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 22, minute: 30))!
        stats.lastSessionStart = night
        let reflections = [
            FrictionUnlockReflection(blockReason: "Sleep", stopReason: .habit, completedAt: night),
            FrictionUnlockReflection(blockReason: "Sleep", stopReason: .bored, completedAt: night)
        ]

        let suggestions = SmartSuggestionEngine.suggestions(stats: stats, frictionUnlocks: reflections, calendar: calendar)

        #expect(suggestions.map(\.title).contains("Try a Sleep Block preset"))
        #expect(suggestions.map(\.title).contains("Try a shorter 30 min block"))
    }

    @Test func smartSuggestionsHiddenWithoutPersonalizedSignals() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let fresh = FocusStats(totalSessions: 0, totalPlannedMinutes: 0)
        let emptyReflections: [FrictionUnlockReflection] = []

        #expect(!SmartSuggestionEngine.hasPersonalizedSignals(stats: fresh, frictionUnlocks: emptyReflections, calendar: calendar))

        var withSessions = FocusStats(totalSessions: 3, totalPlannedMinutes: 120)
        #expect(SmartSuggestionEngine.hasPersonalizedSignals(stats: withSessions, frictionUnlocks: emptyReflections, calendar: calendar))

        let night = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 23, minute: 0))!
        withSessions = FocusStats(totalSessions: 1, totalPlannedMinutes: 30)
        withSessions.lastSessionStart = night
        #expect(SmartSuggestionEngine.hasPersonalizedSignals(stats: withSessions, frictionUnlocks: emptyReflections, calendar: calendar))

        let reflections = [
            FrictionUnlockReflection(blockReason: "Sleep", stopReason: .habit, completedAt: night),
            FrictionUnlockReflection(blockReason: "Sleep", stopReason: .bored, completedAt: night)
        ]
        let freshAgain = FocusStats(totalSessions: 1, totalPlannedMinutes: 30)
        #expect(SmartSuggestionEngine.hasPersonalizedSignals(stats: freshAgain, frictionUnlocks: reflections, calendar: calendar))
    }




    #if canImport(FamilyControls)
    @Test func shortcutInterventionStoreMarksShieldBackedTriggers() async throws {
        let now = Date(timeIntervalSince1970: 4_000)
        ShortcutInterventionStore.shared.clearDelayShieldTarget()
        ShortcutInterventionStore.shared.recordDelayShieldTrigger(selection: FamilyActivitySelection(), now: now)

        let trigger = ShortcutInterventionStore.shared.consumePendingTrigger(now: now.addingTimeInterval(1))

        #expect(trigger?.returnURL == nil)
        #expect(trigger?.hasShieldTarget == true)
        ShortcutInterventionStore.shared.clearDelayShieldTarget()
    }

    @Test func shortcutReturnURLTriggerClearsStaleShieldTarget() async throws {
        let now = Date(timeIntervalSince1970: 5_000)
        ShortcutInterventionStore.shared.recordDelayShieldTrigger(selection: FamilyActivitySelection(), now: now)
        ShortcutInterventionStore.shared.recordTrigger(returnURL: URL(string: "youtube://"), now: now.addingTimeInterval(1))

        let trigger = ShortcutInterventionStore.shared.consumePendingTrigger(now: now.addingTimeInterval(2))

        #expect(trigger?.returnURL?.absoluteString == "youtube://")
        #expect(trigger?.hasShieldTarget == false)
        ShortcutInterventionStore.shared.clearDelayShieldTarget()
    }

    @Test func expiredShortcutInterventionClearsShieldTarget() async throws {
        let now = Date(timeIntervalSince1970: 6_000)
        ShortcutInterventionStore.shared.recordDelayShieldTrigger(selection: FamilyActivitySelection(), now: now)

        let trigger = ShortcutInterventionStore.shared.consumePendingTrigger(now: now.addingTimeInterval(120))

        #expect(trigger == nil)
        ShortcutInterventionStore.shared.clearDelayShieldTarget()
    }
    #endif


    @Test func delayAppsConfigurationIsIndependentFromBlockingSelection() async throws {
        let delayApps = DelayAppsConfiguration(isEnabled: true, appCount: 2, categoryCount: 1, webDomainCount: 0)
        let blockSchedule = BlockSchedule.defaultFocus
        let immediateBlock = ImmediateBlockSession(durationMinutes: 60)

        #expect(delayApps.isEnabled)
        #expect(delayApps.totalSelectionCount == 3)
        #expect(delayApps.waitSeconds == 15)
        #expect(blockSchedule == BlockSchedule.defaultFocus)
        #expect(immediateBlock.durationMinutes == 60)
    }

    @Test func delayAppsConfigurationCanBeClearedWithoutTouchingBlockState() async throws {
        let enabled = DelayAppsConfiguration(isEnabled: true, appCount: 4, categoryCount: 2, webDomainCount: 1)
        let cleared = enabled.clearedSelection()

        #expect(enabled.totalSelectionCount == 7)
        #expect(cleared.isEnabled)
        #expect(cleared.totalSelectionCount == 0)
        #expect(cleared.waitSeconds == 15)
    }


    @MainActor
    @Test func delayAppsWaitGateStartsWaitInsteadOfBlockingCompletionThread() async throws {
        let gate = DelayAppsWaitGate()
        let start = Date(timeIntervalSince1970: 1_000)

        let decision = gate.decision(now: start, waitStartedAt: nil)

        #expect(decision == .startWaiting(unlockAt: start.addingTimeInterval(15)))
        #expect(gate.remainingSeconds(now: start.addingTimeInterval(12), unlockAt: start.addingTimeInterval(15)) == 3)
    }

    @MainActor
    @Test func delayAppsWaitGateAllowsOnlyAfterFifteenSecondPause() async throws {
        let gate = DelayAppsWaitGate()
        let start = Date(timeIntervalSince1970: 2_000)
        let unlockAt = start.addingTimeInterval(15)

        #expect(gate.decision(now: start.addingTimeInterval(14), waitStartedAt: start) == .keepWaiting(remainingSeconds: 1))
        #expect(gate.decision(now: unlockAt, waitStartedAt: start) == .allowAccess)
        #expect(gate.decision(now: start.addingTimeInterval(30), waitStartedAt: start) == .allowAccess)
    }


    @Test func delayAppsPauseProgressShowsDescendingBarAndRemainingSeconds() {
        let full = DelayAppsPauseProgress(waitSeconds: 15, remainingSeconds: 15)
        let mid = DelayAppsPauseProgress(waitSeconds: 15, remainingSeconds: 7)
        let done = DelayAppsPauseProgress(waitSeconds: 15, remainingSeconds: 0)

        #expect(full.barText == "██████████")
        #expect(mid.barText == "█████░░░░░")
        #expect(done.barText == "░░░░░░░░░░")
        #expect(mid.statusText == "7s left")
        #expect(done.statusText == "Ready")
    }



    @Test func coreFlowExplainsTheMainUserPath() {
        #expect(CoreFlowStep.all.map(\.tabName) == ["Status", "Schedule", "Modes", "Progress"])
        #expect(CoreFlowStep.status.message.contains("apps"))
        #expect(CoreFlowStep.status.title.contains("Quick Block"))
        #expect(CoreFlowStep.progress.message.contains("streaks"))
    }

    @Test func screenTimePermissionCopyIsClearAndPrivacyFirst() {
        let explainer = ScreenTimePermissionExplainer.standard

        #expect(explainer.title == "Why Screen Time access?")
        #expect(explainer.ctaTitle == "Allow Screen Time Access")
        #expect(explainer.bullets.contains { $0.contains("cannot read") })
        #expect(explainer.privacyLine.contains("stay on-device"))
    }


    @Test func macSyncPlanTargetsDeviceIDsAndKeepsPhoneAsSourceOfTruth() {
        let domains = MacBlockDomainPreset.sanitized(["https://YouTube.com/watch", "www.youtube.com", "bad domain"])
        let plan = SyncedMacBlockPlan(domains: domains, durationMinutes: 90, targetDeviceIDs: MacBlockDevicePreset.defaultSelectedDeviceIDs)

        #expect(plan.domains == ["www.youtube.com", "youtube.com"])
        #expect(plan.targetDeviceIDs == MacBlockDevicePreset.defaultSelectedDeviceIDs)
        #expect(plan.activeSession == nil)
    }

    @Test func macSyncActiveSessionCarriesQuickBlockDurationToMac() {
        let start = Date(timeIntervalSince1970: 100)
        let session = SyncedMacImmediateSession(start: start, durationMinutes: 120)
        let plan = SyncedMacBlockPlan(domains: ["reddit.com"], durationMinutes: 60, activeSession: session)

        #expect(plan.durationMinutes == 60)
        #expect(plan.activeSession?.durationMinutes == 120)
        #expect(plan.activeSession?.isActive(at: Date(timeIntervalSince1970: 101)) == true)
    }

    @Test func popularBlockedAppsAutomaticallyMapToTheirWebsites() {
        let domains = AutoWebsiteSync.effectiveDomains(
            bundleIDs: Set(["com.burbn.instagram", "com.google.ios.youtube", "com.zhiliaoapp.musically"]),
            displayNames: Set(["Reddit", "X", "Facebook"]),
            categoryNames: Set<String>(),
            manualDomains: []
        )

        for expected in ["instagram.com", "youtube.com", "tiktok.com", "reddit.com", "x.com", "facebook.com"] {
            #expect(domains.contains(expected))
        }
    }

    @Test func syncedScheduleCarriesDaysTimesTimezoneAndScheduledDomains() {
        let schedule = SyncedMacSchedule(
            domains: ["instagram.com"],
            startHour: 9,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            selectedWeekdays: [2, 3, 4, 5, 6],
            timeZoneIdentifier: "Europe/Zurich",
            targetDeviceIDs: ["ben-macbook-air"]
        )
        let plan = SyncedMacBlockPlan(domains: ["youtube.com"], targetDeviceIDs: ["ben-macbook-air"], schedules: [schedule])

        #expect(plan.schemaVersion == 3)
        #expect(plan.schedules == [schedule])
        #expect(plan.schedules.first?.domains == ["instagram.com"])
        #expect(plan.schedules.first?.selectedWeekdays == [2, 3, 4, 5, 6])
        #expect(plan.schedules.first?.targetDeviceIDs == ["ben-macbook-air"])
    }

    @Test func scheduleSavesProtectedDevicesAndMigratesLegacySchedules() throws {
        let phoneID = MacBlockDevicePreset.currentDeviceID
        let normalizedPhoneID = phoneID.lowercased()
        let schedule = BlockSchedule(
            startHour: 9,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            selectedWeekdays: [2, 3, 4, 5, 6],
            protectedDeviceIDs: [phoneID, "ben-macbook-air"]
        )
        let decoded = try JSONDecoder().decode(BlockSchedule.self, from: JSONEncoder().encode(schedule))
        #expect(decoded.protectedDeviceIDs == [normalizedPhoneID, "ben-macbook-air"])
        #expect(decoded.effectiveProtectedDeviceIDs(defaultRemoteDeviceIDs: ["other-mac"]) == [normalizedPhoneID, "ben-macbook-air"])

        struct LegacySchedule: Encodable {
            let startHour = 9
            let startMinute = 0
            let endHour = 12
            let endMinute = 0
            let selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
            let selectedBlocklistID: UUID? = nil
        }
        let legacy = try JSONDecoder().decode(BlockSchedule.self, from: JSONEncoder().encode(LegacySchedule()))
        #expect(legacy.protectedDeviceIDs == nil)
        #expect(legacy.effectiveProtectedDeviceIDs(defaultRemoteDeviceIDs: ["ben-macbook-air"]) == [normalizedPhoneID, "ben-macbook-air"])
    }


    @Test func quickBlockCommitmentModesKeepNormalSimpleAndStrongPremiumOnly() async throws {
        #expect(QuickBlockCommitmentMode.normal.title == "Normal")
        #expect(QuickBlockCommitmentMode.strong.title == "Strong")
        #expect(!QuickBlockCommitmentMode.normal.requiresPremium)
        #expect(QuickBlockCommitmentMode.strong.requiresPremium)
        #expect(PremiumAccessPolicy.canStartQuickBlock(durationMinutes: 60, isPremium: false, commitmentMode: .normal))
        #expect(!PremiumAccessPolicy.canStartQuickBlock(durationMinutes: 60, isPremium: false, commitmentMode: .strong))
        #expect(PremiumAccessPolicy.canStartQuickBlock(durationMinutes: 60, isPremium: true, commitmentMode: .strong))
    }

    @Test func immediateBlockSessionStoresCommitmentModeAndDefaultsToNormal() async throws {
        let start = Date(timeIntervalSince1970: 10_000)
        let normal = ImmediateBlockSession(start: start, durationMinutes: 30)
        let strong = ImmediateBlockSession(start: start, durationMinutes: 30, commitmentMode: .strong)
        #expect(normal.commitmentMode == .normal)
        #expect(strong.commitmentMode == .strong)
    }

    @Test func escapeTokensAllowOneStrongEmergencyExitPerDay() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        var ledger = EscapeTokenLedger()

        #expect(EscapeTokenPolicy.dailyLimit == 1)
        #expect(EscapeTokenPolicy.remainingTokens(in: ledger, on: day, calendar: calendar) == 1)
        #expect(EscapeTokenPolicy.canSpendToken(in: ledger, on: day, calendar: calendar))

        ledger = EscapeTokenPolicy.spendingToken(in: ledger, on: day, calendar: calendar)
        #expect(EscapeTokenPolicy.remainingTokens(in: ledger, on: day, calendar: calendar) == 0)
        #expect(!EscapeTokenPolicy.canSpendToken(in: ledger, on: day, calendar: calendar))
        #expect(EscapeTokenPolicy.remainingTokens(in: ledger, on: nextDay, calendar: calendar) == 1)
    }

    @Test func frictionUnlockTimingKeepsNormalUnderstandableAndStrongProtected() async throws {
        let normal = FrictionUnlockTiming.forMode(.normal)
        let strong = FrictionUnlockTiming.forMode(.strong)
        #expect(normal.initialDelaySeconds == 30)
        #expect(normal.finalDelaySeconds == 10)
        #expect(strong.initialDelaySeconds == 30)
        #expect(strong.finalDelaySeconds == 20)
        #expect(strong.finalDelaySeconds > normal.finalDelaySeconds)
    }

    @Test func premiumAccessPolicyLimitsFreeQuickBlocksToTwoHours() async throws {
        #expect(PremiumAccessPolicy.maxFreeQuickBlockMinutes == 120)
        #expect(PremiumAccessPolicy.premiumProductID == "com.benberther.BlockerApp.premium")
        #expect(PremiumAccessPolicy.canStartQuickBlock(durationMinutes: 120, isPremium: false))
        #expect(!PremiumAccessPolicy.canStartQuickBlock(durationMinutes: 121, isPremium: false))
        #expect(PremiumAccessPolicy.canStartQuickBlock(durationMinutes: 480, isPremium: true))
        #expect(PremiumAccessPolicy.requiresPremiumForQuickBlock(durationMinutes: 480))
    }


    @Test func schedulesPreserveTheSelectedBlocklistID() async throws {
        let blocklistID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let schedule = BlockSchedule(startHour: 8, startMinute: 0, endHour: 10, endMinute: 0, selectedWeekdays: [2], selectedBlocklistID: blocklistID)
        #expect(schedule.selectedBlocklistID == blocklistID)
    }

    @Test func activeScheduledBlockWindowShowsRemainingTimeAndRotatingQuote() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9, minute: 0))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9, minute: 25))!
        let schedule = BlockSchedule(startHour: 9, startMinute: 0, endHour: 11, endMinute: 0, selectedWeekdays: [2])

        let window = ActiveScheduledBlockWindow.activeWindow(for: schedule, now: now, calendar: calendar)

        #expect(window?.start == start)
        #expect(window?.largeRemainingLabel(at: now) == "1h 35m")
        #expect(ActiveScheduleMotivation.quote(for: now).isEmpty == false)
        #expect(ActiveScheduleMotivation.quote(for: now) == ActiveScheduleMotivation.quote(for: now.addingTimeInterval(1800)))
        #expect(ActiveScheduleMotivation.quote(for: now) != ActiveScheduleMotivation.quote(for: calendar.date(byAdding: .day, value: 1, to: now)!))
    }


    @Test func macSyncSanitizesDomainsWithoutLosingTheAdultFilterSetting() async throws {
        let domains = MacBlockDomainPreset.sanitized(["YouTube.com", "https://example.com/path", "bad domain"])
        #expect(domains.contains("youtube.com"))
        #expect(domains.contains("example.com"))
        #expect(Set(domains).count == domains.count)
        let plan = SyncedMacBlockPlan(domains: domains, durationMinutes: 45, adultWebFilterEnabled: true)
        #expect(plan.adultWebFilterEnabled == true)
    }

    @Test func syncedMacPlanRoundTripsTheAdultFilterFlag() async throws {
        let newPlan = SyncedMacBlockPlan(domains: ["youtube.com"], durationMinutes: 45, adultWebFilterEnabled: true)
        let decoded = try JSONDecoder().decode(SyncedMacBlockPlan.self, from: JSONEncoder().encode(newPlan))
        #expect(decoded.adultWebFilterEnabled == true)
        #expect(decoded.domains == ["youtube.com"])
        #expect(decoded.durationMinutes == 45)
    }

    @Test func legacySyncedMacPlanDefaultsAdultFilterToOff() async throws {
        struct LegacyPlan: Encodable {
            let domains = ["youtube.com"]
            let durationMinutes = 45
            let updatedAt = Date(timeIntervalSince1970: 100)
            let activeSession: SyncedMacImmediateSession? = nil
            let targetDeviceIDs: [String] = []
        }

        let decoded = try JSONDecoder().decode(
            SyncedMacBlockPlan.self,
            from: JSONEncoder().encode(LegacyPlan())
        )
        #expect(decoded.adultWebFilterEnabled == false)
        #expect(decoded.domains == ["youtube.com"])
    }


    @Test func allL10nStringLiteralsHaveLocaleEntries() async throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appRoot = projectRoot.appendingPathComponent("BlockerApp/BlockerApp")
        let sourceFiles = [
            appRoot.appendingPathComponent("App/RootView.swift"),
            appRoot.appendingPathComponent("Views/StatusView.swift"),
            appRoot.appendingPathComponent("Views/SettingsView.swift"),
            appRoot.appendingPathComponent("Views/ScheduleView.swift"),
            appRoot.appendingPathComponent("Views/FocusProgressView.swift"),
            appRoot.appendingPathComponent("Views/FocusModesView.swift"),
            appRoot.appendingPathComponent("Views/ScheduledBlockActiveOverlay.swift")
        ]
        let pattern = #"L10n\.string\("((?:\\.|[^"\\])*)"\)"#
        let regex = try NSRegularExpression(pattern: pattern)
        var keys = Set<String>()
        for file in sourceFiles {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in regex.matches(in: source, range: nsRange) {
                guard let range = Range(match.range(at: 1), in: source) else { continue }
                keys.insert(String(source[range]))
            }
        }

        let locales = ["en", "de", "es", "fr", "pt", "ru", "zh-Hans", "ar", "hi", "bn", "ur"]
        #expect(keys.isEmpty == false)
        for locale in locales {
            let url = appRoot.appendingPathComponent("\(locale).lproj/Localizable.strings")
            let dictionary = NSDictionary(contentsOf: url) as? [String: String] ?? [:]
            for key in keys {
                #expect(dictionary[key] != nil, "Missing localization key '\(key)' in \(locale).lproj")
            }
        }
    }

    @Test func longerGermanAndSpanishUXCopyIsLocalized() async throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appRoot = projectRoot.appendingPathComponent("BlockerApp/BlockerApp")
        let keys = [
            "Create a recurring block so focus happens automatically — no need to start it every time.",
            "Your completed sessions, focus time, and streak will show up here.",
            "Pick devices that follow your blocks and manage websites sent to Mac.",
            "Selected apps show a short impulse pause instead of a hard block."
        ]

        for locale in ["de", "es"] {
            let url = appRoot.appendingPathComponent("\(locale).lproj/Localizable.strings")
            let dictionary = NSDictionary(contentsOf: url) as? [String: String] ?? [:]
            for key in keys {
                let value = dictionary[key]
                #expect(value != nil, "Missing long-form copy in \(locale).lproj: \(key)")
                #expect(value != key, "Long-form copy was left in English in \(locale).lproj: \(key)")
                #expect((value?.count ?? 0) >= 20, "Long-form copy is unexpectedly short in \(locale).lproj: \(key)")
            }
        }
    }

}
