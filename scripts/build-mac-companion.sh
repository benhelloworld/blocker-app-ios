#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AntiScroll Mac Companion"
BUNDLE_ID="com.benberther.AntiScrollMacCompanion"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUILD_DIR="$ROOT_DIR/build/MacCompanion"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/build/dist"
DMG_PATH="$DIST_DIR/AntiScroll-Mac-Companion.dmg"
BINARY_PATH="$ROOT_DIR/.build/release/BlockerMacCompanion"
ENTITLEMENTS_PATH="$BUILD_DIR/BlockerMacCompanion.entitlements"

cd "$ROOT_DIR"
swift build -c release --product BlockerMacCompanion

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/BlockerMacCompanion"
chmod +x "$APP_DIR/Contents/MacOS/BlockerMacCompanion"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BlockerMacCompanion</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cat > "$ENTITLEMENTS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.benberther.BlockerApp</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
PLIST

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning | perl -ne 'print "$1\n" and exit if /\"(Apple Development:[^\"]+)\"/')"
fi
if [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
    if ! codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null; then
        echo "warning: Apple Development signing was unavailable in this shell; using ad-hoc signing (iCloud Drive fallback remains active)" >&2
        codesign --force --deep --sign - "$APP_DIR" >/dev/null
    fi
else
    echo "warning: no Apple Development signing identity found; using ad-hoc signing (iCloud Drive fallback only)" >&2
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
cat > "$STAGING_DIR/Beta Installation.txt" <<TXT
AntiScroll Mac Companion $VERSION (Beta)

1. Drag AntiScroll Mac Companion into Applications.
2. Open Applications, Control-click AntiScroll Mac Companion, and choose Open.
3. If macOS asks for confirmation, choose Open again.
4. Use the same Apple Account as your iPhone and keep iCloud Drive enabled.
5. When Mac blocking changes, approve the administrator prompt so the Companion can update protected system settings.

This beta is ad-hoc signed and is not yet notarized. A notarized public build will replace it before the full launch.
TXT

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
printf '%s\n%s\n' "$APP_DIR" "$DMG_PATH"
