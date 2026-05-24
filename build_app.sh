#!/bin/bash
# Builds Shutter.app from the Swift package and ad-hoc signs it.
# Run: ./build_app.sh
# Output: ./build/Shutter.app  (drag this to /Applications)

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Shutter"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release

BINARY_PATH=$(swift build -c release --show-bin-path)/$APP_NAME

if [ ! -f "$BINARY_PATH" ]; then
    echo "ERROR: binary not found at $BINARY_PATH"
    exit 1
fi

echo "==> Assembling .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_DIR/Contents/Info.plist"

# Drop your custom AppIcon.icns into Resources/ before running this script and it'll get bundled.
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "    (included custom AppIcon.icns)"
else
    echo "    (no Resources/AppIcon.icns found — using default Swift icon)"
fi

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_DIR"

# Pull the version from Info.plist so the dmg name matches the build.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "dev")
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"

echo "==> Building $DMG_PATH"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
# Symlink to /Applications gives the classic drag-to-install affordance.
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

echo ""
echo "Built:"
echo "  App: $APP_DIR"
echo "  DMG: $DMG_PATH"
echo ""
echo "Install:"
echo "  Open $DMG_PATH and drag Shutter to Applications."
echo "  First launch: right-click Shutter → Open (Gatekeeper warns since it's not Apple-signed)."
