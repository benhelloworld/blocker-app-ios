import Foundation
#if canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class AuthorizationService: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published var lastError: String?

    func requestAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            lastError = error.localizedDescription
            isAuthorized = false
        }
        #else
        lastError = "FamilyControls is only available on supported Apple platforms."
        #endif
    }
}
