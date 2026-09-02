import Foundation
import Combine
#if canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class AuthorizationService: ObservableObject {
    static let shared = AuthorizationService()

    @Published private(set) var isAuthorized = false
    @Published var lastError: String?

    private init() {
        refresh()
    }

    func requestAuthorization() async {
        #if canImport(FamilyControls)
        lastError = nil
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
            if isAuthorized {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
            isAuthorized = false
        }
        #else
        lastError = "FamilyControls is only available on supported Apple platforms."
        #endif
    }

    /// Refreshes the current authorization status without prompting the user.
    func refresh() {
        #if canImport(FamilyControls)
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if isAuthorized {
            lastError = nil
        }
        #endif
    }
}
