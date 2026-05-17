import SwiftUI

struct StatusView: View {
    @StateObject private var authorization = AuthorizationService()
    @State private var quickBlockMessage: String?
    @State private var isStartingQuickBlock = false

    private let quickDurations = [30, 60, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    heroCard
                    quickBlockCard
                    authorizationCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Status")
        }
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.14))
                    .frame(width: 96, height: 96)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("Blocker App")
                    .font(.largeTitle.bold())

                Text("Choose distractions once, then start a focused block whenever you need it.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }

    private var quickBlockCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Block now", systemImage: "bolt.shield.fill")
                .font(.title2.bold())

            Text("Start an immediate commitment session using your selected apps and websites.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                ForEach(quickDurations, id: \.self) { minutes in
                    Button {
                        startQuickBlock(minutes: minutes)
                    } label: {
                        VStack(spacing: 4) {
                            Text(durationTitle(minutes))
                                .font(.headline)
                            Text("focus")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isStartingQuickBlock)
                }
            }

            if let quickBlockMessage {
                Text(quickBlockMessage)
                    .font(.footnote)
                    .foregroundStyle(quickBlockMessage.localizedCaseInsensitiveContains("failed") ? .red : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var authorizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Screen Time access", systemImage: authorization.isAuthorized ? "checkmark.circle.fill" : "lock.shield")
                .font(.headline)
                .foregroundStyle(authorization.isAuthorized ? .green : .primary)

            Text("Apple requires Screen Time permission before the app can shield selected distractions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func startQuickBlock(minutes: Int) {
        isStartingQuickBlock = true
        defer { isStartingQuickBlock = false }

        do {
            let session = try ScheduleService.shared.startImmediateBlock(durationMinutes: minutes)
            quickBlockMessage = "Started a \(session.durationLabel) block."
        } catch {
            quickBlockMessage = "Block failed: \(error.localizedDescription)"
        }
    }

    private func durationTitle(_ minutes: Int) -> String {
        ImmediateBlockSession(durationMinutes: minutes).durationLabel
    }
}
