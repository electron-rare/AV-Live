#!/bin/sh
# Convertit Resources/icon.svg en AppIcon.icns (multi-sizes)
set -eu
cd "$(dirname "$0")"

SVG=icon.svg
SET=AppIcon.iconset

[ -f "$SVG" ] || { echo "missing $SVG" >&2; exit 1; }
command -v rsvg-convert >/dev/null || { echo "needs rsvg-convert (brew install librsvg)" >&2; exit 1; }
command -v iconutil >/dev/null || { echo "needs iconutil (Xcode CLT)" >&2; exit 1; }

rm -rf "$SET" AppIcon.icns
mkdir -p "$SET"

# (size_in_pt, scale, filename)
render() {
    px=$(( $1 * $2 ))
    rsvg-convert -w "$px" -h "$px" "$SVG" -o "$SET/icon_${1}x${1}${3}.png"
}

render 16  1 ""
render 16  2 "@2x"
render 32  1 ""
render 32  2 "@2x"
render 128 1 ""
render 128 2 "@2x"
render 256 1 ""
render 256 2 "@2x"
render 512 1 ""
render 512 2 "@2x"

iconutil -c icns "$SET" -o AppIcon.icns
echo "==> AppIcon.icns ($(du -k AppIcon.icns | cut -f1) KB)"
