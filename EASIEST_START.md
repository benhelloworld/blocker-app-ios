# Open AntiScroll in Xcode

AntiScroll now has one canonical Git-controlled project.

1. Open `~/blocker-app-ios/BlockerApp.xcodeproj` in Xcode.
2. If you migrated from the older Desktop copy, ensure that path points to this same repository rather than maintaining duplicate source trees.
3. Select the `BlockerApp` scheme and your development team.
4. Run on a physical iPhone for FamilyControls and Screen Time verification.

Do not create another Xcode project or copy Swift files into a second directory. Make source changes only in this repository and use a Git branch for each task.

See `README.md`, `AGENTS.md`, and `docs/xcode-setup.md` for build commands, engineering rules, capabilities, and App Group details.
