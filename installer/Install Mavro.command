#!/bin/bash
# Double-click to install Mavro Keyboard + its bundled Bengali fonts.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/Mavro.app"
IM_DIR="$HOME/Library/Input Methods"
FONT_DIR="$HOME/Library/Fonts"

echo "=== Installing Mavro Keyboard ==="

if [ ! -d "$APP" ]; then
    echo "Error: Mavro.app not found next to this installer."
    read -r -p "Press Return to close." _ ; exit 1
fi

# 1. Install the bundled fonts (so Bengali + ANSI/Bijoy text renders everywhere).
mkdir -p "$FONT_DIR"
if [ -d "$APP/Contents/Resources/Fonts" ]; then
    cp -f "$APP/Contents/Resources/Fonts/"*.ttf "$FONT_DIR/" 2>/dev/null || true
    echo "Installed bundled Bengali fonts to $FONT_DIR"
fi

# 2. Install the input method.
killall Mavro 2>/dev/null || true
sleep 1
mkdir -p "$IM_DIR"
rm -rf "$IM_DIR/Mavro.app"
cp -R "$APP" "$IM_DIR/"
xattr -cr "$IM_DIR/Mavro.app" 2>/dev/null || true
open "$IM_DIR/Mavro.app"

cat <<EOF

=== Done ===
Mavro is installed. To start typing Bengali:
  1. Open System Settings -> Keyboard -> Input Sources -> Edit... -> "+"
  2. Choose "Bangla" -> "Mavro" -> Add
  3. Switch to Mavro with the Globe/Fn key or Ctrl-Space
  (First install: if Mavro isn't listed, log out and back in, then retry.)

Shortcuts while typing with Mavro:
  Cmd-Shift-M  switch Raw / Preview mode
  Cmd-Shift-E  cycle output: Unicode -> ANSI(SutonnyMJ) -> ANSI(Kalpurush)
EOF
read -r -p "Press Return to close." _
