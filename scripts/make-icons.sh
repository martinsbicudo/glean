#!/usr/bin/env bash
# Regenerates brand SVGs and the raster assets the app bundles (AppIcon.icns, menu bar PNGs).
# Only needed after changing brand/generate.py; the outputs are committed so `make install` doesn't need it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RENDER="${RENDER_PNG:-$(ls -d "$HOME"/.claude/plugins/cache/logo-design-skill/logo-design/*/skills/logo-design/scripts/render_png.py 2>/dev/null | tail -1)}"
if [[ -z "$RENDER" || ! -f "$RENDER" ]]; then
  echo "render_png.py not found; set RENDER_PNG=/path/to/render_png.py" >&2
  exit 1
fi

SVG="$ROOT/brand/svg"
RES="$ROOT/Resources"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

python3 "$ROOT/brand/generate.py"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
render() { python3 "$RENDER" "$1" -o "$2" --size "$3" >/dev/null; }

for size in 16 32 128 256 512; do
  src="$SVG/glean-app-icon.svg"
  [[ $size -le 32 ]] && src="$SVG/glean-app-icon-small.svg"
  render "$src" "$ICONSET/icon_${size}x${size}.png" "$size"
  double=$((size * 2))
  src2="$SVG/glean-app-icon.svg"
  [[ $double -le 32 ]] && src2="$SVG/glean-app-icon-small.svg"
  render "$src2" "$ICONSET/icon_${size}x${size}@2x.png" "$double"
done
iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"

python3 "$RENDER" "$SVG/menubar.svg" -o "$RES/menubar.png" --width 22 --height 18 >/dev/null
python3 "$RENDER" "$SVG/menubar.svg" -o "$RES/menubar@2x.png" --width 44 --height 36 >/dev/null

mkdir -p "$ROOT/brand/png"
render "$SVG/glean-app-icon.svg" "$ROOT/brand/png/glean-app-icon-1024.png" 1024
python3 "$RENDER" "$SVG/glean-lockup-plum.svg" -o "$ROOT/brand/png/glean-lockup.png" --bg "#F4EFE6" --width 1280 --height 512 >/dev/null
python3 "$RENDER" "$SVG/glean-lockup-reversed.svg" -o "$ROOT/brand/png/glean-lockup-reversed.png" --width 1280 --height 512 --bg "#16181D" >/dev/null

echo "icons written to $RES and $ROOT/brand/png"
