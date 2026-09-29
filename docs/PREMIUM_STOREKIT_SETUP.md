# Premium / StoreKit setup

Current product ID used by the app and local StoreKit file:

- `com.benberther.BlockerApp.premium`
- Type: Non-Consumable
- Reference name: `Blocker Premium Lifetime`

## Current implementation state

- `PremiumEntitlementStore` contains the real StoreKit path (`Product.products`, `purchase()`, `Transaction.currentEntitlements`, `Transaction.updates`, and `AppStore.sync()`).
- Debug builds use a local simulated unlock so Premium UX can be tested before App Store Connect is fully configured.
- Release/App Store builds automatically use real StoreKit; the fake unlock is not the UI path in Release.
- Local StoreKit testing config lives at `BlockerPremium.storekit` in the canonical Xcode project.

## App Store Connect step

Create one in-app purchase with exactly this Product ID:

`com.benberther.BlockerApp.premium`

Use **Non-Consumable** unless you decide later to make Premium a subscription. If you change the Product ID in App Store Connect, update `PremiumAccessPolicy.premiumProductID` in both the Xcode app source and mirrored package source, plus the `.storekit` file.
