#!/usr/bin/env bash
# Build a release DMG for Claude Window.
# Requires: create-dmg (brew install create-dmg)
#
# Usage: ./scripts/build-dmg.sh [version]
# Example: ./scripts/build-dmg.sh 1.0.1
set -euo pipefail

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo '1.0.0')}"
APP_NAME="ClaudeWindow"
SCHEME="ClaudeWindow"
BUILD_DIR="$(mktemp -d)/build"
DMG_DIR="dist"

echo "Building $APP_NAME $VERSION..."

# Build release
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: App not found at $APP_PATH"
  exit 1
fi

mkdir -p "$DMG_DIR"
DMG_PATH="$DMG_DIR/${APP_NAME}-${VERSION}.dmg"

echo "Creating DMG at $DMG_PATH..."

create-dmg \
  --volname "Claude Window $VERSION" \
  --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 175 185 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 425 185 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$APP_PATH"

echo "Done: $DMG_PATH"
echo "SHA256: $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
