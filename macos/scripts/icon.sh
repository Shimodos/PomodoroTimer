#!/bin/sh
# icon.sh <source.png> <out.icns>
# Builds an .icns from a 256-px PNG with sips + iconutil. The source is 256 px,
# so the iconset stops at 256 (128@2x); the 512 sizes are left out.
set -eu

SRC="$1"
OUT="$2"
SET="${OUT%.icns}.iconset"

rm -rf "$SET"
mkdir -p "$SET"

sips -z 16 16     "$SRC" --out "$SET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$SRC" --out "$SET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$SRC" --out "$SET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$SRC" --out "$SET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$SRC" --out "$SET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$SRC" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$SET/icon_256x256.png"    >/dev/null

iconutil -c icns "$SET" -o "$OUT"
rm -rf "$SET"
