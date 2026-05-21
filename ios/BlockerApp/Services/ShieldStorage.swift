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

    func saveActiveImmediateSession(_ session: ImmediateBlockSession) throws {
        let data = try JSONEncoder().encode(session)
        defaults?.set(data, forKey: SharedConfig.activeImmediateSessionKey)
    }

    func loadActiveImmediateSession(now: Date = Date()) -> ImmediateBlockSession? {
        guard let data = defaults?.data(forKey: SharedConfig.activeImmediateSessionKey),
              let session = try? JSONDecoder().decode(ImmediateBlockSession.self, from: data) else {
            return nil
        }

        if session.isActive(at: now) {
            return session
        }

        defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
        return nil
    }

    func clearActiveImmediateSession() {
        defaults?.removeObject(forKey: SharedConfig.activeImmediateSessionKey)
    }


    func saveFocusStats(_ stats: FocusStats) throws {
        let data = try JSONEncoder().encode(stats)
        defaults?.set(data, forKey: SharedConfig.focusStatsKey)
    }

    func loadFocusStats() -> FocusStats {
        guard let data = defaults?.data(forKey: SharedConfig.focusStatsKey),
              let stats = try? JSONDecoder().decode(FocusStats.self, from: data) else {
            return FocusStats()
        }
        return stats
    }


    func recordFrictionUnlock(_ reflection: FrictionUnlockReflection) throws {
        var history = loadFrictionUnlockHistory()
        history.append(reflection)
        let data = try JSONEncoder().encode(history)
        defaults?.set(data, forKey: SharedConfig.frictionUnlockHistoryKey)
    }

    func loadFrictionUnlockHistory() -> [FrictionUnlockReflection] {
        guard let data = defaults?.data(forKey: SharedConfig.frictionUnlockHistoryKey),
              let history = try? JSONDecoder().decode([FrictionUnlockReflection].self, from: data) else {
            return []
        }
        return history
    }


    func saveAccountabilityReceipt(_ receipt: AccountabilityReceipt) throws {
        let data = try JSONEncoder().encode(receipt)
        defaults?.set(data, forKey: SharedConfig.lastAccountabilityReceiptKey)
    }

    func loadLastAccountabilityReceipt() -> AccountabilityReceipt? {
        guard let data = defaults?.data(forKey: SharedConfig.lastAccountabilityReceiptKey) else { return nil }
        return try? JSONDecoder().decode(AccountabilityReceipt.self, from: data)
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
