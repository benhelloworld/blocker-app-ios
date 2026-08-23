import SwiftUI

struct ScheduledBlockActiveOverlay: View {
    let window: ActiveScheduledBlockWindow
    let now: Date

    private var remainingText: String { window.largeRemainingLabel(at: now) }
    private var progress: Double { window.progress(at: now) }
    private var endText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return String(format: L10n.string("Scheduled block ends at %@"), formatter.string(from: window.end))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.002, green: 0.002, blue: 0.004), Color(red: 0.018, green: 0.016, blue: 0.026), Color(red: 0.075, green: 0.052, blue: 0.020)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 30)

                VStack(spacing: 10) {
                    Label(L10n.string("Scheduled focus is active"), systemImage: "lock.shield.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.13), in: Capsule())
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.35), lineWidth: 1))

                    Text(L10n.string("Stay locked in"))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(L10n.string("Your scheduled block is running. AntiScroll stays locked until the window ends."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)

                ZStack {
                    ProgressRing(progress: progress)
                        .frame(width: 232, height: 232)
                        .shadow(color: Color.yellow.opacity(0.25), radius: 30, y: 14)

                    VStack(spacing: 6) {
                        Text(remainingText)
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .minimumScaleFactor(0.52)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                        Text(L10n.string("remaining"))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 12) {
                    Text(L10n.string(ActiveScheduleMotivation.quote(for: now)))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(endText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.yellow.opacity(0.22), lineWidth: 1))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.string("Bypass protection"), systemImage: "hand.raised.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.string("Editing schedules and app lists is disabled while this scheduled block is active. You can change future blocks after the timer finishes."))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.red.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 20)

                Spacer(minLength: 34)
            }
        }
    }
}
