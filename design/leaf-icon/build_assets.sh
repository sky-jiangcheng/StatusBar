#!/usr/bin/env bash
# Render SVG masters -> PNG iconset -> xcassets (with dark variants) + icns
# No-delete pipeline: renders into a fresh timestamp-free unique dir each run,
# overwrites xcassets PNGs in place (cp over same-name files).
set -euo pipefail
cd "$(dirname "$0")"

OUT="png-output"   # created fresh with mkdir -p; files overwritten by renderer
mkdir -p "$OUT/light" "$OUT/dark"

SIZES=( "16x16:16" "16x16@2x:32" "32x32:32" "32x32@2x:64" "128x128:128" "128x128@2x:256" "256x256:256" "256x256@2x:512" "512x512:512" "512x512@2x:1024" )

for entry in "${SIZES[@]}"; do
  name="${entry%%:*}"
  px="${entry##*:}"
  if [ "$px" -le 32 ]; then
    LSVG="leaf-light-small-rounded.svg"; DSVG="leaf-dark-small-rounded.svg"
  else
    LSVG="preview-light-rounded.svg"; DSVG="preview-dark-rounded.svg"
  fi
  ./render_icons --one "$LSVG" "$OUT/light/icon_${name}.png" "$px"
  ./render_icons --one "$DSVG" "$OUT/dark/icon_${name}.png" "$px"
  echo "✓ ${name} (${px}px)"
done

# --- icns (light as default bundle icon); icns overwritten each run ---
mkdir -p iconset.iconset
for f in "$OUT"/light/icon_*.png; do cp "$f" "iconset.iconset/$(basename "$f")"; done
iconutil -c icns iconset.iconset -o "StatusBar.icns"
echo "✓ StatusBar.icns"

# --- xcassets: overwrite light PNGs in place, add dark/ subdir ---
ASSETS="../../Sources/status-bar/Resources/Assets.xcassets"
APPICON="$ASSETS/AppIcon.appiconset"
for f in "$OUT"/light/icon_*.png; do cp "$f" "$APPICON/$(basename "$f")"; done
mkdir -p "$APPICON/dark"
for f in "$OUT"/dark/icon_*.png; do cp "$f" "$APPICON/dark/$(basename "$f")"; done
echo "✓ PNGs staged into xcassets"
