import Combine
import Foundation
import StoreKit

struct PremiumSubscriptionPlan: Identifiable, Hashable {
  let productID: String
  let titleKey: String
  let fallbackPriceKey: String
  let detailKey: String
  let isBestValue: Bool

  var id: String { productID }

  static let monthly = PremiumSubscriptionPlan(
    productID: "focusblocker.premium_monthly",
    titleKey: "Monthly",
    fallbackPriceKey: "€2/month",
    detailKey: "Flexible monthly access",
    isBestValue: false
  )

  static let yearly = PremiumSubscriptionPlan(
    productID: "focusblocker.premium.yearly",
    titleKey: "Yearly",
    fallbackPriceKey: "€20/year",
    detailKey: "Save compared with monthly",
    isBestValue: true
  )

  static let all: [PremiumSubscriptionPlan] = [.monthly, .yearly]
  static let productIDs = all.map(\.productID)

  static func plan(for productID: String) -> PremiumSubscriptionPlan? {
    all.first { $0.productID == productID }
  }
}

private enum PremiumBetaAccess {
  static let productID = PremiumSubscriptionPlan.yearly.productID

  static var isEnabled: Bool {
    #if DEBUG
      // Local Xcode runs stay Premium so locked features can be tested quickly.
      // TestFlight, App Review, and App Store builds must use verified StoreKit
      // entitlements so the real paywall/subscription flow can be tested.
      return true
    #else
      return false
    #endif
  }
}

enum PremiumSubscriptionEntitlementPolicy {
  static func isActive(
    productID: String, expirationDate: Date?, revocationDate: Date?, now: Date = Date()
  ) -> Bool {
    guard PremiumSubscriptionPlan.productIDs.contains(productID) else { return false }
    guard revocationDate == nil else { return false }
    guard let expirationDate else { return false }
    return expirationDate > now
  }
}

@MainActor
final class PremiumEntitlementStore: ObservableObject {
  typealias SubscriptionManager = PremiumEntitlementStore

  enum PurchaseState: Equatable {
    case idle
    case loadingProducts
    case purchasing
    case restoring
    case success
    case cancelled
    case pending
    case failed
  }

  @Published private(set) var isPremium: Bool
  @Published private(set) var activeProductID: String?
  @Published private(set) var products: [Product] = []
  @Published var selectedPlan: PremiumSubscriptionPlan
  @Published var isLoading = false
  @Published var message: String?
  @Published private(set) var purchaseState: PurchaseState = .idle

  private var transactionUpdatesTask: Task<Void, Never>?

  init(startListeningForTransactions: Bool = true, automaticallyRefresh: Bool = true) {
    // Real Premium access is never sourced from UserDefaults. It starts locked
    // until StoreKit currentEntitlements confirms an active subscription.
    let betaPremiumAccessEnabled = PremiumBetaAccess.isEnabled

    self.isPremium = betaPremiumAccessEnabled
    self.activeProductID = betaPremiumAccessEnabled ? PremiumBetaAccess.productID : nil
    self.selectedPlan = .yearly
    ShieldStorage.shared.savePremiumStatus(betaPremiumAccessEnabled)

    if startListeningForTransactions {
      self.transactionUpdatesTask = listenForTransactionUpdates()
    }

    if automaticallyRefresh {
      Task {
        await loadProducts()
        await refreshPremiumStatus()
      }
    }
  }

  deinit {
    transactionUpdatesTask?.cancel()
  }

  var statusTitle: String {
    isPremium ? L10n.string("Premium") : L10n.string("Free")
  }

  var statusSubtitle: String {
    isPremium ? L10n.string("All focus tools unlocked") : L10n.string("Quick Block up to 2h")
  }

  var selectedProduct: Product? {
    product(for: selectedPlan)
  }

  var activePlan: PremiumSubscriptionPlan? {
    activeProductID.flatMap(PremiumSubscriptionPlan.plan(for:))
  }

  var isSelectedPlanActive: Bool {
    activeProductID == selectedPlan.productID
  }

  var purchaseButtonTitle: String {
    if isSelectedPlanActive { return L10n.string("Current Plan") }
    if isPremium { return L10n.string("Switch Plan") }
    return L10n.string("Continue")
  }

  var purchaseSubtitle: String {
    if isSelectedPlanActive { return L10n.string("This is your active plan.") }
    if isPremium { return L10n.string("Switch to the selected plan.") }
    if products.isEmpty { return isLoading ? L10n.string("Loading subscription options…") : L10n.string("Subscription options unavailable") }
    return selectedProduct?.displayPrice ?? L10n.string(selectedPlan.fallbackPriceKey)
  }

  func product(for plan: PremiumSubscriptionPlan) -> Product? {
    products.first { $0.id == plan.productID }
  }

  func displayPrice(for plan: PremiumSubscriptionPlan) -> String {
    product(for: plan)?.displayPrice ?? L10n.string(plan.fallbackPriceKey)
  }

  func select(_ plan: PremiumSubscriptionPlan) {
    selectedPlan = plan
  }

  func loadProducts() async {
    guard !PremiumBetaAccess.isEnabled else {
      purchaseState = .success
      message = nil
      setPremiumFromStoreKit(PremiumBetaAccess.productID)
      return
    }

    guard products.isEmpty else { return }
    isLoading = true
    purchaseState = .loadingProducts
    defer {
      isLoading = false
      if purchaseState == .loadingProducts { purchaseState = .idle }
    }

    do {
      let fetched = try await Product.products(for: PremiumSubscriptionPlan.productIDs)
      products = fetched.sorted { lhs, rhs in
        (PremiumSubscriptionPlan.productIDs.firstIndex(of: lhs.id) ?? Int.max)
          < (PremiumSubscriptionPlan.productIDs.firstIndex(of: rhs.id) ?? Int.max)
      }
      if products.isEmpty {
        purchaseState = .failed
        message = L10n.string("Subscription options unavailable")
      } else if selectedProduct == nil, let firstProduct = products.first,
        let plan = PremiumSubscriptionPlan.plan(for: firstProduct.id)
      {
        selectedPlan = plan
      }
    } catch {
      purchaseState = .failed
      message = localizedStoreKitError(prefixKey: "Could not load subscriptions.", error: error)
    }
  }

  func purchaseSelectedPlan() async {
    guard !PremiumBetaAccess.isEnabled else {
      setPremiumFromStoreKit(PremiumBetaAccess.productID)
      purchaseState = .success
      message = L10n.string("Premium unlocked.")
      return
    }

    guard !isSelectedPlanActive else {
      message = L10n.string("This is your active plan.")
      return
    }

    if products.isEmpty { await loadProducts() }

    guard let product = selectedProduct else {
      purchaseState = .failed
      message = L10n.string("Subscription options unavailable")
      return
    }

    isLoading = true
    purchaseState = .purchasing
    defer { isLoading = false }

    do {
      let result = try await product.purchase()
      switch result {
      case .success(let verification):
        guard case .verified(let transaction) = verification else {
          purchaseState = .failed
          message = L10n.string("Purchase could not be verified.")
          return
        }
        setPremiumFromStoreKit(transaction.productID)
        await transaction.finish()
        if isPremium {
          purchaseState = .success
          message = L10n.string("Premium unlocked.")
        } else {
          purchaseState = .failed
          message = L10n.string(
            "We could not confirm an active subscription yet. Please try Restore Purchases.")
        }
      case .userCancelled:
        purchaseState = .cancelled
        message = L10n.string("Purchase cancelled.")
      case .pending:
        purchaseState = .pending
        message = L10n.string("Purchase pending approval.")
      @unknown default:
        purchaseState = .failed
        message = L10n.string("Purchase status changed. Please try Restore Purchases.")
      }
    } catch {
      purchaseState = .failed
      message = localizedStoreKitError(prefixKey: "Purchase failed.", error: error)
    }
  }

  func restorePurchases() async {
    guard !PremiumBetaAccess.isEnabled else {
      setPremiumFromStoreKit(PremiumBetaAccess.productID)
      purchaseState = .success
      message = L10n.string("Premium restored.")
      return
    }

    isLoading = true
    purchaseState = .restoring
    defer { isLoading = false }

    do {
      try await AppStore.sync()
      await refreshPremiumStatus()
      purchaseState = isPremium ? .success : .idle
      message =
        isPremium
        ? L10n.string("Premium restored.") : L10n.string("No active Premium subscription found.")
    } catch {
      purchaseState = .failed
      message = localizedStoreKitError(prefixKey: "Restore failed.", error: error)
    }
  }

  func refreshPremiumStatus() async {
    guard !PremiumBetaAccess.isEnabled else {
      setPremiumFromStoreKit(PremiumBetaAccess.productID)
      return
    }

    var activeEntitlementProductID: String?
    let now = Date()

    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else { continue }
      if PremiumSubscriptionEntitlementPolicy.isActive(
        productID: transaction.productID,
        expirationDate: transaction.expirationDate,
        revocationDate: transaction.revocationDate,
        now: now
      ) {
        activeEntitlementProductID = transaction.productID
        break
      }
    }

    setPremiumFromStoreKit(activeEntitlementProductID)
  }

  // Backwards-compatible entry point used by existing buttons.
  func purchasePremium() async {
    await purchaseSelectedPlan()
  }

  @available(*, unavailable, message: "Premium now requires a verified StoreKit subscription.")
  func unlockPremiumForSimulatorTesting() {}

  @available(*, unavailable, message: "Premium now requires a verified StoreKit subscription.")
  func unlockPremiumForTesting() {}

  private func setPremiumFromStoreKit(_ productID: String?) {
    activeProductID = productID
    isPremium = productID != nil
    if let productID, PremiumSubscriptionPlan.productIDs.contains(productID) {
      selectedPlan = PremiumSubscriptionPlan.plan(for: productID) ?? selectedPlan
    }
    // Cache only mirrors verified StoreKit state for UI/background convenience.
    // It is not used as the source of truth by this manager.
    ShieldStorage.shared.savePremiumStatus(isPremium)
  }

  private func listenForTransactionUpdates() -> Task<Void, Never> {
    Task { [weak self] in
      for await result in Transaction.updates {
        guard case .verified(let transaction) = result else { continue }
        guard PremiumSubscriptionPlan.productIDs.contains(transaction.productID) else { continue }
        await transaction.finish()
        await self?.refreshPremiumStatus()
        await MainActor.run {
          if self?.isPremium == true {
            self?.purchaseState = .success
            self?.message = L10n.string("Premium unlocked.")
          }
        }
      }
    }
  }

  private func localizedStoreKitError(prefixKey: String, error: Error) -> String {
    let prefix = L10n.string(prefixKey)
    return String(format: L10n.string("%@ Please try again or restore purchases."), prefix)
  }
}
