#!/bin/bash
# Remove Mavro from ~/Library/Input Methods.
set -euo pipefail
APP_NAME="Mavro"
INSTALL_DIR="$HOME/Library/Input Methods"
killall "$APP_NAME" 2>/dev/null || true
rm -rf "$INSTALL_DIR/$APP_NAME.app"
echo "Removed $INSTALL_DIR/$APP_NAME.app. Remove 'Mavro' from System Settings -> Keyboard -> Input Sources too."
