import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif

struct FocusModesView: View {
    @EnvironmentObject private var premiumStore: PremiumEntitlementStore
    let onboardingTarget: String?

    init(onboardingTarget: String? = nil) {
        self.onboardingTarget = onboardingTarget
    }

    @State private var suggestions = SmartSuggestionEngine.suggestions(
        stats: ShieldStorage.shared.loadFocusStats(),
        frictionUnlocks: ShieldStorage.shared.loadFrictionUnlockHistory()
    )
    private var hasSuggestionData: Bool {
        SmartSuggestionEngine.hasPersonalizedSignals(
            stats: ShieldStorage.shared.loadFocusStats(),
            frictionUnlocks: ShieldStorage.shared.loadFrictionUnlockHistory()
        )
    }

    var body: some View {
        Group {
            if premiumStore.isPremium {
                modesContent
            } else {
                PremiumUpsellView(trigger: .advancedFeatures)
            }
        }
        .tint(AppActionStyle.turquoise[0])
        .onAppear { reloadSuggestions() }
    }

    private var modesContent: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        delayModeRow
                        templatesRow
                        if hasSuggestionData {
                            suggestionsRow
                        }
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 150)
                }

                bottomTabScrim
            }
            .navigationTitle(L10n.string("Modes"))
            .toolbarColorScheme(.dark, for: .navigationBar)
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

    private var heroCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.mint)
                .frame(width: 48, height: 48)
                .background(.mint.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            explanatoryText("Softer focus tools: delays, templates, and smart next steps.")

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func explanatoryText(_ copy: String) -> some View {
        Text(L10n.string(copy))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.66))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Compact rows

    private var delayModeRow: some View {
        NavigationLink {
            DelayAppsDetailView()
        } label: {
            modeRow(
                icon: "hourglass",
                accent: .mint,
                title: L10n.string("Delay Apps"),
                subtitle: L10n.string("Selected apps show a short impulse pause instead of a hard block."),
                detail: L10n.string("15s")
            )
            .id("Delay Apps")
            .onboardingHighlight("Delay Apps")
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private var templatesRow: some View {
        NavigationLink {
            FocusTemplatesDetailView()
        } label: {
            modeRow(
                icon: "square.grid.2x2.fill",
                accent: .cyan,
                title: L10n.string("Focus Templates"),
                subtitle: L10n.string("Ready-made setups for work, study, sleep, and more."),
                detail: "\(FocusTemplate.allPresets.count)"
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private var suggestionsRow: some View {
        NavigationLink {
            SmartSuggestionsDetailView()
        } label: {
            modeRow(
                icon: "lightbulb.fill",
                accent: .mint,
                title: L10n.string("Smart Suggestions"),
                subtitle: L10n.string("Calm next steps based on your recent focus patterns."),
                detail: "\(suggestions.count)"
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private func modeRow(icon: String, accent: Color, title: String, subtitle: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Text(detail)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.09), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }

    private func reloadSuggestions() {
        suggestions = SmartSuggestionEngine.suggestions(
            stats: ShieldStorage.shared.loadFocusStats(),
            frictionUnlocks: ShieldStorage.shared.loadFrictionUnlockHistory()
        )
    }
}

// MARK: - Delay Apps detail

struct DelayAppsDetailView: View {
    #if canImport(FamilyControls)
    @State private var delaySelection = ShieldStorage.shared.loadDelaySelection()
    @State private var delayAppsEnabled = ShieldStorage.shared.loadDelayAppsEnabled()
    @State private var isDelayPickerPresented = false
    #endif
    @State private var message: String?
    @State private var showingShortcutInstructions = false
    @State private var showingDelayMode = false

    var body: some View {
        ZStack {
            appBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(L10n.string("Delay Apps"), systemImage: "hourglass")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(L10n.string("Selected apps show a short impulse pause instead of changing your main block list."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    #if canImport(FamilyControls)
                    delaySelectionSummary

                    Toggle(isOn: Binding(
                        get: { delayAppsEnabled },
                        set: { newValue in setDelayAppsEnabled(newValue) }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.string("Delay Apps is active"))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(delayAppsEnabled ? L10n.string("Selected apps show a 15-second shield.") : L10n.string("Turn on after choosing apps to delay."))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(AppActionStyle.turquoise[0])
                    .disabled(delaySelectionIsEmpty && !delayAppsEnabled)

                    Button { isDelayPickerPresented = true } label: {
                        Label(delaySelectionIsEmpty ? L10n.string("Choose Apps to Delay") : L10n.string("Edit Delay Apps"), systemImage: "plus.app.fill")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                            .shadow(color: AppActionStyle.turquoise[0].opacity(0.24), radius: 16, y: 7)
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                    .controlSize(.large)
                    .familyActivityPicker(isPresented: $isDelayPickerPresented, selection: $delaySelection)
                    .onChange(of: delaySelection) { _, newValue in
                        updateDelaySelection(newValue)
                    }

                    Button { showingDelayMode = true } label: {
                        Label(L10n.string("Preview 15 second timer"), systemImage: "timer")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.13), lineWidth: 1))
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                    #else
                    Text(L10n.string("Delay Apps uses Apple Screen Time app selection and is available in the iOS app target."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                    #endif

                    Button { showingShortcutInstructions = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "link.badge.plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(width: 46, height: 46)
                                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            VStack(alignment: .leading, spacing: 5) {
                                Text(L10n.string("Setup instructions"))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(L10n.string("Open the full Shortcuts setup guide."))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .glassCard(cornerRadius: 24)
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                    .accessibilityIdentifier("shortcut-setup-instructions-button")

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding()
                .safeAreaPadding(.bottom, 40)
            }
        }
        .navigationTitle(L10n.string("Delay Apps"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showingShortcutInstructions) {
            ShortcutSetupInstructionsView()
        }
        .sheet(isPresented: $showingDelayMode) {
            DelayModeView()
        }
    }

    #if canImport(FamilyControls)
    private var delaySelectionSummary: some View {
        let config = DelayAppsConfiguration(
            isEnabled: delayAppsEnabled,
            appCount: delaySelection.applicationTokens.count,
            categoryCount: delaySelection.categoryTokens.count,
            webDomainCount: delaySelection.webDomainTokens.count
        )

        return HStack(spacing: 10) {
            delayMetric(value: config.appCount, label: "Apps", icon: "app.fill")
            delayMetric(value: config.categoryCount, label: "Categories", icon: "square.grid.2x2.fill")
            delayMetric(value: config.webDomainCount, label: "Websites", icon: "globe")
        }
    }

    private var delaySelectionIsEmpty: Bool {
        delaySelection.applicationTokens.isEmpty && delaySelection.categoryTokens.isEmpty && delaySelection.webDomainTokens.isEmpty
    }

    private func setDelayAppsEnabled(_ isEnabled: Bool) {
        delayAppsEnabled = isEnabled
        do {
            try ScheduleService.shared.setDelayAppsEnabled(isEnabled, selection: delaySelection)
            message = isEnabled ? L10n.string("Delay Apps is on. Chosen apps now pause for 15 seconds.") : L10n.string("Delay Apps is off. Your normal blocks were not changed.")
            #if canImport(UIKit)
            AppHaptics.success()
            #endif
        } catch {
            delayAppsEnabled = ShieldStorage.shared.loadDelayAppsEnabled()
            message = error.localizedDescription
        }
    }

    private func updateDelaySelection(_ selection: FamilyActivitySelection) {
        do {
            try ScheduleService.shared.updateDelayAppsSelection(selection)
            message = L10n.string("Delay Apps updated. Your block list was not changed.")
        } catch {
            message = error.localizedDescription
        }
    }

    private func delayMetric(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.mint)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }
    #endif

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

// MARK: - Focus Templates detail

struct FocusTemplatesDetailView: View {
    @StateObject private var authorization = AuthorizationService()
    @State private var message: String?
    @State private var activeTemplate = ShieldStorage.shared.loadActiveFocusTemplate()
    @State private var startingTemplate: FocusTemplate?

    var body: some View {
        ZStack {
            appBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(L10n.string("Focus Templates"), systemImage: "square.grid.2x2.fill")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(L10n.string("Ready-made focus setups for common moments. Starting one uses your current selection."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(FocusTemplate.allPresets, id: \.self) { template in
                        templateRow(template)
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding()
                .safeAreaPadding(.bottom, 40)
            }
        }
        .navigationTitle(L10n.string("Focus Templates"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            authorization.refresh()
            activeTemplate = ShieldStorage.shared.loadActiveFocusTemplate()
        }
    }

    private func templateAccent(_ template: FocusTemplate) -> Color {
        switch template {
        case .work: return .blue
        case .sleep: return .purple
        case .morning: return .orange
        case .study: return .mint
        case .gym: return .green
        }
    }

    private func templateRow(_ template: FocusTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: template.systemImage)
                .font(.headline)
                .foregroundStyle(templateAccent(template))
                .frame(width: 38, height: 38)
                .background(templateAccent(template).opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.string(template.name)).font(.headline).foregroundStyle(.white)
                    if let scheduleHint = template.scheduleHint {
                        Text(L10n.string(scheduleHint)).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                }
                Text(L10n.string(template.blockingIntent))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
            }
            Spacer()
            Button {
                Task { await start(template) }
            } label: {
                if startingTemplate == template {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(L10n.string(activeTemplate == template ? "Active" : "Start"))
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(activeTemplate == template ? AppActionStyle.turquoise[0] : .white.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(activeTemplate == template ? AppActionStyle.turquoise[0].opacity(0.14) : .white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(activeTemplate == template ? AppActionStyle.turquoise[0].opacity(0.48) : .white.opacity(0.14), lineWidth: 1))
            .buttonStyle(PremiumPressButtonStyle())
            .disabled(startingTemplate != nil || activeTemplate == template)
            .accessibilityIdentifier("focus-template-\(template.rawValue)")
        }
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }

    @MainActor
    private func start(_ template: FocusTemplate) async {
        startingTemplate = template
        defer { startingTemplate = nil }

        authorization.refresh()
        if !authorization.isAuthorized {
            await authorization.requestAuthorization()
        }
        guard authorization.isAuthorized else {
            activeTemplate = nil
            message = authorization.lastError ?? L10n.string("Allow Screen Time access to start blocking.")
            return
        }

        do {
            let session = try ScheduleService.shared.startImmediateBlock(
                durationMinutes: template.defaultDurationMinutes,
                focusTemplate: template
            )
            // The service returns only after DeviceActivity registration, ManagedSettings
            // assignment verification, and session persistence all succeed.
            activeTemplate = ShieldStorage.shared.loadActiveFocusTemplate()
            guard activeTemplate == template else {
                throw ScheduleServiceError.managedSettingsNotApplied
            }
            message = String(format: L10n.string("Started %@: %@."), L10n.string(template.name), L10n.string(session.durationLabel))
            #if canImport(UIKit)
            AppHaptics.success()
            #endif
        } catch {
            activeTemplate = ShieldStorage.shared.loadActiveFocusTemplate()
            message = error.localizedDescription
        }
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

// MARK: - Smart Suggestions detail

struct SmartSuggestionsDetailView: View {
    @State private var suggestions = SmartSuggestionEngine.suggestions(
        stats: ShieldStorage.shared.loadFocusStats(),
        frictionUnlocks: ShieldStorage.shared.loadFrictionUnlockHistory()
    )

    var body: some View {
        ZStack {
            appBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(L10n.string("Smart Suggestions"), systemImage: "lightbulb.fill")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(L10n.string("Suggestions translate your recent patterns into calm next actions."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.string(suggestion.title))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(L10n.string(suggestion.message))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.66))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
                    }
                }
                .padding()
                .safeAreaPadding(.bottom, 40)
            }
        }
        .navigationTitle(L10n.string("Smart Suggestions"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            suggestions = SmartSuggestionEngine.suggestions(
                stats: ShieldStorage.shared.loadFocusStats(),
                frictionUnlocks: ShieldStorage.shared.loadFrictionUnlockHistory()
            )
        }
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

// MARK: - Shortcuts setup instructions

struct ShortcutSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String)] = [
        ("Open Shortcuts → Automation", "Open Apple Shortcuts, then tap the Automation tab."),
        ("Create a new app automation", "Tap +, choose App, then select the app that usually distracts you."),
        ("Use the opened trigger", "Select Is Opened, choose Run Immediately, and turn off Notify When Run so no Shortcuts notification appears."),
        ("Add Should Pause?", "Add AntiScroll’s Should Pause? action first. It returns No once after you tap Open it, which prevents the automation from looping."),
        ("Add an If block", "Use If Should Pause? is Yes, then run Blocker Pause. Leave Otherwise empty."),
        ("Add Blocker Pause", "Inside the If block, add Blocker Pause. Add the app’s Return URL, for example youtube:// or instagram://, so Open it can jump back."),
        ("Repeat for more apps", "Apple requires one manual automation setup for each distracting app you want to delay.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.015, green: 0.015, blue: 0.018), Color(red: 0.085, green: 0.085, blue: 0.095)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(L10n.string("Shortcut pause setup"), systemImage: "link.badge.plus")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(L10n.string("Follow these steps once in Apple Shortcuts so AntiScroll opens automatically, shows the 15-second pause, then asks: Open it or stay focused. The If step prevents a second delay when you choose Open it."))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .glassCard(cornerRadius: 26)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                instructionStep(number: index + 1, title: step.0, detail: step.1)
                            }
                        }

                        Text(L10n.string("Important: Delay Apps should only be used for apps that are not also in your active block list. If an app is blocked by Quick Block or Schedule, Apple will show the hard block instead of the delay pause."))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.64))
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.string("Setup instructions"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) { dismiss() }
                }
            }
        }
    }

    private func instructionStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.black))
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .background(Color.yellow, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.string(title))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(L10n.string(detail))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22)
    }
}

struct DelayModeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remainingSeconds = DelayModeConfiguration.default.waitSeconds
    private let config = DelayModeConfiguration.default
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.015, green: 0.015, blue: 0.018), Color(red: 0.085, green: 0.085, blue: 0.095)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                VStack(spacing: 24) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.14), lineWidth: 12).frame(width: 170, height: 170)
                        Circle().trim(from: 0, to: Double(config.waitSeconds - remainingSeconds) / Double(config.waitSeconds))
                            .stroke(.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 170, height: 170)
                        Text("\(remainingSeconds)")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text(config.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(config.message)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.70))
                    Button(remainingSeconds == 0 ? "Continue intentionally" : "Waiting…") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                        .buttonStyle(PremiumPressButtonStyle())
                        .controlSize(.large)
                        .disabled(remainingSeconds > 0)
                        .opacity(remainingSeconds > 0 ? 0.45 : 1)
                    Button(L10n.string("Close and stay focused")) { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
            }
            .navigationTitle(L10n.string("Delay"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onReceive(timer) { _ in
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            if remainingSeconds == 0 { AppHaptics.success() }
        }
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        background(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }
}
