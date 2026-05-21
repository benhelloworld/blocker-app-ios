import SwiftUI
import Combine

struct FrictionUnlockView: View {
    let onCancel: () -> Void
    let onComplete: (FrictionUnlockReflection) -> Void

    @State private var remainingSeconds = 30
    @State private var blockReason = ""
    @State private var stopReason: FrictionUnlockReason?
    @State private var otherStopReason = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var reflection: FrictionUnlockReflection {
        FrictionUnlockReflection(blockReason: blockReason, stopReason: stopReason, otherStopReason: otherStopReason)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(spacing: 18) {
                        breathingCard
                        if remainingSeconds == 0 {
                            questionsCard
                            unlockCard
                        } else {
                            patienceCard
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pause first")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep block") { onCancel() } } }
        }
        .tint(.cyan)
        .onReceive(timer) { _ in
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
        }
    }

    private var breathingCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(.white.opacity(0.14), lineWidth: 12).frame(width: 150, height: 150)
                Circle().trim(from: 0, to: Double(30 - remainingSeconds) / 30.0)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 150, height: 150)
                VStack(spacing: 4) {
                    Text("\(remainingSeconds)").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("seconds").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.62))
                }
            }
            Text(remainingSeconds == 0 ? "Now answer honestly." : "Take a slow breath before unlocking.")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("This short pause adds friction so stopping a block is intentional, not automatic.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private var patienceCard: some View {
        Label("Questions unlock after the breathing timer.", systemImage: "wind")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassCard(cornerRadius: 26)
    }

    private var questionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What’s your reason for the block?").font(.headline).foregroundStyle(.white)
                TextField("Example: Finish deep work, study, sleep", text: $blockReason, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Why do you want to stop it?").font(.headline).foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    ForEach(FrictionUnlockReason.allOptions, id: \.self) { reason in
                        reasonButton(reason)
                    }
                }
                if stopReason == .other {
                    TextField("Write your reason", text: $otherStopReason, axis: .vertical)
                        .lineLimit(2...3)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(role: .destructive) { onComplete(reflection) } label: {
                Label("Unlock and stop block", systemImage: "lock.open.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!reflection.isComplete)

            Text(reflection.isComplete ? "You can stop the block now." : "Answer both questions to unlock the stop button.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.09, green: 0.10, blue: 0.22), Color(red: 0.13, green: 0.09, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }

    private func reasonButton(_ reason: FrictionUnlockReason) -> some View {
        Button { stopReason = reason } label: {
            Label(reason.title, systemImage: reason.icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .foregroundStyle(stopReason == reason ? .white : .white.opacity(0.78))
                .background(stopReason == reason ? .cyan.opacity(0.30) : .white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(stopReason == reason ? .cyan.opacity(0.78) : .white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        background(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }
}
