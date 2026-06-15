#!/bin/bash
# Build a shareable Mavro-Installer.dmg: Mavro.app (fonts bundled) + a
# double-click installer + Read Me + font licenses.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Mavro.app"
DMG="$BUILD/Mavro-Installer.dmg"
VOL="Mavro Keyboard"

# Ensure a fresh release build (with fonts) exists.
bash "$ROOT/scripts/build.sh" release

STAGE="$BUILD/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"

cp -R "$APP" "$STAGE/Mavro.app"
cp "$ROOT/installer/Install Mavro.command" "$STAGE/Install Mavro.command"
chmod +x "$STAGE/Install Mavro.command"
cp "$ROOT/installer/ReadMe.txt" "$STAGE/Read Me.txt"
mkdir -p "$STAGE/Font Licenses"
cp "$ROOT/assets/fonts/FONTS-NOTICE.txt" "$STAGE/Font Licenses/" 2>/dev/null || true
cp -R "$ROOT/assets/fonts/licenses/." "$STAGE/Font Licenses/" 2>/dev/null || true

rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "=== Created $DMG ($(du -h "$DMG" | cut -f1)) ==="
