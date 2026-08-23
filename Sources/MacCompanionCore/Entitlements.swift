import Foundation
import Security

public enum MacCompanionEntitlements {
    public static func iCloudContainerIdentifiers() -> [String] {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil) else {
            return []
        }
        return value as? [String] ?? []
    }

    public static var hasICloudContainer: Bool {
        !iCloudContainerIdentifiers().isEmpty
    }
}
