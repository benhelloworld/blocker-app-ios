import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif

struct FocusModesView: View {
    @State private var message: String?
    @State private var showingDelayMode = false
    #if canImport(FamilyControls)
    @State private var delaySelection = ShieldStorage.shared.loadDelaySelection()
    @State private var delayAppsEnabled = ShieldStorage.shared.loadDelayAppsEnabled()
    @State private var isDelayPickerPresented = false
    #endif
    @State private var suggestions = SmartSuggestionEngine.suggestions(
        stats: ShieldStorage.shared.loadFocusStats(),
        frictionUnlocks: ShieldStorage.shared.loadFrictionUnlockHistory()
    )

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        delayCard
                        templatesCard
                        suggestionsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Modes")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingDelayMode) { DelayModeView() }
        }
        .tint(.cyan)
        .onAppear { reloadSuggestions() }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Premium Focus")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Delay, templates, suggestions, and calm copy — no shame, just better defaults.")
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 68, height: 68)
                    .background(.cyan.opacity(0.18), in: Circle())
            }
            HStack(spacing: 10) {
                statusPill("Calm dark UI", "moon.fill")
                statusPill("No shame language", "heart.fill")
            }
        }
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private var delayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Delay Apps", systemImage: "hourglass")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Choose apps specifically for delay. This is separate from your block list, quick blocks, and schedules.")
                .foregroundStyle(.white.opacity(0.68))

            #if canImport(FamilyControls)
            delaySelectionSummary

            Toggle(isOn: Binding(
                get: { delayAppsEnabled },
                set: { newValue in setDelayAppsEnabled(newValue) }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Delay Apps is active")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(delayAppsEnabled ? "Selected apps show a 30-second shield." : "Turn on after choosing apps to delay.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .toggleStyle(.switch)
            .disabled(delaySelectionIsEmpty && !delayAppsEnabled)

            Button { isDelayPickerPresented = true } label: {
                Label(delaySelectionIsEmpty ? "Choose Apps to Delay" : "Edit Delay Apps", systemImage: "plus.app.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .familyActivityPicker(isPresented: $isDelayPickerPresented, selection: $delaySelection)
            .onChange(of: delaySelection) { _, newValue in
                updateDelaySelection(newValue)
            }

            Button { showingDelayMode = true } label: {
                Label("Preview 30 second timer", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("When you open one of these chosen apps, Apple’s shield appears. Tap the wait button, pause for 30 seconds, then continue intentionally.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
            #else
            Text("Delay Apps uses Apple Screen Time app selection and is available in the iOS app target.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
            Button { showingDelayMode = true } label: {
                Label("Preview 30 second timer", systemImage: "timer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
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
            message = isEnabled ? "Delay Apps is on. Chosen apps now pause for 30 seconds." : "Delay Apps is off. Your normal blocks were not changed."
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } catch {
            delayAppsEnabled = ShieldStorage.shared.loadDelayAppsEnabled()
            message = error.localizedDescription
        }
    }

    private func updateDelaySelection(_ selection: FamilyActivitySelection) {
        do {
            try ScheduleService.shared.updateDelayAppsSelection(selection)
            message = "Delay Apps updated. Your block list was not changed."
        } catch {
            message = error.localizedDescription
        }
    }

    private func delayMetric(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.cyan)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }
    #endif

    private var templatesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Focus Templates", systemImage: "square.grid.2x2.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Presets for common moments. They use the Apps tab selection for now, with the preset intent shown clearly.")
                .foregroundStyle(.white.opacity(0.68))

            ForEach(FocusTemplate.allPresets, id: \.self) { template in
                templateRow(template)
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Smart Suggestions", systemImage: "lightbulb.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)
            ForEach(suggestions) { suggestion in
                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(suggestion.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private func templateRow(_ template: FocusTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: template.systemImage)
                .font(.headline)
                .foregroundStyle(.cyan)
                .frame(width: 38, height: 38)
                .background(.cyan.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.name).font(.headline).foregroundStyle(.white)
                    if let scheduleHint = template.scheduleHint {
                        Text(scheduleHint).font(.caption.weight(.semibold)).foregroundStyle(.cyan)
                    }
                }
                Text(template.blockingIntent)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }
            Spacer()
            Button("Start") { start(template) }
                .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.09, green: 0.10, blue: 0.22), Color(red: 0.13, green: 0.09, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }

    private func statusPill(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func start(_ template: FocusTemplate) {
        do {
            let session = try ScheduleService.shared.startImmediateBlock(durationMinutes: template.defaultDurationMinutes)
            message = "Started \(template.name): \(session.durationLabel)."
            reloadSuggestions()
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } catch {
            message = error.localizedDescription
        }
    }

    private func reloadSuggestions() {
        suggestions = SmartSuggestionEngine.suggestions(
            stats: ShieldStorage.shared.loadFocusStats(),
            frictionUnlocks: ShieldStorage.shared.loadFrictionUnlockHistory()
        )
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
                LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.12, green: 0.10, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                VStack(spacing: 24) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.14), lineWidth: 12).frame(width: 170, height: 170)
                        Circle().trim(from: 0, to: Double(config.waitSeconds - remainingSeconds) / Double(config.waitSeconds))
                            .stroke(.cyan, style: StrokeStyle(lineWidth: 12, lineCap: .round))
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
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(remainingSeconds > 0)
                    Button("Close and stay focused") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
            }
            .navigationTitle("Delay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onReceive(timer) { _ in
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
        }
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        background(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }
}
