#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP_PATH="$ROOT/build/Release/NoShitMac.app"
DMG_PATH="$ROOT/dist/NoShitMac-${VERSION}.dmg"
STAGING="$ROOT/build/dmg-staging"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Run scripts/build-release.sh first"
  exit 1
fi

mkdir -p "$ROOT/dist"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "NoShitMac" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
echo "Created: $DMG_PATH"
