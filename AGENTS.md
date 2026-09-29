# AntiScroll Engineering Rules

## Repository layout

This repository is the sole source of truth. The root `BlockerApp.xcodeproj` and `BlockerApp/BlockerApp/` contain the live iOS app. Do not recreate an `ios/` mirror or copy Swift files into another project tree. The Swift package at `Package.swift` contains shared/Mac companion code and is intentionally separate from the Xcode target source.

## Screen Time invariants

- Treat FamilyControls authorization, DeviceActivity registration, ManagedSettings assignment, verification, and persisted UI state as one transaction.
- Never show a block or template as active until enforcement state has been verified.
- Keep immediate and scheduled enforcement in separate named `ManagedSettingsStore` instances.
- DeviceActivity callbacks must dispatch by activity identity and must not apply a stale selection belonging to another blocking source.
- Preserve App Group persistence and app/extension separation.
- Commitment-locked sessions may add targets but must not remove active targets before completion.
- Simulator builds cannot prove physical Screen Time enforcement; provide a real-device checklist for those changes.

## Product and UI

- Preserve the premium dark/black-gold AntiScroll brand, rounded cards, and existing features.
- Use turquoise for primary/active UI; reserve yellow/orange mainly for Premium, warnings, and strong blocking.
- Keep copy calm, clear, localized, and non-shaming.
- Use “AntiScroll Mac Companion,” never “Mac extension.”
- Avoid large redesigns unless explicitly approved.

## Localization

Localize changed user-facing copy in every supported `.lproj` directory. Preserve format placeholders exactly and validate all `.strings` files with `plutil -lint`. Check German and Spanish wording, small iPhones, Dynamic Type, and right-to-left languages when layout changes.

## Verification

For source changes:

1. Inspect the diff for secrets and unrelated changes.
2. Build the complete `BlockerApp` scheme.
3. Run targeted unit tests and appropriate broader tests.
4. Run `swift test` when shared/Mac companion code changes.
5. Verify all Screen Time extension targets compile.
6. Report baseline/pre-existing failures separately from new regressions.

Do not push, upload, submit, publish, or perform account verification without Ben’s approval.
