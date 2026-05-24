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
TMP_DMG="$BUILD_DIR/$APP_NAME-$VERSION.tmp.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"
BG_SRC="shutter-dmg-background.png"

echo "==> Building $DMG_PATH"
rm -rf "$STAGING_DIR" "$DMG_PATH" "$TMP_DMG"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
# Symlink to /Applications gives the classic drag-to-install affordance.
ln -s /Applications "$STAGING_DIR/Applications"

# Drop the background into a hidden folder so Finder doesn't show it in the window.
# PNG is 1520x1000 (2x Retina). Stamp 144dpi so Finder treats it as 760x500 points
# (no resizing — preserve original pixels so the artwork isn't stretched).
if [ -f "$BG_SRC" ]; then
    mkdir -p "$STAGING_DIR/.background"
    cp "$BG_SRC" "$STAGING_DIR/.background/background.png"
    sips -s dpiHeight 144 -s dpiWidth 144 "$STAGING_DIR/.background/background.png" >/dev/null
fi

# Create a writable DMG we can decorate before compressing.
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDRW \
    "$TMP_DMG" >/dev/null

MOUNT_DIR="/Volumes/$APP_NAME"
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen >/dev/null

if [ -f "$BG_SRC" ]; then
    # Background image is 1520x1000 (2x Retina) → 760x500 points at 144dpi.
    # Window bounds {left, top, right, bottom}: width 760, height 528 (500 + ~28 titlebar)
    # so the content area lines up exactly with the background image.
    osascript <<EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 960, 648}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {190, 250}
        set position of item "Applications" of container window to {570, 250}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
fi

sync
hdiutil detach "$MOUNT_DIR" >/dev/null

hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

echo ""
echo "Built:"
echo "  App: $APP_DIR"
echo "  DMG: $DMG_PATH"
echo ""
echo "Install:"
echo "  Open $DMG_PATH and drag Shutter to Applications."
echo "  First launch: right-click Shutter → Open (Gatekeeper warns since it's not Apple-signed)."
