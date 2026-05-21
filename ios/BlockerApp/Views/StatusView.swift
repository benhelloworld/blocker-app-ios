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
    @State private var confirmationPreset: QuickBlockPreset?
    @State private var showStartConfirmation = false

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

                if showStartConfirmation {
                    startConfirmationOverlay
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .zIndex(2)
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
                startQuickBlock(minutes: selectedQuickBlockMinutes, preset: selectedQuickBlockPreset)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedQuickBlockPreset?.systemImage ?? "play.fill")
                    Text(QuickBlockPresetSelection(selectedMinutes: selectedQuickBlockMinutes).startButtonTitle)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .foregroundStyle(.black)
            .background(.cyan, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .cyan.opacity(0.25), radius: 18, y: 8)
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
        let accent = presetAccentColor(preset)

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                selectedQuickBlockPreset = preset
                selectedQuickBlockMinutes = preset.durationMinutes
            }
            playSelectionHaptic()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                AnimatedPresetGlyph(preset: preset, isSelected: isSelected)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(preset.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSelected ? .black.opacity(0.66) : .white.opacity(0.62))
                }
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(width: 118, alignment: .leading)
            .padding(13)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? accent : .white.opacity(0.09))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.linearGradient(colors: [.white.opacity(isSelected ? 0.30 : 0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.42) : .white.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: isSelected ? accent.opacity(0.32) : .clear, radius: 18, y: 8)
            .scaleEffect(isSelected ? 1.025 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isStartingQuickBlock)
    }

    private var startConfirmationOverlay: some View {
        let preset = confirmationPreset
        let accent = preset.map(presetAccentColor) ?? .cyan
        return ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 98, height: 98)
                    Circle()
                        .stroke(accent.opacity(0.42), lineWidth: 1)
                        .frame(width: 98, height: 98)
                    AnimatedPresetGlyph(preset: preset ?? .quickReset, isSelected: true)
                        .frame(width: 54, height: 54)
                }

                VStack(spacing: 6) {
                    Text(preset?.confirmationTitle ?? "Focus started")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(preset?.confirmationSubtitle ?? "Your selected block is active.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(26)
            .frame(maxWidth: 310)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            )
            .padding()
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                showStartConfirmation = false
            }
        }
    }

    private func presetAccentColor(_ preset: QuickBlockPreset) -> Color {
        switch preset {
        case .quickReset: return .cyan
        case .deepWork: return .indigo
        case .study: return .orange
        case .sleep: return .purple
        }
    }

    private func startQuickBlock(minutes: Int, preset: QuickBlockPreset?) {
        isStartingQuickBlock = true
        defer { isStartingQuickBlock = false }

        do {
            let session = try ScheduleService.shared.startImmediateBlock(durationMinutes: minutes)
            activeSession = session
            quickBlockMessage = "Started a \(session.durationLabel) block."
            confirmationPreset = preset
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                showStartConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                withAnimation(.easeOut(duration: 0.28)) {
                    showStartConfirmation = false
                }
            }
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


private struct AnimatedPresetGlyph: View {
    let preset: QuickBlockPreset
    let isSelected: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill((isSelected ? Color.black.opacity(0.08) : Color.white.opacity(0.10)))
                icon(for: t)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .black : .white)
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
