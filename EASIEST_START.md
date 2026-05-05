# Easiest Start

## Step 1: Clone/open this repo

On your Mac:

```bash
git clone https://github.com/benhelloworld/blocker-app-ios.git
cd blocker-app-ios
```

## Step 2: Create the Xcode app shell

1. Open Xcode.
2. File → New → Project.
3. Choose iOS → App.
4. Product Name: `BlockerApp`
5. Interface: SwiftUI
6. Language: Swift
7. Save it inside this repo, or create it elsewhere and copy the files from `ios/`.

## Step 3: Add the extension

In Xcode:

1. File → New → Target.
2. Search for `Device Activity Monitor Extension`.
3. Name it: `BlockerMonitorExtension`.

## Step 4: Add capabilities

Main app target:
- Family Controls
- App Groups

Extension target:
- App Groups

Use an App Group like:

`group.com.benhelloworld.blockerapp`

Then replace the placeholder in:

`ios/BlockerApp/Services/SharedConfig.swift`

## Step 5: Add Swift files to targets

Copy files under `ios/BlockerApp` into the main app target.
Copy files under `ios/BlockerMonitorExtension` into the extension target.

Shared files that should be available to both targets:
- `ios/BlockerApp/Models/BlockSchedule.swift`
- `ios/BlockerApp/Services/SharedConfig.swift`
- `ios/BlockerApp/Services/ShieldStorage.swift`

## Step 6: Run on a real iPhone

Screen Time APIs usually require a real iPhone and your Apple Developer account. Simulator support is limited.

## If Xcode errors

Send Herm the exact error text or a screenshot. He can update the GitHub repo and you can pull the fix.
