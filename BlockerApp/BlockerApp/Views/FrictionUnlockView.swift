import SwiftUI
import Combine

struct FrictionUnlockView: View {
    let commitmentMode: QuickBlockCommitmentMode
    let remainingEscapeTokens: Int
    let onCancel: () -> Void
    let onComplete: (FrictionUnlockReflection) -> Void

    @State private var remainingSeconds: Int
    @State private var finalRemainingSeconds: Int
    @State private var finalDelayStarted = false
    @State private var blockReason = ""
    @State private var stopReason: FrictionUnlockReason?
    @State private var otherStopReason = ""

    private let timing: FrictionUnlockTiming
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        commitmentMode: QuickBlockCommitmentMode = .normal,
        remainingEscapeTokens: Int = EscapeTokenPolicy.dailyLimit,
        onCancel: @escaping () -> Void,
        onComplete: @escaping (FrictionUnlockReflection) -> Void
    ) {
        self.commitmentMode = commitmentMode
        self.remainingEscapeTokens = remainingEscapeTokens
        self.onCancel = onCancel
        self.onComplete = onComplete
        let timing = FrictionUnlockTiming.forMode(commitmentMode)
        self.timing = timing
        _remainingSeconds = State(initialValue: timing.initialDelaySeconds)
        _finalRemainingSeconds = State(initialValue: timing.finalDelaySeconds)
    }

    private var reflection: FrictionUnlockReflection {
        FrictionUnlockReflection(blockReason: blockReason, stopReason: stopReason, otherStopReason: otherStopReason)
    }

    private var canUseStrongEmergencyExit: Bool {
        commitmentMode == .normal || remainingEscapeTokens > 0
    }

    private var canStartFinalDelay: Bool {
        reflection.isComplete && canUseStrongEmergencyExit
    }

    private var canComplete: Bool {
        canStartFinalDelay && finalDelayStarted && finalRemainingSeconds == 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(spacing: 18) {
                        breathingCard
                        if commitmentMode == .strong { escapeTokenCard }
                        if remainingSeconds == 0 {
                            questionsCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            unlockCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            patienceCard
                        }
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 150)
                }
            }
            .navigationTitle(L10n.string(commitmentMode == .strong ? "Strong exit" : "Pause first"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.string("Keep block")) { onCancel() } } }
        }
        .tint(.orange)
        .animation(.easeInOut(duration: 0.28), value: remainingSeconds == 0)
        .onReceive(timer) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
                if remainingSeconds == 0 { AppHaptics.success() }
            } else if finalDelayStarted && finalRemainingSeconds > 0 {
                finalRemainingSeconds -= 1
                if finalRemainingSeconds == 0 { AppHaptics.success() }
            }
        }
    }

    private var breathingCard: some View {
        let total = max(1, timing.initialDelaySeconds)
        return VStack(spacing: 18) {
            ZStack {
                Circle().stroke(.white.opacity(0.14), lineWidth: 12).frame(width: 150, height: 150)
                Circle().trim(from: 0, to: Double(total - remainingSeconds) / Double(total))
                    .stroke(commitmentMode == .strong ? .yellow : .orange, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 150, height: 150)
                VStack(spacing: 4) {
                    Text("\(remainingSeconds)").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(L10n.string("seconds")).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.68))
                }
            }
            Text(remainingSeconds == 0 ? L10n.string("Now answer honestly.") : L10n.string("Take a slow breath before unlocking."))
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(L10n.string(commitmentMode == .strong ? "Strong Mode gives you one calm emergency exit per day. Use it only when it truly matters." : "Normal blocks ask for a short pause, honest reflection, then one final wait before stopping."))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.74))
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private var escapeTokenCard: some View {
        Label(
            remainingEscapeTokens > 0
                ? String(format: L10n.string("%d emergency exit left today"), remainingEscapeTokens)
                : L10n.string("No emergency exits left today"),
            systemImage: remainingEscapeTokens > 0 ? "ticket.fill" : "lock.fill"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(remainingEscapeTokens > 0 ? .yellow : .red.opacity(0.92))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var patienceCard: some View {
        Label(L10n.string("Questions unlock after the breathing timer."), systemImage: "wind")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassCard(cornerRadius: 26)
    }

    private var questionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("What’s your reason for the block?")).font(.headline).foregroundStyle(.white)
                TextField(L10n.string("Example: Finish deep work, study, sleep"), text: $blockReason, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("Why do you want to stop it?")).font(.headline).foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    ForEach(FrictionUnlockReason.allOptions, id: \.self) { reason in
                        reasonButton(reason)
                    }
                }
                if stopReason == .other {
                    TextField(L10n.string("Write your reason"), text: $otherStopReason, axis: .vertical)
                        .lineLimit(2...3)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !canUseStrongEmergencyExit {
                Text(L10n.string("Strong Mode is locked in for today. This block can finish naturally."))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.9))
            } else if finalDelayStarted && finalRemainingSeconds > 0 {
                Label(String(format: L10n.string("Final check: %d seconds left"), finalRemainingSeconds), systemImage: "hourglass")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            }

            Button(role: .destructive) {
                if !finalDelayStarted {
                    finalDelayStarted = true
                    AppHaptics.warning()
                } else if canComplete {
                    AppHaptics.success()
                    onComplete(reflection)
                }
            } label: {
                Label(L10n.string(finalDelayStarted ? "Unlock and stop block" : "Start final pause"), systemImage: finalDelayStarted ? "lock.open.fill" : "hourglass")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color.orange.opacity(0.96), Color.red.opacity(0.86)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                    .shadow(color: .orange.opacity(0.18), radius: 14, y: 6)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .controlSize(.large)
            .disabled(!canStartFinalDelay || (finalDelayStarted && finalRemainingSeconds > 0))
            .opacity(canStartFinalDelay && !(finalDelayStarted && finalRemainingSeconds > 0) ? 1 : 0.45)

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var statusText: String {
        if !reflection.isComplete { return L10n.string("Answer both questions to unlock the stop button.") }
        if !canUseStrongEmergencyExit { return L10n.string("You have used today’s emergency exit.") }
        if !finalDelayStarted { return L10n.string("One final pause keeps stopping intentional.") }
        if finalRemainingSeconds > 0 { return L10n.string("Stay here for the final check, or keep the block.") }
        return L10n.string(commitmentMode == .strong ? "Use emergency exit and stop block." : "You can stop the block now.")
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }

    private func reasonButton(_ reason: FrictionUnlockReason) -> some View {
        Button {
            stopReason = reason
            AppHaptics.selection()
        } label: {
            Label(L10n.string(reason.title), systemImage: reason.icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .foregroundStyle(stopReason == reason ? .white : .white.opacity(0.78))
                .background(stopReason == reason ? .orange.opacity(0.28) : .white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(stopReason == reason ? .orange.opacity(0.78) : .white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        background(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }
}
