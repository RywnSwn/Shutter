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

echo ""
echo "Built: $APP_DIR"
echo ""
echo "Next steps:"
echo "  1. Drag $APP_DIR into /Applications"
echo "  2. Right-click → Open the first time (Gatekeeper will warn since it's not Apple-signed)"
echo "  3. Open Settings and enable 'Launch at login' if you want auto-start"
