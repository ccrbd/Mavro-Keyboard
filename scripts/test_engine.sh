#!/bin/bash
# Compile and run the C engine test against the release static lib.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$ROOT/engine"
LIB="$ENGINE/target/aarch64-apple-darwin/release"

[ -f "$LIB/libmavro_engine.a" ] || ( cd "$ENGINE" && cargo build --release --target aarch64-apple-darwin )

OUT="$(mktemp -d)/engine_test"
clang -I "$ENGINE/include" \
    "$ENGINE/tests/engine_test.c" \
    "$LIB/libmavro_engine.a" \
    -framework CoreFoundation -framework Security \
    -o "$OUT"

mkdir -p "$ROOT/build/test-userdir"
"$OUT" "$ROOT/Resources/data" "$ROOT/build/test-userdir"
