#!/usr/bin/env bash
set -euo pipefail

APP_DISPLAY_NAME="iTMUX"
PRODUCT_NAME="iTMUXApp"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.johnnyclem.itmux}"
BUNDLE_VERSION="${BUNDLE_VERSION:-1}"
BUNDLE_SHORT_VERSION="${BUNDLE_SHORT_VERSION:-1.0.0}"
OUTPUT_DIR="${1:-dist}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "$BUILD_CONFIGURATION" != "release" && "$BUILD_CONFIGURATION" != "debug" ]]; then
    echo "error: BUILD_CONFIGURATION must be 'release' or 'debug' (got '$BUILD_CONFIGURATION')"
    exit 1
fi

cd "$REPO_ROOT"

echo "Building ${PRODUCT_NAME} (${BUILD_CONFIGURATION})..."
swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME"

BINARY_PATH="$REPO_ROOT/.build/$BUILD_CONFIGURATION/$PRODUCT_NAME"
if [[ ! -x "$BINARY_PATH" ]]; then
    echo "error: expected built binary at $BINARY_PATH"
    exit 1
fi

APP_BUNDLE_PATH="$REPO_ROOT/$OUTPUT_DIR/${APP_DISPLAY_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$APP_DISPLAY_NAME"
chmod +x "$MACOS_DIR/$APP_DISPLAY_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_IDENTIFIER}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${BUNDLE_SHORT_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUNDLE_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -f "$REPO_ROOT/Resources/AppIcon.icns" ]]; then
    cp "$REPO_ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1 || true
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE_PATH" >/dev/null
fi

echo ""
echo "Built standalone app bundle:"
echo "  $APP_BUNDLE_PATH"
echo ""
echo "Launch it without Terminal parent process:"
echo "  open \"$APP_BUNDLE_PATH\""
