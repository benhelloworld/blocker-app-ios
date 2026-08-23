# AntiScroll

AntiScroll is an iOS app and Mac companion for intentional app and website blocking. The iOS app uses Apple’s FamilyControls, ManagedSettings, and DeviceActivity frameworks.

## Canonical source of truth

A clone of this repository is the complete source of truth. Open `BlockerApp.xcodeproj` from that same clone; do not create or maintain a second copied Swift/Xcode tree. If a historical path is needed, make it a symlink to the clone.

- Xcode project: `BlockerApp.xcodeproj`
- iOS app: `BlockerApp/BlockerApp/`
- Screen Time extensions: `BlockerMonitorExtension/`, `BlockerShieldActionExtension/`, `BlockerShieldConfigurationExtension/`, and `BlockerAppReportExtension/`
- iOS tests: `BlockerAppTests/` and `BlockerAppUITests/`
- Mac companion package: `Package.swift`, `Sources/`, and `Tests/`

The compatibility Desktop path used on the primary development Mac points to this repository. It is a symlink, never a second editable copy.

## Build and test

```bash
xcodebuild build \
  -project BlockerApp.xcodeproj \
  -scheme BlockerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project BlockerApp.xcodeproj \
  -scheme BlockerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

swift test
```

FamilyControls and real Screen Time shield behavior require a signed build on a physical iPhone; simulator success does not replace real-device verification.

## Git workflow

1. Start from a clean `main` branch.
2. Create one branch per change.
3. Keep changes scoped and review the diff.
4. Build and run targeted tests before committing.
5. Validate every edited `Localizable.strings` file.
6. Push, upload, submit, or change external accounts only with Ben’s approval.

## Product safety language

Do not claim AntiScroll is “impossible to bypass.” Prefer truthful language such as “harder to bypass,” “commitment-focused,” and “built with Apple’s Screen Time framework.”
