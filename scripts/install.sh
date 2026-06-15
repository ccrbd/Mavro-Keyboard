#!/bin/bash
# Install Mavro.app into ~/Library/Input Methods and (re)launch the service.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Mavro"
APP_BUNDLE="$PROJECT_ROOT/build/$APP_NAME.app"
INSTALL_DIR="$HOME/Library/Input Methods"

[ -d "$APP_BUNDLE" ] || { echo "Error: $APP_BUNDLE not found. Run scripts/build.sh first."; exit 1; }

echo "=== Installing $APP_NAME ==="
killall "$APP_NAME" 2>/dev/null || true
sleep 1

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"
xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

open "$INSTALL_DIR/$APP_NAME.app"

cat <<EOF

=== Installed to $INSTALL_DIR/$APP_NAME.app ===

First-time setup:
  1. System Settings -> Keyboard -> Input Sources -> Edit... -> "+"
  2. Select "Bangla" (or search "Mavro") and add "Mavro"
  3. Switch to Mavro with the Globe/Fn key or Ctrl+Space
  (If Mavro doesn't appear, log out and back in so macOS registers it.)
EOF
