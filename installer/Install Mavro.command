#!/bin/bash
# Installs Mavro Keyboard + its bundled Bengali fonts for the current user.
# Double-click it, or run:  bash "/Volumes/Mavro Keyboard/Install Mavro.command"
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

# 1. Fonts (so Bengali + ANSI/Bijoy text renders everywhere). Clear the download
#    quarantine only on the files we copy — never touch the user's other fonts.
mkdir -p "$FONT_DIR"
if [ -d "$APP/Contents/Resources/Fonts" ]; then
    for font in "$APP/Contents/Resources/Fonts/"*.ttf; do
        name="$(basename "$font")"
        cp -f "$font" "$FONT_DIR/$name"
        xattr -c "$FONT_DIR/$name" 2>/dev/null || true
    done
    echo "Installed bundled Bengali fonts."
fi

# 2. The input method. Removing the quarantine flag is what lets macOS load this
#    unsigned (not notarized) build.
killall Mavro 2>/dev/null || true
sleep 1
mkdir -p "$IM_DIR"
rm -rf "$IM_DIR/Mavro.app"
cp -R "$APP" "$IM_DIR/"
xattr -cr "$IM_DIR/Mavro.app" 2>/dev/null || true

# 3. Register + enable it so it appears in the input menu right away.
if "$IM_DIR/Mavro.app/Contents/MacOS/Mavro" --install; then
    ENABLED=1
else
    ENABLED=0
fi
open "$IM_DIR/Mavro.app"

echo
echo "=== Done ==="
if [ "$ENABLED" = "1" ]; then
    echo "Mavro is installed and added to your input sources."
    echo "Switch to it with the Globe (fn) key or Control-Space, then type."
else
    echo "Mavro is installed. Add it once:"
    echo "  System Settings -> Keyboard -> Text Input -> Input Sources -> Edit... -> +"
    echo "  -> Bangla -> Mavro -> Add. (If it isn't listed yet, log out and back in.)"
fi
cat <<'EOF'

Typing modes (Cmd-Shift-M cycles):
  iAvro style (default) - English stays inline, Bangla suggestions below.
                          Up/Down choose, Space or Return commits.
  Preview               - Bangla inline, numbered suggestions (Tab / 1-9).
  Raw                   - exactly as typed, no suggestions.
Output (Cmd-Shift-E cycles): Unicode -> ANSI SutonnyMJ -> ANSI Kalpurush

Tip: old iAvro ("Avro Keyboard") no longer works on new macOS - you can remove
it from Input Sources.
EOF
read -r -p "Press Return to close." _
