# Implementation Plan

## Phase 1: Compile-ready Xcode skeleton

- Create Xcode project on Mac
- Add main app and Device Activity Monitor Extension
- Add Family Controls + App Groups capabilities
- Wire Swift files into targets

## Phase 2: MVP blocking flow

- Request Screen Time authorization
- Present FamilyActivityPicker
- Persist selections in App Group storage
- Configure DeviceActivitySchedule
- Apply ManagedSettings shields during interval

## Phase 3: Commitment UX

- Daily schedule editor
- Clear status screen
- Warnings before schedule changes take effect
- Safer copy around "harder to bypass" rather than absolute claims

## Phase 4: App Store readiness

- Privacy policy
- Onboarding
- App Store screenshots
- TestFlight
- Review notes explaining Screen Time API use
