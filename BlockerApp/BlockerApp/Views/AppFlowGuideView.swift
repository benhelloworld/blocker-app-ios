import SwiftUI

struct CoreFlowCard: View {
    let currentTab: String
    let headline: String
    let subtitle: String
    let onSelectTab: ((String) -> Void)?

    init(currentTab: String, headline: String = "How Blocker works", subtitle: String = "A simple flow: choose what to protect, start a block, automate it, then review your progress.", onSelectTab: ((String) -> Void)? = nil) {
        self.currentTab = currentTab
        self.headline = headline
        self.subtitle = subtitle
        self.onSelectTab = onSelectTab
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(headline, systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(CoreFlowStep.all) { step in
                    flowRow(step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [.white.opacity(0.13), .white.opacity(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.yellow.opacity(0.10), lineWidth: 1)
        )
    }

    private func flowRow(_ step: CoreFlowStep) -> some View {
        Group {
            if let onSelectTab {
                Button {
                    onSelectTab(step.tabName)
                } label: {
                    flowRowContent(step)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(step.tabName) tab")
                .accessibilityHint("Switches to the \(step.tabName) tab")
            } else {
                flowRowContent(step)
            }
        }
    }

    private func flowRowContent(_ step: CoreFlowStep) -> some View {
        let isCurrent = step.tabName == currentTab
        let accent = color(named: step.accentName)
        let isTappable = onSelectTab != nil

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isCurrent ? 0.22 : 0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: step.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(L10n.string(step.tabName))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                    if isCurrent {
                        Text(L10n.string("Current"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.yellow.opacity(0.92), in: Capsule())
                    }
                }
                Text(L10n.string(step.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(L10n.string(step.message))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isTappable {
                Image(systemName: isCurrent ? "checkmark.circle.fill" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isCurrent ? accent : .white.opacity(0.42))
                    .padding(.top, 9)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(isCurrent ? 0.12 : 0.07))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.opacity(isCurrent ? 0.10 : 0.04))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCurrent ? accent.opacity(0.45) : .white.opacity(0.10), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func color(named name: String) -> Color {
        switch name {
        case "mint": return .mint
        case "yellow", "gold": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "blue": return .blue
        default: return .white
        }
    }
}


struct FeatureGuideStep: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
    let accent: Color
}

struct FeatureOnboardingCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let steps: [FeatureGuideStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 50, height: 50)
                    Circle()
                        .stroke(accent.opacity(0.45), lineWidth: 1)
                        .frame(width: 50, height: 50)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow)
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    guideStepRow(number: index + 1, step: step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [.white.opacity(0.13), .white.opacity(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }

    private func guideStepRow(number: Int, step: FeatureGuideStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(step.accent.opacity(0.18))
                    .frame(width: 34, height: 34)
                Text("\(number)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(step.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: step.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(step.accent)
                    Text(L10n.string(step.title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Text(L10n.string(step.message))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.07))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(step.accent.opacity(0.04))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(step.accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct PermissionExplanationRows: View {
    let explainer: ScreenTimePermissionExplainer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(explainer.subtitle))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(explainer.bullets, id: \.self) { bullet in
                Label(L10n.string(bullet), systemImage: bullet.contains("cannot") ? "eye.slash.fill" : "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(L10n.string(explainer.privacyLine), systemImage: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.yellow.opacity(0.26), lineWidth: 1))
        }
    }
}
