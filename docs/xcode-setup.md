# Xcode Setup Notes

## Required capabilities

Main app:
- Family Controls
- App Groups

Device Activity Monitor Extension:
- App Groups

## App Group

Use one value consistently in both targets:

`group.com.benberther.BlockerApp`

Update:

`SharedConfig.appGroupIdentifier`

## Entitlements

Family Controls entitlement requires an Apple Developer account and may need approval depending on distribution.

## Testing

Use a real iPhone. Screen Time APIs are device-dependent and may not behave fully in the simulator.
