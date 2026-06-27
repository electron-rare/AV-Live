#!/bin/zsh
# Assemble "AV-Live Concert.app" from launch_concert.sh + Info.plist.
# Usage: ./build_concert_app.sh [output-path]
#   default output: ~/Desktop/AV-Live Concert.app
set -eu
cd "$(dirname "$0")"

APP="${1:-$HOME/Desktop/AV-Live Concert.app}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist            "$APP/Contents/Info.plist"
cp launch_concert.sh     "$APP/Contents/MacOS/launch"
chmod +x                 "$APP/Contents/MacOS/launch"

# Ad-hoc sign so Gatekeeper lets it run locally without a quarantine prompt.
codesign --force --deep --sign - "$APP" 2>/dev/null || true
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "Built: $APP"
echo "Double-click it, or:  open \"$APP\""
