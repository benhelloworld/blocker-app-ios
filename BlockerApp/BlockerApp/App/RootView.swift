import SwiftUI
import Combine


struct OnboardingHighlightPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func onboardingHighlight(_ id: String) -> some View {
        anchorPreference(key: OnboardingHighlightPreferenceKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }
}

private enum BlockerTab: String, Hashable {
    case status = "Status"
    case schedule = "Schedule"
    case progress = "Progress"
    case modes = "Modes"
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLaunchSplash = true
    @State private var selectedTab: BlockerTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-tab-schedule") { return .schedule }
        if arguments.contains("--ui-testing-tab-progress") { return .progress }
        if arguments.contains("--ui-testing-tab-modes") { return .modes }
        return .status
    }()
    @State private var onboardingStepIndex = 0
    @State private var didRequestScreenTimeAccessOnFirstLaunch = false
    @State private var showShortcutIntervention = false
    @State private var shortcutReturnURL: URL?
    @State private var shortcutHasShieldTarget = false
    @State private var shortcutOpenError: String?
    @StateObject private var onboardingAuthorization = AuthorizationService()
    @StateObject private var premiumStore = PremiumEntitlementStore()
    @AppStorage("hasCompletedFirstLaunchOnboarding", store: UserDefaults(suiteName: SharedConfig.appGroupIdentifier)) private var hasCompletedFirstLaunchOnboarding = false
    private let slogan = AppLaunchSlogan.primary

    private var onboardingSteps: [FirstLaunchOnboardingStep] {
        FirstLaunchOnboardingStep.all
    }

    private var currentOnboardingStep: FirstLaunchOnboardingStep? {
        guard onboardingSteps.indices.contains(onboardingStepIndex) else { return nil }
        return onboardingSteps[onboardingStepIndex]
    }

    var body: some View {
        ZStack {
            mainTabs

            if showLaunchSplash {
                LaunchSplashView(slogan: slogan)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
            }

            TimelineView(.periodic(from: .now, by: 15)) { context in
                if let scheduledWindow = activeScheduledWindow(now: context.date), !showLaunchSplash {
                    ScheduledBlockActiveOverlay(window: scheduledWindow, now: context.date)
                        .transition(.opacity.combined(with: .scale(scale: 1.01)))
                        .zIndex(8)
                }
            }

            if showShortcutIntervention {
                ShortcutInterventionView(
                    returnURL: shortcutReturnURL,
                    errorMessage: shortcutOpenError,
                    onOpen: openDelayedApp,
                    onStayFocused: dismissShortcutIntervention
                )
                .transition(.opacity.combined(with: .scale(scale: 1.01)))
                .zIndex(9)
            }
        }
        .overlayPreferenceValue(OnboardingHighlightPreferenceKey.self) { highlights in
            GeometryReader { proxy in
                if !showLaunchSplash && !hasCompletedFirstLaunchOnboarding, let step = currentOnboardingStep {
                    FirstLaunchOnboardingView(
                        step: step,
                        currentIndex: onboardingStepIndex,
                        totalCount: onboardingSteps.count,
                        highlightedFrame: highlights[step.targetID].map { proxy[$0] },
                        onBack: previousOnboardingStep,
                        onNext: nextOnboardingStep,
                        onSkip: completeOnboarding
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            Task { await premiumStore.refreshPremiumStatus() }
            refreshDelayShieldIfNeeded()
            refreshAdultWebFilterIfNeeded()
            refreshScheduledShieldIfNeeded()
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-show-pause-overlay") {
                ShortcutInterventionStore.shared.recordTrigger()
            }
            presentShortcutInterventionIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    showLaunchSplash = false
                }
                // Screen Time permission is requested from the first onboarding step,
                // after the app explains why it is needed.
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await premiumStore.refreshPremiumStatus() }
                refreshDelayShieldIfNeeded()
                refreshAdultWebFilterIfNeeded()
                refreshScheduledShieldIfNeeded()
                presentShortcutInterventionIfNeeded()
            }
        }
        .onChange(of: onboardingStepIndex) { _, newIndex in
            guard onboardingSteps.indices.contains(newIndex) else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                selectedTab = tab(for: onboardingSteps[newIndex].tabName)
            }
        }
        .onChange(of: premiumStore.isPremium) { _, _ in
            if onboardingStepIndex >= onboardingSteps.count {
                onboardingStepIndex = max(onboardingSteps.count - 1, 0)
            }
        }
    }


    private func activeScheduledWindow(now: Date = Date()) -> ActiveScheduledBlockWindow? {
        guard ScheduleService.shared.isScheduledShieldApplied(now: now) else { return nil }
        return ActiveScheduledBlockWindow.activeWindow(for: ShieldStorage.shared.loadSchedule(), now: now)
    }

    private func presentShortcutInterventionIfNeeded() {
        guard let trigger = ShortcutInterventionStore.shared.consumePendingTrigger() else { return }
        shortcutReturnURL = trigger.returnURL
        shortcutHasShieldTarget = trigger.hasShieldTarget
        shortcutOpenError = nil
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            showShortcutIntervention = true
        }
    }

    private func dismissShortcutIntervention() {
        shortcutReturnURL = nil
        shortcutHasShieldTarget = false
        shortcutOpenError = nil
        ShortcutInterventionStore.shared.clearDelayShieldTarget()
        withAnimation(.easeInOut(duration: 0.28)) {
            showShortcutIntervention = false
        }
    }

    /// After the anti-impulse pause, jump straight into the app the user wanted
    /// to open — via its URL scheme. Apps without a known scheme are simply
    /// unblocked (the user taps the icon again); the Shortcuts flow already
    /// handles its own return URL.
    private func reopenDelayTargetIfPossible(bundleIDs: [String]) {
        guard let first = bundleIDs.first,
              let scheme = AppDomainCatalog.urlScheme(forBundleID: first),
              let url = URL(string: scheme) else { return }
        // Small delay so the unblock propagates before launching the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }

    private func openDelayedApp() {
        if shortcutHasShieldTarget && shortcutReturnURL == nil {
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            let targetBundleIDs = ShortcutInterventionStore.shared.pendingDelayShieldTargetBundleIDs()
            if ShortcutInterventionStore.shared.allowPendingDelayShieldTarget() {
                dismissShortcutIntervention()
                reopenDelayTargetIfPossible(bundleIDs: targetBundleIDs)
            } else {
                shortcutOpenError = L10n.string("AntiScroll could not allow that app yet. Please try once more.")
            }
            #else
            dismissShortcutIntervention()
            #endif
            return
        }

        guard let url = shortcutReturnURL else {
            shortcutOpenError = L10n.string("Add a Return URL in Shortcuts first so AntiScroll knows which app to open.")
            return
        }

        ShortcutInterventionStore.shared.allowNextAutomationPass()
        if shortcutHasShieldTarget {
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            _ = ShortcutInterventionStore.shared.allowPendingDelayShieldTarget()
            #endif
        }

        #if canImport(UIKit)
        UIApplication.shared.open(url) { success in
            if success {
                dismissShortcutIntervention()
            } else {
                ShortcutInterventionStore.shared.clearNextAutomationPass()
                shortcutOpenError = L10n.string("AntiScroll could not open that URL. Check the Return URL in Shortcuts.")
            }
        }
        #else
        dismissShortcutIntervention()
        #endif
    }

    private func refreshDelayShieldIfNeeded() {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        try? ScheduleService.shared.refreshDelayAppsShieldIfNeeded()
        #endif
    }

    private func refreshAdultWebFilterIfNeeded() {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        ScheduleService.shared.refreshAdultWebFilterIfNeeded()
        #endif
    }

    private func refreshScheduledShieldIfNeeded() {
        try? ScheduleService.shared.reconcileScheduleShield()
    }

    private func requestScreenTimeAccessForFirstLaunchIfNeeded() {
        guard !hasCompletedFirstLaunchOnboarding, !didRequestScreenTimeAccessOnFirstLaunch else { return }
        guard !ProcessInfo.processInfo.environment.keys.contains("XCTestConfigurationFilePath") else { return }
        didRequestScreenTimeAccessOnFirstLaunch = true
        Task { await onboardingAuthorization.requestAuthorization() }
    }

    private func nextOnboardingStep() {
        guard let step = currentOnboardingStep else { return }

        if step.requestsScreenTimePermission && !didRequestScreenTimeAccessOnFirstLaunch {
            didRequestScreenTimeAccessOnFirstLaunch = true
            Task { await onboardingAuthorization.requestAuthorization() }
        }

        if onboardingStepIndex < onboardingSteps.count - 1 {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                onboardingStepIndex += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func previousOnboardingStep() {
        guard onboardingStepIndex > 0 else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            onboardingStepIndex -= 1
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.32)) {
            hasCompletedFirstLaunchOnboarding = true
        }
    }

    private var currentOnboardingTarget: String? {
        guard !showLaunchSplash, !hasCompletedFirstLaunchOnboarding else { return nil }
        return currentOnboardingStep?.targetID
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            StatusView(onboardingTarget: currentOnboardingTarget) { tabName in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    selectedTab = tab(for: tabName)
                }
            }
                .tabItem { Label(L10n.string("Home"), systemImage: "shield") }
                .tag(BlockerTab.status)

            ScheduleView(onboardingTarget: currentOnboardingTarget)
                .tabItem { Label(L10n.string("Schedule"), systemImage: "calendar") }
                .tag(BlockerTab.schedule)

            FocusProgressView(onboardingTarget: currentOnboardingTarget) { tabName in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    selectedTab = tab(for: tabName)
                }
            }
                .tabItem { Label(L10n.string("Progress"), systemImage: "chart.line.uptrend.xyaxis") }
                .tag(BlockerTab.progress)

            FocusModesView(onboardingTarget: currentOnboardingTarget)
                .tabItem { Label(L10n.string("Modes"), systemImage: "sparkles") }
                .tag(BlockerTab.modes)
        }
        .tint(AppActionStyle.turquoise[0])
        .toolbarBackground(Color.black.opacity(0.96), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
        .environmentObject(premiumStore)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private func tab(for tabName: String) -> BlockerTab {
        switch tabName {
        case BlockerTab.schedule.rawValue: return .schedule
        case BlockerTab.progress.rawValue: return .progress
        case BlockerTab.modes.rawValue: return .modes
        default: return .status
        }
    }
}


private struct FirstLaunchOnboardingView: View {
    let step: FirstLaunchOnboardingStep
    let currentIndex: Int
    let totalCount: Int
    let highlightedFrame: CGRect?
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    private var progressText: String {
        String(format: L10n.string("Step %d of %d"), currentIndex + 1, totalCount)
    }
    private var canGoBack: Bool { currentIndex > 0 }

    var body: some View {
        GeometryReader { proxy in
            let frame = highlightedFrame ?? fallbackHighlightFrame(in: proxy.size)
            let calloutOnTop = true

            ZStack {
                spotlightDimmer(highlightedFrame: frame)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [.yellow.opacity(0.95), .white.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                    .frame(width: frame.width + 14, height: frame.height + 14)
                    .position(x: frame.midX, y: frame.midY)
                    .shadow(color: .yellow.opacity(0.38), radius: 22, y: 0)
                    .allowsHitTesting(false)

                Image(systemName: calloutOnTop ? "arrow.down" : "arrow.up")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.48), radius: 14, y: 4)
                    .position(x: frame.midX, y: arrowY(for: frame, calloutOnTop: calloutOnTop, screenHeight: proxy.size.height))
                    .allowsHitTesting(false)

                VStack {
                    calloutCard
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 70)
                .padding(.bottom, 112)
            }
        }
    }

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: step.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.string(step.cardTitle))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(progressText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                        onboardingDots
                    }
                }

                Spacer()

                Button(L10n.string("Skip")) { onSkip() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Text(L10n.string(step.body))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(canGoBack ? .white.opacity(0.82) : .white.opacity(0.22))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(canGoBack ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .disabled(!canGoBack)
                .buttonStyle(.plain)

                Button { onNext() } label: {
                    HStack(spacing: 8) {
                        Text(L10n.string(step.buttonTitle))
                        Image(systemName: currentIndex < totalCount - 1 ? "arrow.right" : "checkmark")
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(colors: [Color(red: 1.00, green: 0.78, blue: 0.22), Color(red: 0.93, green: 0.58, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(red: 0.070, green: 0.062, blue: 0.086), Color(red: 0.024, green: 0.022, blue: 0.032)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.58), radius: 30, y: 16)
    }

    private var onboardingDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.yellow : Color.white.opacity(0.28))
                    .frame(width: index == currentIndex ? 7 : 5, height: index == currentIndex ? 7 : 5)
            }
        }
        .accessibilityHidden(true)
    }

    private func spotlightDimmer(highlightedFrame frame: CGRect) -> some View {
        Color.black.opacity(0.86)
            .ignoresSafeArea()
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .frame(width: frame.width + 14, height: frame.height + 14)
                    .position(x: frame.midX, y: frame.midY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private func fallbackHighlightFrame(in size: CGSize) -> CGRect {
        CGRect(x: 16, y: size.height * 0.34, width: size.width - 32, height: 170)
    }

    private func arrowY(for frame: CGRect, calloutOnTop: Bool, screenHeight: CGFloat) -> CGFloat {
        if calloutOnTop {
            return max(300, frame.minY - 34)
        } else {
            return min(screenHeight - 250, frame.maxY + 34)
        }
    }

    private var accentColor: Color {
        switch step.tabName {
        case "Schedule": return .orange
        case "Progress": return .green
        case "Modes": return .purple
        default: return .mint
        }
    }
}


private struct LaunchSplashView: View {
    let slogan: AppLaunchSlogan
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.020, green: 0.016, blue: 0.032), Color(red: 0.060, green: 0.038, blue: 0.090)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(glow ? 0.22 : 0.10))
                        .frame(width: 92, height: 92)
                        .blur(radius: 2)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                Text(L10n.string(slogan.subtitle))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
        }
        .onAppear {
            if reduceMotion {
                glow = true
            } else {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
        }
    }
}


private struct ShortcutInterventionView: View {
    let returnURL: URL?
    let errorMessage: String?
    let onOpen: () -> Void
    let onStayFocused: () -> Void
    @State private var remainingSeconds = 15
    private let totalSeconds = 15
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.030, green: 0.026, blue: 0.040), Color(red: 0.080, green: 0.052, blue: 0.105)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.13), lineWidth: 14)
                        .frame(width: 210, height: 210)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 210, height: 210)
                        .shadow(color: .yellow.opacity(0.28), radius: 22, y: 10)

                    VStack(spacing: 4) {
                        Text("\(remainingSeconds)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(L10n.string("seconds"))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }

                VStack(spacing: 10) {
                    Text(L10n.string("Do you really want to open the app?"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(L10n.string("Think about what you had planned."))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if returnURL == nil {
                        Text(L10n.string("If this opened from the blocked app screen, tap Open it after the pause, then open the app once more."))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.24))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 26)

                Button {
                    onOpen()
                } label: {
                    Text(remainingSeconds == 0 ? L10n.string("Open it") : L10n.string("Still waiting…"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [Color(red: 1.00, green: 0.78, blue: 0.22), Color(red: 0.93, green: 0.58, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(remainingSeconds > 0)
                .opacity(remainingSeconds == 0 ? 1 : 0.58)
                .padding(.horizontal, 24)

                Button(L10n.string("No, stay focused")) { onStayFocused() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .padding(.top, 2)

                Spacer()
            }
        }
        .onReceive(timer) { _ in
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
        }
    }

    private var progress: Double {
        Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
}
