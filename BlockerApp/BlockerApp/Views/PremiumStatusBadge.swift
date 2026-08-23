import SwiftUI

struct PremiumStatusBadge: View {
    let isPremium: Bool

    private var badgeFill: AnyShapeStyle {
        if isPremium {
            return AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    var body: some View {
        Label(isPremium ? L10n.string("PREMIUM") : L10n.string("FREE"), systemImage: isPremium ? "crown.fill" : "lock.open.fill")
            .font(.caption2.weight(.black))
            .foregroundStyle(isPremium ? .black : .white.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(badgeFill, in: Capsule())
            .overlay(Capsule().stroke(isPremium ? .white.opacity(0.32) : .white.opacity(0.18), lineWidth: 1))
            .accessibilityLabel(isPremium ? L10n.string("Premium user") : L10n.string("Free user"))
            .accessibilityIdentifier(isPremium ? "premium-status-badge" : "free-status-badge")
    }
}
