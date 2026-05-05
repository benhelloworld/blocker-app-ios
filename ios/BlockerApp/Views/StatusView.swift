import SwiftUI

struct StatusView: View {
    @StateObject private var authorization = AuthorizationService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("Blocker App")
                    .font(.largeTitle.bold())

                Text("Create a daily commitment window that makes distracting apps harder to access.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Allow Screen Time Access") {
                    Task { await authorization.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)

                if authorization.isAuthorized {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let error = authorization.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Status")
        }
    }
}
