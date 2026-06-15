#!/bin/bash
# Build Mavro.app: Rust engine static lib + Swift InputMethodKit binary,
# assembled and ad-hoc signed. Apple Silicon only.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_DIR="$PROJECT_ROOT/engine"
SOURCES_DIR="$PROJECT_ROOT/Sources"
RESOURCES_DIR="$PROJECT_ROOT/Resources"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="Mavro"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BUILD_TYPE="${1:-release}"

echo "=== Mavro build ($BUILD_TYPE) ==="

command -v cargo >/dev/null 2>&1 || source "$HOME/.cargo/env" 2>/dev/null || true

# 1. Rust engine static library
echo ">>> Building Rust engine..."
CARGO_ARGS=""
[ "$BUILD_TYPE" = "release" ] && CARGO_ARGS="--release"
( cd "$ENGINE_DIR" && cargo build $CARGO_ARGS --target aarch64-apple-darwin )
LIB="$ENGINE_DIR/target/aarch64-apple-darwin/${BUILD_TYPE}/libmavro_engine.a"
echo ">>> Engine: $LIB"

# 2. App bundle skeleton
echo ">>> Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/data"
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$RESOURCES_DIR/data/"*.json "$APP_BUNDLE/Contents/Resources/data/"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# 3. Compile Swift sources
echo ">>> Compiling Swift..."
SWIFT_SOURCES=(
    "$SOURCES_DIR/InputMode.swift"
    "$SOURCES_DIR/MavroInputController.swift"
    "$SOURCES_DIR/CandidatePanel.swift"
    "$SOURCES_DIR/ModeHUD.swift"
    "$SOURCES_DIR/HotKeyManager.swift"
    "$SOURCES_DIR/ToolWindowCoordinator.swift"
    "$SOURCES_DIR/StatusMenu.swift"
    "$SOURCES_DIR/AppDelegate.swift"
    "$SOURCES_DIR/Tools/CharacterMap.swift"
    "$SOURCES_DIR/Tools/Converter.swift"
    "$SOURCES_DIR/main.swift"
)
SWIFT_OPT="-O"
[ "$BUILD_TYPE" = "debug" ] && SWIFT_OPT="-Onone -g"

swiftc "${SWIFT_SOURCES[@]}" \
    $SWIFT_OPT \
    -module-name "$APP_NAME" \
    -import-objc-header "$SOURCES_DIR/BridgeHeader.h" \
    -I "$ENGINE_DIR/include" \
    -L "$(dirname "$LIB")" \
    -lmavro_engine \
    -framework Cocoa \
    -framework InputMethodKit \
    -target arm64-apple-macos13.0 \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 4. Ad-hoc sign (sufficient for local install; not notarized)
echo ">>> Ad-hoc signing..."
codesign --force --sign - \
    --entitlements "$RESOURCES_DIR/Mavro.entitlements" \
    "$APP_BUNDLE"

echo "=== Done: $APP_BUNDLE ==="
