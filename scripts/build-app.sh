#!/bin/bash
# Builds HingeForce and wraps it in build/HingeForce.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/HingeForce"

APP="build/HingeForce.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/HingeForce"
cp Support/Info.plist "$APP/Contents/Info.plist"

# SPM resource bundle — AppResources looks here under Contents/Resources.
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done

codesign --force --sign - "$APP"
echo "Built $APP"
