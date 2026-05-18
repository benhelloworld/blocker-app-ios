import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StatusView: View {
    @StateObject private var authorization = AuthorizationService()
    @State private var activeSession = ShieldStorage.shared.loadActiveImmediateSession()
    @State private var quickBlockMessage: String?
    @State private var isStartingQuickBlock = false
    @State private var customHours = 1.0
    @State private var showingCustomDuration = false

    private let quickDurations = [30, 60, 120]

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
        .background(cardBackground)
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
                        stopQuickBlock()
                    } label: {
                        Label("Stop quick block", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("No active quick block right now. Choose a duration below when you want to focus immediately.")
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
            .padding(20)
            .background(cardBackground)
        }
    }

    private var quickBlockCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick Block", systemImage: "bolt.shield.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Uses the apps and websites from your Apps tab. Pick a preset or set your own duration.")
                .foregroundStyle(.white.opacity(0.68))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                ForEach(quickDurations, id: \.self) { minutes in
                    quickDurationButton(minutes: minutes)
                }

                Button {
                    showingCustomDuration = true
                } label: {
                    VStack(spacing: 4) {
                        Text("Custom")
                            .font(.headline)
                        Text("duration")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(GlassButtonStyle())
            }

            Button {
                startQuickBlock(minutes: 60)
            } label: {
                Label("Start 1 hour focus", systemImage: "play.fill")
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
        .background(cardBackground)
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
        .background(cardBackground)
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

                Slider(value: $customHours, in: 0.5...8, step: 0.5)

                Button {
                    startQuickBlock(minutes: Int(customHours * 60))
                    showingCustomDuration = false
                } label: {
                    Label("Start custom block", systemImage: "play.fill")
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

    private func quickDurationButton(minutes: Int) -> some View {
        Button {
            startQuickBlock(minutes: minutes)
        } label: {
            VStack(spacing: 4) {
                Text(durationTitle(minutes))
                    .font(.headline)
                Text("focus")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(GlassButtonStyle())
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
        ScheduleService.shared.stopImmediateBlock()
        activeSession = nil
        quickBlockMessage = "Quick block stopped."
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
