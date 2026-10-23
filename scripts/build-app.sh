#!/usr/bin/env bash
# Compiles Glean and assembles a signed build/Glean.app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/scripts/signing.env"
BUILD="$(date +%Y%m%d%H%M)"
APP="$ROOT/build/Glean.app"

swift build -c release --product Glean
BIN="$(swift build -c release --show-bin-path)/Glean"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Glean"
cp Resources/AppIcon.icns Resources/menubar*.png "$APP/Contents/Resources/"
sed -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

if [[ -n "$SIGN_IDENTITY" && -f "$SIGN_KEYCHAIN" ]] && security find-identity -p codesigning "$SIGN_KEYCHAIN" | grep -q "\"$SIGN_IDENTITY\""; then
  if [[ -n "$SIGN_KEYCHAIN_PASSWORD" ]]; then security unlock-keychain -p "$SIGN_KEYCHAIN_PASSWORD" "$SIGN_KEYCHAIN"; fi
  codesign --force --keychain "$SIGN_KEYCHAIN" --sign "$SIGN_IDENTITY" --identifier local.glean.app "$APP"
else
  echo "note: no signing identity configured (scripts/signing.local.env); using ad-hoc signing." >&2
  echo "      macOS will ask for microphone and notification permission again after every rebuild." >&2
  codesign --force --sign - --identifier local.glean.app "$APP"
fi

echo "built $APP (build $BUILD)"
