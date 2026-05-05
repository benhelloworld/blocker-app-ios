import Foundation
#if canImport(FamilyControls)
import FamilyControls
#endif

final class ShieldStorage {
    static let shared = ShieldStorage()

    private let defaults: UserDefaults?

    private init(defaults: UserDefaults? = UserDefaults(suiteName: SharedConfig.appGroupIdentifier)) {
        self.defaults = defaults
    }

    func saveSchedule(_ schedule: BlockSchedule) throws {
        let data = try JSONEncoder().encode(schedule)
        defaults?.set(data, forKey: SharedConfig.scheduleKey)
    }

    func loadSchedule() -> BlockSchedule {
        guard let data = defaults?.data(forKey: SharedConfig.scheduleKey),
              let schedule = try? JSONDecoder().decode(BlockSchedule.self, from: data) else {
            return .defaultFocus
        }
        return schedule
    }

    #if canImport(FamilyControls)
    func saveSelection(_ selection: FamilyActivitySelection) throws {
        let data = try JSONEncoder().encode(selection)
        defaults?.set(data, forKey: SharedConfig.shieldSelectionKey)
    }

    func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: SharedConfig.shieldSelectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }
    #endif
}
