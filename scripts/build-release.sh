#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="NoShitMac"
CONFIG="Release"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/NoShitMac.xcarchive"
APP_PATH="$BUILD_DIR/Release/NoShitMac.app"

cd "$ROOT"

if [[ ! -f "NoShitMac.xcodeproj/project.pbxproj" ]]; then
  echo "Generating Xcode project…"
  xcodegen generate
fi

xcodebuild \
  -project NoShitMac.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/NoShitMac.app" "$APP_PATH"
echo "Built: $APP_PATH"
