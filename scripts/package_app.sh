#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/SnipConcludeMac"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="ClipWise"
EXECUTABLE_NAME="ClipWiseMac"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
EXECUTABLE_PATH="$PROJECT_DIR/.build/release/$EXECUTABLE_NAME"
ASSETS_DIR="$PROJECT_DIR/Assets"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
VERSION="${CLIPWISE_VERSION:-0.1.0}"
BUILD_NUMBER="${CLIPWISE_BUILD:-1}"
BUNDLE_ID="${CLIPWISE_BUNDLE_ID:-com.pilotphil.clipwise}"
SIGN_IDENTITY="${CLIPWISE_SIGN_IDENTITY:--}"

echo "==> Building release binary"
cd "$PROJECT_DIR"
swift build -c release

echo "==> Creating app bundle"
rm -rf "$APP_BUNDLE" "$ZIP_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$EXECUTABLE_PATH" "$APP_MACOS/$EXECUTABLE_NAME"
chmod +x "$APP_MACOS/$EXECUTABLE_NAME"

if [[ ! -f "$ASSETS_DIR/ClipWise.icns" || ! -f "$ASSETS_DIR/StatusBarTemplate.png" ]]; then
    echo "Missing icon assets. Run: swift scripts/generate_icons.swift" >&2
    exit 1
fi
cp "$ASSETS_DIR/ClipWise.icns" "$APP_RESOURCES/ClipWise.icns"
cp "$ASSETS_DIR/StatusBarTemplate.png" "$APP_RESOURCES/StatusBarTemplate.png"
cp "$ASSETS_DIR/StatusBarTemplate@2x.png" "$APP_RESOURCES/StatusBarTemplate@2x.png"

cat > "$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>ClipWise</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>
    <string>ClipWise</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ClipWise</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Pilot.Phil</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Signing app bundle"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP_BUNDLE"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
fi

echo "==> Creating zip"
cd "$DIST_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"

echo
echo "Done:"
echo "  $APP_BUNDLE"
echo "  $ZIP_PATH"
echo
echo "For Developer ID signing, run for example:"
echo "  CLIPWISE_SIGN_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\" ./scripts/package_app.sh"
