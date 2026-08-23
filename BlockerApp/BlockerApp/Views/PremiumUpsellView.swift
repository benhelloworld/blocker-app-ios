import SwiftUI

struct PremiumUpsellView: View {
    enum Trigger {
        case quickBlockLimit
        case scheduledBlocking
        case recurringBlocks
        case advancedFeatures

        var headline: String {
            switch self {
            case .quickBlockLimit: return L10n.string("Unlock longer Quick Blocks")
            case .scheduledBlocking: return L10n.string("Schedule is Premium")
            case .recurringBlocks: return L10n.string("Recurring blocks are Premium")
            case .advancedFeatures: return L10n.string("Unlock Premium Focus")
            }
        }

        var subtitle: String {
            switch self {
            case .quickBlockLimit: return L10n.string("Free Quick Blocks are capped at 2 hours. Premium removes the limit.")
            case .scheduledBlocking: return L10n.string("Build automatic focus windows instead of starting every block manually.")
            case .recurringBlocks: return L10n.string("Repeat your focus sessions across the week with less effort.")
            case .advancedFeatures: return L10n.string("Use the full blocking system for deeper, long-term focus control.")
            }
        }

        var contextTitle: String {
            switch self {
            case .scheduledBlocking: return L10n.string("What unlocks after Premium")
            case .quickBlockLimit: return L10n.string("What changes after Premium")
            case .recurringBlocks, .advancedFeatures: return L10n.string("Premium tools you unlock")
            }
        }

        var contextBullets: [String] {
            switch self {
            case .scheduledBlocking:
                return [
                    "Create named app lists for schedules.",
                    "Pick recurring days and time windows.",
                    "Show an active scheduled-block timer when protection is running."
                ]
            case .quickBlockLimit:
                return [
                    "Use Quick Blocks longer than 2 hours.",
                    "Keep active blocks commitment-locked.",
                    "Combine Quick Block with stronger weekly routines."
                ]
            case .recurringBlocks, .advancedFeatures:
                return [
                    "Build recurring focus routines.",
                    "Track long-term focus progress.",
                    "Use delay tools and templates for calmer control."
                ]
            }
        }
    }

    let trigger: Trigger
    var onClose: (() -> Void)? = nil

    @EnvironmentObject private var premiumStore: PremiumEntitlementStore

    var body: some View {
        NavigationStack {
            ZStack {
                premiumBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        planPickerCard
                        purchaseCard
                        contextCard
                        benefitsCard
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 32)
                }
            }
            .navigationTitle(L10n.string("Premium"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.string("Maybe Later")) { onClose() }
                    }
                }
            }
            .task {
                await premiumStore.loadProducts()
                await premiumStore.refreshPremiumStatus()
            }
            .onChange(of: premiumStore.isPremium) { _, isPremium in
                if isPremium { onClose?() }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var premiumBackground: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.020, green: 0.017, blue: 0.028), Color(red: 0.074, green: 0.048, blue: 0.080)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(trigger.headline)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text(trigger.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                    Text(L10n.string("Build focus routines that work on your terms."))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .padding(.top, 4)
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 68, height: 68)
                    .background(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .shadow(color: .yellow.opacity(0.32), radius: 18, y: 8)
            }
        }
        .padding(22)
        .premiumGlassCard()
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(trigger.contextTitle, systemImage: "lock.open.fill")
                .font(.headline.bold())
                .foregroundStyle(.white)

            ForEach(trigger.contextBullets, id: \.self) { bullet in
                Label(L10n.string(bullet), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .premiumGlassCard()
        .accessibilityIdentifier("premium-context-card")
    }

    private var planPickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("Choose your plan"))
                .font(.title2.bold())
                .foregroundStyle(.white)

            ForEach(PremiumSubscriptionPlan.all) { plan in
                Button {
                    premiumStore.select(plan)
                    AppHaptics.selection()
                } label: {
                    subscriptionPlanRow(plan)
                }
                .buttonStyle(PremiumPressButtonStyle())
                .accessibilityIdentifier(plan.isBestValue ? "premium-yearly-plan" : "premium-monthly-plan")
            }
        }
        .padding(20)
        .premiumGlassCard()
    }

    private func subscriptionPlanRow(_ plan: PremiumSubscriptionPlan) -> some View {
        let isSelected = premiumStore.selectedPlan == plan
        return HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? .yellow : .white.opacity(0.55))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(L10n.string(plan.titleKey))
                        .font(.headline)
                        .foregroundStyle(.white)
                    if plan.isBestValue {
                        Text(L10n.string("Best value"))
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.yellow, in: Capsule())
                    }
                }
                Text(L10n.string(plan.detailKey))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            Text(premiumStore.displayPrice(for: plan))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(isSelected ? .yellow.opacity(0.16) : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? .yellow.opacity(0.70) : .white.opacity(0.12), lineWidth: 1))
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.string("What Premium includes"), systemImage: "sparkles")
                .font(.title2.bold())
                .foregroundStyle(.white)

            premiumBenefit(L10n.string("Unlimited Quick Block duration"), icon: "infinity")
            premiumBenefit(L10n.string("Scheduled focus blocks"), icon: "calendar.badge.shield")
            premiumBenefit(L10n.string("Recurring focus routines"), icon: "repeat")
            premiumBenefit(L10n.string("Stronger long-term focus control"), icon: "chart.line.uptrend.xyaxis")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .premiumGlassCard()
    }

    private var purchaseStatusBadge: some View {
        Label(premiumStore.isPremium ? L10n.string("ACTIVE") : L10n.string("SUBSCRIPTION"), systemImage: premiumStore.isPremium ? "checkmark.seal.fill" : "creditcard.fill")
            .font(.caption2.weight(.black))
            .foregroundStyle(premiumStore.isPremium ? .black : .white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                premiumStore.isPremium
                    ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.white.opacity(0.10)),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
    }


    private var purchaseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.string("AntiScroll Premium"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(premiumStore.purchaseSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                }
                Spacer()
                purchaseStatusBadge
            }
            Button {
                Task { await premiumStore.purchaseSelectedPlan() }
            } label: {
                HStack {
                    if premiumStore.isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "crown.fill")
                    }
                    Text(premiumStore.isLoading ? L10n.string("Loading…") : premiumStore.purchaseButtonTitle)
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(red: 1.00, green: 0.78, blue: 0.22), Color(red: 0.93, green: 0.58, blue: 0.10), Color(red: 0.70, green: 0.40, blue: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.30), lineWidth: 1))
                .shadow(color: .yellow.opacity(0.24), radius: 16, y: 7)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .accessibilityIdentifier("premium-subscribe-button")
            .disabled(premiumStore.isLoading || premiumStore.isSelectedPlanActive)

            legalLinks

            HStack(spacing: 10) {
                Button {
                    Task { await premiumStore.restorePurchases() }
                } label: {
                    Label(L10n.string("Restore Purchases"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PremiumPressButtonStyle())
                .accessibilityIdentifier("premium-restore-button")
                .disabled(premiumStore.isLoading)

                if let onClose {
                    Button {
                        onClose()
                    } label: {
                        Text(L10n.string("Maybe Later"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                    .accessibilityIdentifier("premium-maybe-later-button")
                }
            }

            if let message = premiumStore.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(messageColor)
                    .accessibilityIdentifier("premium-message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .premiumGlassCard()
    }



    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("Subscription renews automatically unless cancelled at least 24 hours before the end of the current period."))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    Label(L10n.string("Terms of Use"), systemImage: "doc.text")
                }
                .accessibilityIdentifier("premium-terms-link")

                Link(destination: URL(string: "https://benhelloworld.github.io/antiscroll-support/")!) {
                    Label(L10n.string("Privacy Policy"), systemImage: "hand.raised")
                }
                .accessibilityIdentifier("premium-privacy-link")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.yellow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
        .accessibilityIdentifier("premium-legal-links")
    }

    private var messageColor: Color {
        switch premiumStore.purchaseState {
        case .failed: return .orange
        case .success: return .green
        case .cancelled, .pending, .idle, .loadingProducts, .purchasing, .restoring: return .white.opacity(0.72)
        }
    }

    private func premiumBenefit(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.yellow)
                .frame(width: 34, height: 34)
                .background(.yellow.opacity(0.14), in: Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

private extension View {
    func premiumGlassCard(cornerRadius: CGFloat = 26) -> some View {
        background(
            LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.yellow.opacity(0.20), lineWidth: 1))
    }
}
