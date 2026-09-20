#!/bin/bash
# Builds HingeForce and wraps it in build/HingeForce.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/HingeForce"

APP="build/HingeForce.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/HingeForce"
cp Support/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "Built $APP"
