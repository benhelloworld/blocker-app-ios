import SwiftUI

struct FocusProgressView: View {
    @State private var stats = ShieldStorage.shared.loadFocusStats()
    @State private var lastReceipt = ShieldStorage.shared.loadLastAccountabilityReceipt()

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                ScrollView {
                    VStack(spacing: 18) { heroCard; lastReceiptCard; metricsCard; streakCard; resetCard }
                        .padding()
                }
            }
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(.cyan)
        .onAppear {
            stats = ShieldStorage.shared.loadFocusStats()
            lastReceipt = ShieldStorage.shared.loadLastAccountabilityReceipt()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus Progress").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("See how many focus sessions you started and build momentum with a simple daily streak.").font(.body).foregroundStyle(.white.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                ZStack {
                    Circle().fill(.cyan.opacity(0.18)).frame(width: 68, height: 68)
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 31, weight: .semibold)).foregroundStyle(.cyan)
                }
            }
            HStack(spacing: 10) {
                statusPill(title: stats.totalSessions == 0 ? "Start first block" : "Momentum building", icon: stats.totalSessions == 0 ? "sparkle" : "flame.fill")
                statusPill(title: "\(stats.currentStreakDays()) day streak", icon: "calendar.badge.checkmark")
            }
        }.padding(22).glassCard(cornerRadius: 28)
    }



    private var lastReceiptCard: some View {
        Group {
            if let lastReceipt {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Accountability Receipt", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text(lastReceipt.headline)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    ForEach(lastReceipt.lines, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassCard(cornerRadius: 26)
            }
        }
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Your totals", systemImage: "number.circle.fill").font(.title2.bold()).foregroundStyle(.white)
            HStack(spacing: 12) {
                metricTile(value: "\(stats.totalSessions)", label: "Sessions", icon: "play.circle.fill")
                metricTile(value: stats.totalHoursLabel, label: "Planned focus", icon: "timer")
                metricTile(value: "\(stats.focusDayCount)", label: "Focus days", icon: "sun.max.fill")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassCard(cornerRadius: 26)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Streak", systemImage: "flame.fill").font(.headline).foregroundStyle(.white)
            Text(streakText).font(.title3.bold()).foregroundStyle(.white)
            Text("A day counts once you start at least one quick block. This keeps it simple and motivating while we build the app out.").font(.subheadline).foregroundStyle(.white.opacity(0.68))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassCard(cornerRadius: 26)
    }

    private var resetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress is saved privately in the app group on your device.").font(.footnote).foregroundStyle(.white.opacity(0.64))
            Button(role: .destructive) { stats = FocusStats(); try? ShieldStorage.shared.saveFocusStats(stats) } label: { Label("Reset progress", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered).disabled(stats.totalSessions == 0)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassCard(cornerRadius: 26)
    }

    private var streakText: String {
        let streak = stats.currentStreakDays()
        if streak == 0 { return "No active streak yet" }
        if streak == 1 { return "1 day in a row" }
        return "\(streak) days in a row"
    }

    private var appBackground: some View { LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.09, green: 0.10, blue: 0.22), Color(red: 0.13, green: 0.09, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() }
    private func statusPill(title: String, icon: String) -> some View { Label(title, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9)).lineLimit(1).padding(.horizontal, 10).padding(.vertical, 7).background(.white.opacity(0.12), in: Capsule()) }
    private func metricTile(value: String, label: String, icon: String) -> some View { VStack(spacing: 7) { Image(systemName: icon).font(.headline).foregroundStyle(.cyan); Text(value).font(.title3.bold()).minimumScaleFactor(0.7).foregroundStyle(.white); Text(label).font(.caption2.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.62)) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1)) }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 26) -> some View { background(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)).overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1)) }
}
