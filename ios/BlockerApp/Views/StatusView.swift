import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StatusView: View {
    @StateObject private var authorization = AuthorizationService()
    @State private var activeSession = ShieldStorage.shared.loadActiveImmediateSession()
    @State private var quickBlockMessage: String?
    @State private var isStartingQuickBlock = false
    @State private var customHours = 0.5
    @State private var showingCustomDuration = false
    @State private var showingFrictionUnlock = false
    @State private var selectedQuickBlockMinutes = 60
    @State private var selectedQuickBlockPreset: QuickBlockPreset?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.09, green: 0.10, blue: 0.22), Color(red: 0.13, green: 0.09, blue: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        activeSessionCard
                        quickBlockCard
                        authorizationCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Status")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingCustomDuration) {
                customDurationSheet
            }
            .sheet(isPresented: $showingFrictionUnlock) {
                frictionUnlockSheet
            }
        }
        .tint(.cyan)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blocker App")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Start a focused block instantly, or let your daily schedule protect your attention.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.18))
                        .frame(width: 68, height: 68)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
            }

            HStack(spacing: 10) {
                statusPill(title: authorization.isAuthorized ? "Access ready" : "Needs access", icon: authorization.isAuthorized ? "checkmark.circle.fill" : "lock.shield")
                statusPill(title: activeSession == nil ? "No active block" : "Blocking now", icon: activeSession == nil ? "moon.zzz.fill" : "bolt.shield.fill")
            }
        }
        .padding(22)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var activeSessionCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let session = refreshedSession(now: context.date)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(session == nil ? "Focus status" : "Protected now", systemImage: session == nil ? "circle.dashed" : "timer")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Spacer()
                }

                if let session {
                    HStack(spacing: 18) {
                        ProgressRing(progress: session.progress(at: context.date))
                            .frame(width: 82, height: 82)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(session.remainingMinutes(at: context.date)) min left")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Protected until \(session.endTimeLabel(at: context.date))")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.68))
                        }

                        Spacer()
                    }

                    Button(role: .destructive) {
                        showingFrictionUnlock = true
                    } label: {
                        Label("Stop with friction unlock", systemImage: "lock.open.trianglebadge.exclamationmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("No active quick block right now. Choose a duration below when you want to focus immediately.")
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
            .padding(20)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        }
    }

    private var quickBlockCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick Block", systemImage: "bolt.shield.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Uses the apps and websites from your Apps tab. Pick a preset or set your own duration.")
                .foregroundStyle(.white.opacity(0.68))

            VStack(alignment: .leading, spacing: 10) {
                Text("Presets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .textCase(.uppercase)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(QuickBlockPreset.mainRow, id: \.self) { preset in
                            quickPresetButton(preset)
                        }

                        Button {
                            showingCustomDuration = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.headline)
                                Text("Custom")
                                    .font(.subheadline.weight(.semibold))
                                Text(durationTitle(selectedQuickBlockMinutes))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                            .frame(width: 106, alignment: .leading)
                            .padding(12)
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                    .padding(.vertical, 2)
                }
            }

            Button {
                startQuickBlock(minutes: selectedQuickBlockMinutes)
            } label: {
                Label(QuickBlockPresetSelection(selectedMinutes: selectedQuickBlockMinutes).startButtonTitle, systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isStartingQuickBlock)

            if let quickBlockMessage {
                Text(quickBlockMessage)
                    .font(.footnote)
                    .foregroundStyle(quickBlockMessage.localizedCaseInsensitiveContains("failed") ? .red : .white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var authorizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Screen Time access", systemImage: authorization.isAuthorized ? "checkmark.circle.fill" : "lock.shield")
                .font(.headline)
                .foregroundStyle(authorization.isAuthorized ? .green : .white)

            Text("Apple requires Screen Time permission before the app can shield selected distractions.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))

            Button(authorization.isAuthorized ? "Access granted" : "Allow Screen Time Access") {
                Task { await authorization.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
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
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var frictionUnlockSheet: some View {
        FrictionUnlockView(
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
                    Text("Custom quick block")
                        .font(.title.bold())
                    Text("Choose how long you want selected distractions blocked.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(customDurationLabel)
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Slider(value: $customHours, in: 0.5...24, step: 0.5)
                HStack {
                    Text("30 min")
                    Spacer()
                    Text("30 min – 24 hours")
                    Spacer()
                    Text("24h")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Button {
                    selectedQuickBlockMinutes = Int(customHours * 60)
                    selectedQuickBlockPreset = nil
                    showingCustomDuration = false
                } label: {
                    Label("Use this duration", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            }
            .padding()
            .navigationTitle("Custom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCustomDuration = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var cardBackground: some ShapeStyle {
        .linearGradient(
            colors: [.white.opacity(0.16), .white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var customDurationLabel: String {
        ImmediateBlockSession(durationMinutes: Int(customHours * 60)).durationLabel
    }

    private func statusPill(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func quickPresetButton(_ preset: QuickBlockPreset) -> some View {
        let isSelected = selectedQuickBlockPreset == preset

        return Button {
            selectedQuickBlockPreset = preset
            selectedQuickBlockMinutes = preset.durationMinutes
            playSelectionHaptic()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: preset.systemImage)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .black : .cyan)
                Text(preset.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(preset.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? .black.opacity(0.65) : .white.opacity(0.62))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(width: 106, alignment: .leading)
            .padding(12)
            .background(isSelected ? .cyan : .white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? .cyan.opacity(0.9) : .white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isStartingQuickBlock)
    }

    private func startQuickBlock(minutes: Int) {
        isStartingQuickBlock = true
        defer { isStartingQuickBlock = false }

        do {
            let session = try ScheduleService.shared.startImmediateBlock(durationMinutes: minutes)
            activeSession = session
            quickBlockMessage = "Started a \(session.durationLabel) block."
            playSuccessHaptic()
        } catch {
            quickBlockMessage = "Block failed: \(error.localizedDescription)"
        }
    }

    private func stopQuickBlock() {
        saveReceiptForStoppedSession()
        ScheduleService.shared.stopImmediateBlock()
        activeSession = nil
        quickBlockMessage = "Quick block stopped."
    }

    private func saveReceiptForStoppedSession() {
        guard let session = activeSession ?? ShieldStorage.shared.loadActiveImmediateSession() else { return }
        let elapsedMinutes = max(1, min(session.durationMinutes, Int(Date().timeIntervalSince(session.start) / 60)))
        try? ShieldStorage.shared.saveAccountabilityReceipt(AccountabilityReceipt(protectedMinutes: elapsedMinutes))
    }

    private func completeFrictionUnlock(_ reflection: FrictionUnlockReflection) {
        try? ShieldStorage.shared.recordFrictionUnlock(reflection)
        showingFrictionUnlock = false
        stopQuickBlock()
        quickBlockMessage = "Quick block stopped after reflection."
    }

    private func refreshedSession(now: Date) -> ImmediateBlockSession? {
        if let activeSession, activeSession.isActive(at: now) {
            return activeSession
        }
        return ShieldStorage.shared.loadActiveImmediateSession(now: now)
    }

    private func durationTitle(_ minutes: Int) -> String {
        ImmediateBlockSession(durationMinutes: minutes).durationLabel
    }

    private func playSelectionHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func playSuccessHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.cyan, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "shield.fill")
                .font(.title2)
                .foregroundStyle(.cyan)
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
