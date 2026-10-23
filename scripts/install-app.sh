#!/usr/bin/env bash
# Replaces /Applications/Glean.app with the fresh build and relaunches it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/Glean.app"
DEST="${INSTALL_DIR:-/Applications}/Glean.app"

[[ -d "$SRC" ]] || { echo "no build found; run 'make build' first" >&2; exit 1; }

if pgrep -x Glean >/dev/null; then
  osascript -e 'tell application id "local.glean.app" to quit' >/dev/null 2>&1 || true
  for _ in {1..20}; do pgrep -x Glean >/dev/null || break; sleep 0.25; done
  pgrep -x Glean >/dev/null && { echo "Glean is still running. Quit it from the menu bar first." >&2; exit 1; }
fi

rm -rf "$DEST"
ditto "$SRC" "$DEST"
open "$DEST"
echo "installed $DEST"
