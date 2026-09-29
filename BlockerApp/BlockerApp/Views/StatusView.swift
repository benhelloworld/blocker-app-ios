import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif

/// Turquoise is the app's primary action color. Yellow/orange is reserved for
/// Premium, warnings, and strong blocking.
enum AppActionStyle {
    static let turquoise = [Color(red: 0.20, green: 0.78, blue: 0.74), Color(red: 0.06, green: 0.56, blue: 0.60)]
    static let yellowGold = [Color(red: 1.00, green: 0.78, blue: 0.22), Color(red: 0.93, green: 0.58, blue: 0.10)]
}

struct StatusView: View {
    @EnvironmentObject private var premiumStore: PremiumEntitlementStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onboardingTarget: String?
    let onFlowTabSelected: (String) -> Void

    init(onboardingTarget: String? = nil, onFlowTabSelected: @escaping (String) -> Void = { _ in }) {
        self.onboardingTarget = onboardingTarget
        self.onFlowTabSelected = onFlowTabSelected
    }

    @ObservedObject private var authorization = AuthorizationService.shared
    @State private var activeSession = ShieldStorage.shared.loadActiveImmediateSession()
    @State private var quickBlockMessage: String?
    @State private var isStartingQuickBlock = false
    @State private var customHours = 0.5
    @State private var showingCustomDuration = false
    @State private var showingPremiumUpsell = false
    @State private var showingFrictionUnlock = false
    @State private var showingSettings = false
    @State private var selectedQuickBlockMinutes = 60
    @State private var selectedQuickBlockPreset: QuickBlockPreset?
    @State private var selectedCommitmentMode: QuickBlockCommitmentMode = .normal
    @State private var showingBlockedContent = false
    @State private var quickBlockCountdownStartedAt: Date?
    @State private var pendingQuickBlockMinutes: Int?
    @State private var pendingQuickBlockPreset: QuickBlockPreset?
    @State private var pendingQuickBlockCommitmentMode: QuickBlockCommitmentMode = .normal
    @State private var pendingFocusContinuation: FocusCompletionPrompt?
    @State private var quickBlockCountdownTask: Task<Void, Never>?
    @State private var focusCompletionPrompt: FocusCompletionPrompt?
    #if canImport(FamilyControls)
    @State private var selection = ShieldStorage.shared.loadSelection()
    @State private var activeBlockAdditions = FamilyActivitySelection()
    @State private var showingActiveBlockAdditionsPicker = false
    @State private var activeBlockAdditionMessage: String?
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                homeBackground

                ScrollViewReader { proxy in
                    ScrollView {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let session = activeSession.flatMap { $0.isActive(at: context.date) ? $0 : nil }

                            VStack(spacing: 18) {
                                if let session {
                                    activeFocusScreen(session: session, now: context.date)
                                } else if let completion = focusCompletionPrompt, completion.isAvailable(at: context.date) {
                                    focusCompleteScreen(completion)
                                } else {
                                    statusCard
                                    quickBlockCard
                                    deviceSyncRow
                                    if authorization.isAuthorized {
                                        screenTimeConfirmedRow
                                    } else {
                                        authorizationCard
                                    }
                                }
                            }
                            .padding()
                            .safeAreaPadding(.bottom, 190)
                            .onChange(of: context.date) { _, now in
                                handleTimelineTick(now: now)
                            }
                        }
                    }
                    .onAppear {
                        scrollToOnboardingTarget(with: proxy)
                    }
                    .onChange(of: onboardingTarget) { _, _ in scrollToOnboardingTarget(with: proxy) }
                }
                .accessibilityHidden(quickBlockCountdownStartedAt != nil)

                if let startedAt = quickBlockCountdownStartedAt {
                    quickBlockCountdownOverlay(startedAt: startedAt)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.02)))
                        .zIndex(2)
                }

                bottomTabScrim
            }
            .navigationTitle(L10n.string("Take Back Your Time"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("Settings"))
                    .accessibilityIdentifier("settings-button")
                    .premiumTapTarget()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingCustomDuration) {
                customDurationSheet
            }
            .sheet(isPresented: $showingBlockedContent, onDismiss: refreshSelection) {
                SelectionView()
            }
            .sheet(isPresented: $showingPremiumUpsell) {
                PremiumUpsellView(trigger: .quickBlockLimit) {
                    showingPremiumUpsell = false
                }
            }
            .sheet(isPresented: $showingFrictionUnlock) {
                frictionUnlockSheet
            }
            #if canImport(FamilyControls)
            .familyActivityPicker(
                isPresented: $showingActiveBlockAdditionsPicker,
                selection: $activeBlockAdditions
            )
            .onChange(of: showingActiveBlockAdditionsPicker) { wasPresented, isPresented in
                if wasPresented && !isPresented {
                    applyActiveBlockAdditions()
                }
            }
            #endif
        }
        .tint(AppActionStyle.turquoise[0])
        .onAppear {
            authorization.refresh()
            reconcileImmediateBlockState()
            refreshFocusCompletionState()
            refreshSelection()
        }
        .onDisappear {
            cancelQuickBlockCountdown()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authorization.refresh()
                reconcileImmediateBlockState()
                refreshFocusCompletionState()
                refreshSelection()
            } else {
                cancelQuickBlockCountdown()
            }
        }
    }

    private func scrollToOnboardingTarget(with proxy: ScrollViewProxy) {
        guard let onboardingTarget else { return }
        guard ["Screen Time Access", "App Selection", "Quick Block"].contains(onboardingTarget) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                proxy.scrollTo(onboardingTarget, anchor: .bottom)
            }
        }
    }

    private var bottomTabScrim: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Protection status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.mint.opacity(0.24), Color.indigo.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.mint.opacity(0.70), Color.indigo.opacity(0.42)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: authorization.isAuthorized ? "shield.lefthalf.filled" : "shield.slash.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.mint)
                }

                Spacer(minLength: 12)

                Button {
                    showingPremiumUpsell = true
                } label: {
                    PremiumStatusBadge(isPremium: premiumStore.isPremium)
                }
                .buttonStyle(PremiumPressButtonStyle())
                .accessibilityIdentifier("status-premium-badge-button")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.string("Protection status"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
                Text(authorization.isAuthorized ? L10n.string("Ready") : L10n.string("Needs Screen Time access"))
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(selectedContentSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(statusCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    #if canImport(FamilyControls)
    private var selectedContentSummary: String {
        if selectionIsEmpty {
            return L10n.string("No apps or websites selected yet")
        }
        let parts: [String] = [
            selection.applicationTokens.isEmpty ? nil : String(format: L10n.string("%d apps"), selection.applicationTokens.count),
            selection.categoryTokens.isEmpty ? nil : String(format: L10n.string("%d categories"), selection.categoryTokens.count),
            selection.webDomainTokens.isEmpty ? nil : String(format: L10n.string("%d websites"), selection.webDomainTokens.count)
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }
    #endif

    private var screenTimeConfirmedRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.mint)
            Text(L10n.string("Screen Time access is on"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.mint.opacity(0.22), lineWidth: 1))
        .id("Screen Time Access")
        .onboardingHighlight("Screen Time Access")
    }

    // MARK: - Quick Block

    private var quickBlockCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(L10n.string("Quick Block"), systemImage: "bolt.shield.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(L10n.string("Focus now"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.09), in: Capsule())
            }

            // 1. Selected content summary
            selectedContentRow

            // 2. Duration
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("Duration"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(QuickBlockPreset.mainRow, id: \.self) { preset in
                            compactPresetChip(preset)
                        }

                        Button {
                            showingCustomDuration = true
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.headline)
                                Text(L10n.string("Custom"))
                                    .font(.subheadline.weight(.semibold))
                                Text(durationTitle(selectedQuickBlockMinutes))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                            .foregroundStyle(.white)
                            .frame(width: 92, alignment: .leading)
                            .padding(12)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }

            // 3. Block strength
            commitmentModeSelector

            // 4. Start button
            Button {
                beginQuickBlockCountdown(minutes: selectedQuickBlockMinutes, preset: selectedQuickBlockPreset)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedQuickBlockPreset?.systemImage ?? "play.fill")
                    Text(String(format: L10n.string("Start %@ focus"), durationTitle(selectedQuickBlockMinutes)))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .foregroundStyle(.black)
            .background(
                LinearGradient(
                    colors: AppActionStyle.yellowGold,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: AppActionStyle.yellowGold[0].opacity(0.32), radius: 18, y: 8)
            .disabled(isStartingQuickBlock)
            .accessibilityIdentifier("start-focus-button")
            .buttonStyle(PremiumPressButtonStyle())

            if let quickBlockMessage {
                Text(quickBlockMessage)
                    .font(.footnote)
                    .foregroundStyle(quickBlockMessage.localizedCaseInsensitiveContains("failed") ? .red : .white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(quickBlockCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .id("Quick Block")
        .onboardingHighlight("Quick Block")
    }

    private var selectedContentRow: some View {
        Button {
            showingBlockedContent = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "app.badge")
                    .font(.headline)
                    .foregroundStyle(.mint)
                    .frame(width: 34, height: 34)
                    .background(.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectionIsEmpty ? L10n.string("Choose what to block") : selectedContentSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Text(L10n.string("Apps, categories, and websites"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.50))
            }
            .padding(12)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("blocked-content-selection-button")
        .id("App Selection")
        .onboardingHighlight("App Selection")
    }

    private func compactPresetChip(_ preset: QuickBlockPreset) -> some View {
        let isSelected = selectedQuickBlockPreset == preset
        let accent = presetAccentColor(preset)

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                selectedQuickBlockPreset = preset
                selectedQuickBlockMinutes = preset.durationMinutes
            }
            playSelectionHaptic()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    AnimatedPresetGlyph(preset: preset, isSelected: isSelected, accent: isSelected ? .black : accent)
                        .frame(width: 26, height: 26)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }
                Text(L10n.string(preset.title))
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.string(preset.subtitle))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .black.opacity(0.62) : .white.opacity(0.58))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(width: 96, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(.white.opacity(0.09)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.40) : .white.opacity(0.13), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isStartingQuickBlock)
    }

    private var commitmentModeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string("Block strength"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if !premiumStore.isPremium {
                    Text(L10n.string("Strong is Premium"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow)
                }
            }

            HStack(spacing: 10) {
                commitmentModeButton(.normal)
                commitmentModeButton(.strong)
            }
        }
    }

    private func commitmentModeButton(_ mode: QuickBlockCommitmentMode) -> some View {
        let isSelected = selectedCommitmentMode == mode
        let accent: Color = mode == .strong ? Color(red: 0.88, green: 0.16, blue: 0.22) : .mint

        return Button {
            if mode.requiresPremium && !premiumStore.isPremium {
                showingPremiumUpsell = true
            } else {
                selectedCommitmentMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.systemImage)
                Text(L10n.string(mode.title))
                if mode == .strong {
                    Image(systemName: "sparkles")
                        .font(.caption)
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(isSelected ? (mode == .strong ? .white : .black) : (mode == .strong ? accent.opacity(0.98) : .white.opacity(0.82)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(mode == .strong ? accent.opacity(0.13) : .white.opacity(0.09)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? accent : (mode == .strong ? accent.opacity(0.48) : .white.opacity(0.14)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(mode == .strong ? "strong-mode-button" : "normal-mode-button")
    }

    // MARK: - Blocked content

    private var blockedContentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.string("Blocked content"), systemImage: "app.badge")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(L10n.string("What Quick Block and schedules protect on this iPhone."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))

            #if canImport(FamilyControls)
            HStack(spacing: 12) {
                selectionMetric(value: selection.applicationTokens.count, label: "Apps", icon: "app.fill", accent: .mint)
                selectionMetric(value: selection.categoryTokens.count, label: "Categories", icon: "square.grid.2x2.fill", accent: .orange)
                selectionMetric(value: selection.webDomainTokens.count, label: "Websites", icon: "globe", accent: .blue)
            }

            Button {
                showingBlockedContent = true
            } label: {
                Label(selectionIsEmpty ? L10n.string("Choose Apps and Websites") : L10n.string("Edit Apps and Websites"), systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(PremiumPressButtonStyle())
            .id("App Selection")
            .onboardingHighlight("App Selection")
            #else
            Text(L10n.string("Apple’s Screen Time picker is available on the iPhone app target."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Device sync row (details live in Settings)

    private var deviceSyncRow: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                    .frame(width: 34, height: 34)
                    .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("Device sync"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(deviceSyncSubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }

                Spacer()

                Text(L10n.string("iCloud"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan, in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(14)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var deviceSyncSubtitle: String {
        let selected = ShieldStorage.shared.loadSelectedMacDeviceIDs()
        if selected.isEmpty {
            return L10n.string("Only this iPhone — no Macs connected")
        }
        return String(format: L10n.string("%d device(s) follow your blocks"), selected.count)
    }

    #if canImport(FamilyControls)
    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }
    #endif

    private func refreshSelection() {
        #if canImport(FamilyControls)
        selection = ShieldStorage.shared.loadSelection()
        #endif
    }

    private func reconcileImmediateBlockState() {
        do {
            activeSession = try ScheduleService.shared.reconcileImmediateShield()
        } catch {
            activeSession = nil
            quickBlockMessage = error.localizedDescription
        }
    }

    private func refreshFocusCompletionState(now: Date = Date()) {
        focusCompletionPrompt = ScheduleService.shared.reconcileFocusCompletionPrompt(now: now)
    }

    private func selectionMetric(value: Int, label: String, icon: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.34), lineWidth: 1))
    }

    // MARK: - Active session

    private func focusCompleteScreen(_ completion: FocusCompletionPrompt) -> some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(AppActionStyle.turquoise[0].opacity(0.16))
                    .frame(width: 94, height: 94)
                Circle()
                    .stroke(AppActionStyle.turquoise[0].opacity(0.42), lineWidth: 1)
                    .frame(width: 94, height: 94)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppActionStyle.turquoise[0])
            }
            .accessibilityHidden(true)

            VStack(spacing: 9) {
                Text(L10n.string("Focus complete"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(String(format: L10n.string("You protected %@ of focused time."), durationTitle(completion.session.durationMinutes)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                Text(L10n.string("Nice work. Carry that momentum into your next focus block when you’re ready."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 11) {
                Button {
                    continueFocus(from: completion)
                } label: {
                    Label(L10n.string("Keep going for 15 minutes"), systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }
                .buttonStyle(PremiumPressButtonStyle())
                .accessibilityIdentifier("keep-going-15-minutes-button")

                Button {
                    dismissFocusComplete()
                    onFlowTabSelected("Progress")
                } label: {
                    Label(L10n.string("View progress"), systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.90))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("view-focus-progress-button")

                Button {
                    dismissFocusComplete()
                } label: {
                    Text(L10n.string("Done"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.white.opacity(0.04), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dismiss-focus-complete-button")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [AppActionStyle.turquoise[0].opacity(0.13), Color.indigo.opacity(0.10), .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus-complete-screen")
    }

    private func continueFocus(from completion: FocusCompletionPrompt) {
        beginQuickBlockCountdown(
            minutes: FocusCompletionPolicy.continuationMinutes,
            preset: nil,
            commitmentMode: completion.session.commitmentMode,
            continuationPrompt: completion
        )
    }

    private func dismissFocusComplete() {
        ScheduleService.shared.dismissFocusCompletionPrompt()
        focusCompletionPrompt = nil
        playSelectionHaptic()
    }

    private func activeFocusScreen(session: ImmediateBlockSession, now: Date) -> some View {
        let remainingText = largeRemainingLabel(for: session, now: now)
        let endText = "Protected until \(session.endTimeLabel(at: now))"
        let progress = session.progress(at: now)

        return VStack(spacing: 18) {
            activeTimerHero(remainingText: remainingText, endText: endText, progress: progress, session: session)
            #if canImport(FamilyControls)
            activeBlockAdditionCard
            #endif
            if QuickBlockLaunchPolicy.canCancelWithoutFriction(sessionStart: session.start, now: now) {
                quickBlockGraceStopButton(session: session, now: now)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                stopFrictionButton
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.24), value: QuickBlockLaunchPolicy.canCancelWithoutFriction(sessionStart: session.start, now: now))
    }

    private func activeTimerHero(remainingText: String, endText: String, progress: Double, session: ImmediateBlockSession) -> some View {
        VStack(spacing: 22) {
            HStack {
                Label(session.commitmentMode == .strong ? L10n.string("Strong block active") : L10n.string("Focus locked"), systemImage: "lock.shield.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.yellow)
                Spacer()
                Text(L10n.string("ACTIVE"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.yellow, in: Capsule())
            }

            ZStack {
                ProgressRing(progress: progress)
                    .frame(width: 214, height: 214)
                    .shadow(color: Color.yellow.opacity(0.22), radius: 28, y: 14)

                VStack(spacing: 5) {
                    Text(remainingText)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    Text(L10n.string("remaining"))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.58))
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 7) {
                Text(L10n.string("Your current block has to finish before you can start another one."))
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text(endText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.14), Color.yellow.opacity(0.11), Color.white.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.yellow.opacity(0.34), lineWidth: 1)
        )
    }

    #if canImport(FamilyControls)
    private var activeBlockAdditionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                activeBlockAdditions = FamilyActivitySelection()
                activeBlockAdditionMessage = nil
                showingActiveBlockAdditionsPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.app.fill")
                        .font(.headline)
                        .foregroundStyle(AppActionStyle.turquoise[0])
                        .frame(width: 40, height: 40)
                        .background(AppActionStyle.turquoise[0].opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Text(L10n.string("Add more apps to your current block:"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppActionStyle.turquoise[0].opacity(0.32), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-apps-to-active-block-button")

            if let activeBlockAdditionMessage {
                Text(activeBlockAdditionMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    #endif

    private func largeRemainingLabel(for session: ImmediateBlockSession, now: Date) -> String {
        let minutes = session.remainingMinutes(at: now)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    private func countdownAccessibilityLabel(remainingSeconds: Int) -> String {
        if remainingSeconds == 1 {
            return L10n.string("Block starts in 1 second")
        }
        return String(format: L10n.string("Block starts in %d seconds"), remainingSeconds)
    }

    private func undoAccessibilityLabel(remainingSeconds: Int) -> String {
        if remainingSeconds == 1 {
            return L10n.string("1 second to undo")
        }
        return String(format: L10n.string("%d seconds to undo"), remainingSeconds)
    }

    private func quickBlockGraceStopButton(session: ImmediateBlockSession, now: Date) -> some View {
        let remaining = QuickBlockLaunchPolicy.graceRemaining(sessionStart: session.start, now: now)

        return Button {
            cancelQuickBlockDuringGrace(session)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.mint.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "arrow.uturn.backward")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.mint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("Undo Quick Block"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.string("Changed something by mistake? Stop now without friction."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2.weight(.bold))
                    Text("\(remaining)")
                        .font(.caption.weight(.black))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.mint, in: Capsule())
                .accessibilityLabel(undoAccessibilityLabel(remainingSeconds: remaining))
            }
            .padding(14)
            .background(Color.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.mint.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick-block-grace-stop-button")
    }

    private var stopFrictionButton: some View {
        Button(role: .destructive) {
            showingFrictionUnlock = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.trianglebadge.exclamationmark")
                Text(L10n.string((activeSession?.commitmentMode ?? .normal) == .strong ? "Use emergency exit" : "Stop with friction unlock"))
            }
            .font(.headline)
            .foregroundStyle(Color.red.opacity(0.95))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.red.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Authorization

    private var authorizationCard: some View {
        let explainer = ScreenTimePermissionExplainer.standard

        return VStack(alignment: .leading, spacing: 14) {
            Label(L10n.string(explainer.title), systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(.yellow)

            PermissionExplanationRows(explainer: explainer)

            Button {
                Task { await authorization.requestAuthorization() }
            } label: {
                Label(L10n.string(explainer.ctaTitle), systemImage: "lock.shield")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                    .shadow(color: AppActionStyle.turquoise[0].opacity(0.26), radius: 16, y: 7)
            }
            .buttonStyle(.plain)
            .disabled(authorization.isAuthorized)

            if let error = authorization.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .id("Screen Time Access")
        .onboardingHighlight("Screen Time Access")
    }

    // MARK: - Sheets

    private var frictionUnlockSheet: some View {
        let mode = activeSession?.commitmentMode ?? ShieldStorage.shared.loadActiveImmediateSession()?.commitmentMode ?? .normal
        let remainingTokens = EscapeTokenPolicy.remainingTokens(in: ShieldStorage.shared.loadEscapeTokenLedger())
        return FrictionUnlockView(
            commitmentMode: mode,
            remainingEscapeTokens: remainingTokens,
            onCancel: { showingFrictionUnlock = false },
            onComplete: { reflection in
                completeFrictionUnlock(reflection)
            }
        )
    }

    private var customDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(L10n.string("Custom quick block"))
                        .font(.title.bold())
                    Text(L10n.string("Choose how long you want selected distractions blocked."))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(customDurationLabel)
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Slider(value: $customHours, in: 0.5...24, step: 0.5)
                HStack {
                    Text(L10n.string("30 min"))
                    Spacer()
                    Text(L10n.string("30 min – 24 hours"))
                    Spacer()
                    Text(L10n.string("24h"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Button {
                    confirmCustomDuration()
                } label: {
                    Label(L10n.string("Use this duration"), systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            }
            .padding()
            .navigationTitle(L10n.string("Custom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) { showingCustomDuration = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var cardBackground: some ShapeStyle {
        .linearGradient(
            colors: [.white.opacity(0.13), .white.opacity(0.055)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var statusCardBackground: some ShapeStyle {
        .linearGradient(
            colors: [
                Color(red: 0.20, green: 0.78, blue: 0.74).opacity(0.13),
                Color.indigo.opacity(0.075),
                .white.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var quickBlockCardBackground: some ShapeStyle {
        .linearGradient(
            colors: [
                Color(red: 0.20, green: 0.26, blue: 0.48).opacity(0.34),
                Color(red: 0.33, green: 0.18, blue: 0.40).opacity(0.22),
                .white.opacity(0.055)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var homeBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.002, green: 0.003, blue: 0.008),
                    Color(red: 0.018, green: 0.025, blue: 0.052),
                    Color(red: 0.052, green: 0.025, blue: 0.064)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.08, green: 0.70, blue: 0.66).opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 72)
                .offset(x: 170, y: -300)

            Circle()
                .fill(Color.indigo.opacity(0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 88)
                .offset(x: -190, y: 180)

            Circle()
                .fill(Color(red: 0.58, green: 0.22, blue: 0.48).opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 96)
                .offset(x: 180, y: 620)
        }
        .ignoresSafeArea()
    }

    private var customDurationLabel: String {
        durationTitle(Int(customHours * 60))
    }

    private func presetAccentColor(_ preset: QuickBlockPreset) -> Color {
        switch preset {
        case .quickReset: return .teal
        case .deepWork: return .indigo
        case .study: return .blue
        case .sleep: return .purple
        }
    }

    private func quickBlockCountdownOverlay(startedAt: Date) -> some View {
        let accent = pendingQuickBlockPreset.map(presetAccentColor) ?? AppActionStyle.turquoise[0]

        return TimelineView(.periodic(from: .now, by: reduceMotion ? 1 : 1.0 / 30.0)) { context in
            let remaining = max(1, QuickBlockLaunchPolicy.countdownRemaining(startedAt: startedAt, now: context.date))
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let progress = min(1, elapsed / TimeInterval(QuickBlockLaunchPolicy.countdownSeconds))

            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.98), Color(red: 0.025, green: 0.035, blue: 0.070), Color(red: 0.060, green: 0.028, blue: 0.075)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)

                VStack(spacing: 24) {
                    Spacer()

                    Label(L10n.string("Quick Block"), systemImage: "bolt.shield.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))

                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(colors: [accent, AppActionStyle.turquoise[0]], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: accent.opacity(0.36), radius: 18)

                        Group {
                            if reduceMotion {
                                Text("\(remaining)")
                            } else {
                                Text("\(remaining)")
                                    .contentTransition(.numericText())
                                    .animation(.snappy(duration: 0.22), value: remaining)
                            }
                        }
                        .font(.system(size: 92, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityLabel(countdownAccessibilityLabel(remainingSeconds: remaining))
                        .accessibilityIdentifier("quick-block-countdown-number")
                    }
                    .frame(width: 224, height: 224)

                    VStack(spacing: 8) {
                        Text(L10n.string("Block starts in"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let minutes = pendingQuickBlockMinutes {
                            Text(durationTitle(minutes))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.66))
                        }
                    }

                    Button {
                        cancelQuickBlockCountdown()
                    } label: {
                        Text(L10n.string("Cancel"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.84))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cancel-quick-block-countdown-button")
                    .padding(.horizontal, 28)

                    Spacer()
                }
                .padding(.vertical, 24)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("quick-block-countdown-overlay")
        }
    }

    // MARK: - Actions

    #if canImport(FamilyControls)
    private func applyActiveBlockAdditions() {
        let hasAdditions = !activeBlockAdditions.applicationTokens.isEmpty
            || !activeBlockAdditions.categoryTokens.isEmpty
            || !activeBlockAdditions.webDomainTokens.isEmpty
        guard hasAdditions else { return }

        do {
            guard try ScheduleService.shared.addToActiveHardBlock(activeBlockAdditions) != nil else {
                reconcileImmediateBlockState()
                return
            }
            activeBlockAdditionMessage = nil
            activeBlockAdditions = FamilyActivitySelection()
            playSuccessHaptic()
        } catch {
            activeBlockAdditionMessage = error.localizedDescription
        }
    }
    #endif

    private func beginQuickBlockCountdown(
        minutes: Int,
        preset: QuickBlockPreset?,
        commitmentMode: QuickBlockCommitmentMode? = nil,
        continuationPrompt: FocusCompletionPrompt? = nil
    ) {
        let mode = commitmentMode ?? selectedCommitmentMode
        guard PremiumAccessPolicy.canStartQuickBlock(durationMinutes: minutes, isPremium: premiumStore.isPremium, commitmentMode: mode) else {
            quickBlockMessage = L10n.string("Premium unlocks Quick Blocks longer than 2 hours.")
            presentPremiumUpsellFromQuickBlock()
            return
        }
        guard !isStartingQuickBlock else { return }

        let startedAt = Date()
        pendingQuickBlockMinutes = minutes
        pendingQuickBlockPreset = preset
        pendingQuickBlockCommitmentMode = mode
        pendingFocusContinuation = continuationPrompt
        withAnimation(.easeInOut(duration: 0.24)) {
            quickBlockCountdownStartedAt = startedAt
        }
        quickBlockMessage = nil
        isStartingQuickBlock = true
        playSelectionHaptic()

        quickBlockCountdownTask?.cancel()
        quickBlockCountdownTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(QuickBlockLaunchPolicy.countdownSeconds) * 1_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            activatePendingQuickBlock()
        }
    }

    private func activatePendingQuickBlock() {
        guard let minutes = pendingQuickBlockMinutes else {
            cancelQuickBlockCountdown()
            return
        }
        let mode = pendingQuickBlockCommitmentMode

        quickBlockCountdownTask = nil
        withAnimation(.easeInOut(duration: 0.20)) {
            quickBlockCountdownStartedAt = nil
        }
        pendingQuickBlockMinutes = nil
        pendingQuickBlockPreset = nil
        defer { isStartingQuickBlock = false }

        do {
            let session = try ScheduleService.shared.startImmediateBlock(durationMinutes: minutes, commitmentMode: mode)
            activeSession = session
            focusCompletionPrompt = nil
            pendingFocusContinuation = nil
            quickBlockMessage = String(format: L10n.string("Started a %@ block."), L10n.string(session.durationLabel))
            playSuccessHaptic()
            syncMacForStartedQuickBlock(session)
        } catch {
            if let continuation = pendingFocusContinuation {
                try? ShieldStorage.shared.saveFocusCompletionPrompt(continuation)
                focusCompletionPrompt = continuation
            }
            pendingFocusContinuation = nil
            quickBlockMessage = String(format: L10n.string("Block failed: %@"), error.localizedDescription)
        }
    }

    private func cancelQuickBlockCountdown() {
        quickBlockCountdownTask?.cancel()
        quickBlockCountdownTask = nil
        withAnimation(.easeInOut(duration: 0.20)) {
            quickBlockCountdownStartedAt = nil
        }
        pendingQuickBlockMinutes = nil
        pendingQuickBlockPreset = nil
        pendingFocusContinuation = nil
        isStartingQuickBlock = false
    }

    private func confirmCustomDuration() {
        let minutes = Int(customHours * 60)
        guard PremiumAccessPolicy.canStartQuickBlock(durationMinutes: minutes, isPremium: premiumStore.isPremium) else {
            showingCustomDuration = false
            quickBlockMessage = L10n.string("Premium unlocks Quick Blocks longer than 2 hours.")
            presentPremiumUpsellFromQuickBlock(delay: 0.28)
            return
        }

        selectedQuickBlockMinutes = minutes
        selectedQuickBlockPreset = nil
        showingCustomDuration = false
    }

    private func presentPremiumUpsellFromQuickBlock(delay: TimeInterval = 0) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                showingPremiumUpsell = true
            }
        } else {
            showingPremiumUpsell = true
        }
    }

    private func cancelQuickBlockDuringGrace(_ session: ImmediateBlockSession, now: Date = Date()) {
        guard QuickBlockLaunchPolicy.canCancelWithoutFriction(sessionStart: session.start, now: now) else {
            showingFrictionUnlock = true
            return
        }

        ScheduleService.shared.stopImmediateBlock(force: true)
        ScheduleService.shared.dismissFocusCompletionPrompt()
        activeSession = nil
        quickBlockMessage = L10n.string("Quick Block cancelled. Nothing was recorded.")
        syncMacForStoppedQuickBlock(durationMinutes: session.durationMinutes)
        playSelectionHaptic()
    }

    private func stopQuickBlock() {
        guard let session = activeSession ?? ShieldStorage.shared.loadActiveImmediateSession() else {
            ScheduleService.shared.stopImmediateBlock(force: true)
            quickBlockMessage = L10n.string("Quick block stopped.")
            return
        }

        let now = Date()
        saveReceipt(for: session, completedAt: now)
        ScheduleService.shared.recordImmediateBlockCompletion(session, completedAt: now)
        ScheduleService.shared.stopImmediateBlock(force: true)
        activeSession = nil
        quickBlockMessage = L10n.string("Quick block stopped. Progress recorded as elapsed protected time.")
        syncMacForStoppedQuickBlock(durationMinutes: session.durationMinutes)
    }

    private func syncMacForStartedQuickBlock(_ session: ImmediateBlockSession) {
        let domains = AutoWebsiteSync.shared.mergedDomains(withManual: ShieldStorage.shared.loadMacBlockDomains())
        let targetDeviceIDs = ShieldStorage.shared.loadSelectedMacDeviceIDs()
        let adultWebFilterEnabled = ShieldStorage.shared.loadAdultWebFilterEnabled()
        guard !targetDeviceIDs.isEmpty else {
            return
        }
        guard !domains.isEmpty || adultWebFilterEnabled else {
            return
        }

        QuickBlockMacSyncCoordinator.shared.enqueueStart(
            domains: domains,
            session: session,
            targetDeviceIDs: targetDeviceIDs,
            adultWebFilterEnabled: adultWebFilterEnabled
        )
    }

    private func syncMacForStoppedQuickBlock(durationMinutes: Int) {
        let domains = AutoWebsiteSync.shared.mergedDomains(withManual: ShieldStorage.shared.loadMacBlockDomains())
        let targetDeviceIDs = ShieldStorage.shared.loadSelectedMacDeviceIDs()
        QuickBlockMacSyncCoordinator.shared.enqueueStop(
            domains: domains,
            durationMinutes: durationMinutes,
            targetDeviceIDs: targetDeviceIDs,
            adultWebFilterEnabled: ShieldStorage.shared.loadAdultWebFilterEnabled()
        )
    }

    private func saveReceipt(for session: ImmediateBlockSession, completedAt: Date) {
        let elapsedMinutes = max(0, min(session.durationMinutes, Int(floor(completedAt.timeIntervalSince(session.start) / 60))))
        guard elapsedMinutes > 0 else { return }
        try? ShieldStorage.shared.saveAccountabilityReceipt(AccountabilityReceipt(protectedMinutes: elapsedMinutes))
    }

    private func completeFrictionUnlock(_ reflection: FrictionUnlockReflection) {
        let mode = activeSession?.commitmentMode ?? ShieldStorage.shared.loadActiveImmediateSession()?.commitmentMode ?? .normal
        if mode == .strong {
            let ledger = ShieldStorage.shared.loadEscapeTokenLedger()
            guard EscapeTokenPolicy.canSpendToken(in: ledger) else {
                quickBlockMessage = L10n.string("No emergency exits left today.")
                showingFrictionUnlock = false
                return
            }
            _ = try? ShieldStorage.shared.spendEscapeToken()
        }
        try? ShieldStorage.shared.recordFrictionUnlock(reflection)
        showingFrictionUnlock = false
        stopQuickBlock()
        quickBlockMessage = mode == .strong ? L10n.string("Emergency exit used. Strong block stopped.") : L10n.string("Quick block stopped after reflection.")
    }

    private func handleTimelineTick(now: Date) {
        if let session = activeSession, now >= session.end {
            saveReceipt(for: session, completedAt: session.end)
            ScheduleService.shared.recordImmediateBlockCompletion(session, completedAt: session.end, presentsFocusComplete: true)
            ScheduleService.shared.stopImmediateBlock(preserveFocusCompletion: true)
            syncMacForStoppedQuickBlock(durationMinutes: session.durationMinutes)
            activeSession = nil
            focusCompletionPrompt = ScheduleService.shared.reconcileFocusCompletionPrompt(now: now)
            return
        }

        if let completion = focusCompletionPrompt,
           now >= completion.completedAt.addingTimeInterval(FocusCompletionPolicy.availabilitySeconds) {
            ScheduleService.shared.dismissFocusCompletionPrompt()
            focusCompletionPrompt = nil
        }
    }

    private func durationTitle(_ minutes: Int) -> String {
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? L10n.string("1 hour") : String(format: L10n.string("%d hours"), hours)
        }

        if minutes > 60 {
            let value = Double(minutes) / 60.0
            return String(format: L10n.string("%@ hours"), value.formatted(.number.precision(.fractionLength(1))))
        }

        return minutes == 1 ? L10n.string("1 minute") : String(format: L10n.string("%d minutes"), minutes)
    }

    private func playSelectionHaptic() {
        AppHaptics.selection()
    }

    private func playSuccessHaptic() {
        AppHaptics.success()
    }
}


@MainActor
final class QuickBlockMacSyncCoordinator {
    static let shared = QuickBlockMacSyncCoordinator()

    private var operationTail: Task<Void, Never>?

    private init() {}

    func enqueueStart(
        domains: [String],
        session: ImmediateBlockSession,
        targetDeviceIDs: [String],
        adultWebFilterEnabled: Bool
    ) {
        enqueue {
            try? await MacBlockPlanSyncService.shared.saveActiveSession(
                domains: domains,
                session: session,
                targetDeviceIDs: targetDeviceIDs,
                adultWebFilterEnabled: adultWebFilterEnabled
            )
        }
    }

    func enqueueStop(
        domains: [String],
        durationMinutes: Int,
        targetDeviceIDs: [String],
        adultWebFilterEnabled: Bool
    ) {
        enqueue {
            try? await MacBlockPlanSyncService.shared.clearActiveSessionKeepingSelection(
                domains: domains,
                durationMinutes: durationMinutes,
                targetDeviceIDs: targetDeviceIDs,
                adultWebFilterEnabled: adultWebFilterEnabled
            )
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = operationTail
        operationTail = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }
}


private struct AnimatedPresetGlyph: View {
    let preset: QuickBlockPreset
    let isSelected: Bool
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? accent.opacity(0.16) : accent.opacity(0.12))
            if isSelected {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    icon(for: timeline.date.timeIntervalSinceReferenceDate)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }
            } else {
                icon(for: 0)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
            }
        }
    }

    @ViewBuilder
    private func icon(for time: TimeInterval) -> some View {
        switch preset.motionCue {
        case .spark:
            Image(systemName: preset.systemImage)
                .rotationEffect(.degrees(isSelected ? sin(time * 3.0) * 12 : 0))
                .scaleEffect(isSelected ? 1 + sin(time * 5.0) * 0.06 : 1)
        case .focusPulse:
            Image(systemName: preset.systemImage)
                .scaleEffect(isSelected ? 1 + sin(time * 2.2) * 0.045 : 1)
                .opacity(isSelected ? 0.86 + cos(time * 2.2) * 0.14 : 1)
        case .pageFlip:
            Image(systemName: preset.systemImage)
                .rotation3DEffect(.degrees(isSelected ? sin(time * 2.4) * 9 : 0), axis: (x: 0, y: 1, z: 0))
        case .moonDrift:
            Image(systemName: preset.systemImage)
                .offset(y: isSelected ? sin(time * 1.4) * 2 : 0)
                .rotationEffect(.degrees(isSelected ? sin(time * 1.1) * 4 : 0))
        }
    }
}

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.mint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
