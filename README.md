# Blocker App iOS

Starter repo for an iOS app/website blocker using Apple's Screen Time APIs.

Important: Hermes can write the code and push to GitHub from the VPS, but final build/run/signing must happen on a Mac with Xcode and a real iPhone for Screen Time APIs.

## What this repo contains

- Swift package with testable shared scheduling logic
- SwiftUI app starter files
- Device Activity Monitor extension starter files
- Xcode setup instructions
- App Store/privacy drafts

## Apple frameworks planned

- FamilyControls
- ManagedSettings
- DeviceActivity
- SwiftUI
- App Groups

## Quick start on your Mac

Read `EASIEST_START.md` first.

## Current MVP scope

1. Ask permission for Family Controls.
2. Let user select apps/websites to block.
3. Create a daily blocking schedule.
4. Enforce selected shields during the scheduled interval.
5. Store schedule and shield selection through an App Group so the main app and extension share state.

## Safety/marketing language

Avoid saying "impossible to bypass" in App Store copy. Use safer wording like "harder to bypass", "commitment-focused", and "built with Apple's Screen Time framework".
