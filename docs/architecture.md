# Architecture

## Main app

Responsible for:
- requesting Family Controls authorization
- letting the user select apps/categories/web domains
- creating daily schedules
- starting/stopping Device Activity monitoring
- showing current commitment status

## Device Activity Monitor Extension

Responsible for:
- receiving interval start/end callbacks
- applying shields through ManagedSettings
- clearing shields when the interval ends

## Shared storage

The main app and extension communicate through App Group UserDefaults.

Data to share:
- selected apps/categories/web domains
- current schedule
- shield state

## Core model

`BlockSchedule` is intentionally testable outside Xcode. The Swift Package tests validate daily schedule behavior on Linux/VPS.
