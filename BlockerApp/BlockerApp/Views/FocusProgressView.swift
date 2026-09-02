import SwiftUI

struct FocusProgressView: View {
    @EnvironmentObject private var premiumStore: PremiumEntitlementStore
    let onboardingTarget: String?
    let onSelectTab: (String) -> Void

    init(onboardingTarget: String? = nil, onSelectTab: @escaping (String) -> Void = { _ in }) {
        self.onboardingTarget = onboardingTarget
        self.onSelectTab = onSelectTab
    }

    @State private var stats = ShieldStorage.shared.loadFocusStats()
    @State private var scheduledStats = ShieldStorage.shared.loadScheduledFocusStats()
    @State private var lastReceipt = ShieldStorage.shared.loadLastAccountabilityReceipt()

    private var summary: FocusProgressSummary {
        FocusProgressSummary(quickStats: stats, scheduledStats: scheduledStats)
    }

    private var hasData: Bool {
        summary.hasData
    }

    var body: some View {
        Group {
            if premiumStore.isPremium {
                progressContent
            } else {
                PremiumUpsellView(trigger: .advancedFeatures)
            }
        }
        .tint(AppActionStyle.turquoise[0])
        .onAppear {
            stats = ShieldStorage.shared.loadFocusStats()
            scheduledStats = ShieldStorage.shared.loadScheduledFocusStats()
            lastReceipt = ShieldStorage.shared.loadLastAccountabilityReceipt()
        }
    }

    private var progressContent: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(spacing: 18) {
                        if hasData {
                            heroCard
                            metricsCard
                            if let lastReceipt {
                                receiptRow(lastReceipt)
                            }
                        } else {
                            emptyStateCard
                        }
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 150)
                }

                bottomTabScrim
            }
            .navigationTitle(L10n.string("Progress"))
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("Focus Progress")).font(.largeTitle.bold()).foregroundStyle(.white)
                    explanatoryText("Your completed focus sessions, protected time, and momentum.")
                }
                Spacer()
                ZStack {
                    Circle().fill(.mint.opacity(0.18)).frame(width: 68, height: 68)
                    Circle().stroke(.mint.opacity(0.55), lineWidth: 1).frame(width: 68, height: 68)
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 31, weight: .semibold)).foregroundStyle(.mint)
                }
            }
        }.padding(22).glassCard(cornerRadius: 28)
    }

    // MARK: - Metrics first: focus time, sessions, streak

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.string("Your focus"), systemImage: "number.circle.fill").font(.title2.bold()).foregroundStyle(.white)
            VStack(spacing: 10) {
                metricRow(value: summary.totalHoursLabel, label: L10n.string("Focus time"), icon: "timer")
                metricRow(value: summary.scheduledHoursLabel, label: L10n.string("Scheduled focus"), icon: "calendar.badge.clock")
                metricRow(value: "\(summary.completedSessions)", label: L10n.string("Completed sessions"), icon: "checkmark.circle.fill")
                metricRow(value: streakValue, label: L10n.string("Streak"), icon: "flame.fill")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassCard(cornerRadius: 26)
        .id("Progress")
        .onboardingHighlight("Progress")
    }

    private func receiptRow(_ receipt: AccountabilityReceipt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                Text(L10n.string("Last session"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
            }
            Text(receipt.headline)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Empty state

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .fill(.mint.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.mint)
            }

            Text(L10n.string("No focus sessions yet"))
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(L10n.string("Your completed sessions, focus time, and streak will show up here."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onSelectTab("Status")
            } label: {
                Label(L10n.string("Start your first focus session"), systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .background(
                LinearGradient(colors: AppActionStyle.turquoise, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
            .shadow(color: AppActionStyle.turquoise[0].opacity(0.24), radius: 16, y: 7)
            .accessibilityIdentifier("start-first-focus-button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .glassCard(cornerRadius: 28)
        .id("Progress")
        .onboardingHighlight("Progress")
    }

    private func explanatoryText(_ copy: String) -> some View {
        Text(L10n.string(copy))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.66))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var streakValue: String {
        "\(summary.currentStreakDays())"
    }

    private var appBackground: some View { LinearGradient(colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.045, green: 0.034, blue: 0.070)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() }

    private func metricRow(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppActionStyle.turquoise[0])
                .frame(width: 38, height: 38)
                .background(AppActionStyle.turquoise[0].opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        background(
            LinearGradient(
                colors: [.white.opacity(0.13), .white.opacity(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.mint.opacity(0.12), lineWidth: 1)
        )
    }
}
