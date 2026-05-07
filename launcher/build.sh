#!/bin/sh
# Build AVLiveLauncher and bundle it into a .app
set -eu
cd "$(dirname "$0")"

BIN_NAME="AVLiveLauncher"
APP_PATH="build/${BIN_NAME}.app"
ARCHS=${ARCHS:-arm64 x86_64}

# Build each arch and lipo them together when more than one
BIN_PARTS=""
for arch in ${ARCHS}; do
    echo "==> swift build (release, ${arch})"
    swift build -c release --arch "${arch}"
    PART=".build/${arch}-apple-macosx/release/${BIN_NAME}"
    [ -x "${PART}" ] || { echo "Missing ${PART}" >&2; exit 1; }
    BIN_PARTS="${BIN_PARTS} ${PART}"
done

BIN_PATH=".build/release/${BIN_NAME}-universal"
mkdir -p "$(dirname "${BIN_PATH}")"
# shellcheck disable=SC2086
lipo -create -output "${BIN_PATH}" ${BIN_PARTS}
echo "==> universal binary $(lipo -info "${BIN_PATH}")"

echo "==> bundling ${APP_PATH}"
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${BIN_PATH}" "${APP_PATH}/Contents/MacOS/${BIN_NAME}"
cp Resources/Info.plist "${APP_PATH}/Contents/Info.plist"

# Build AppIcon.icns from SVG if missing or stale
if [ ! -f Resources/AppIcon.icns ] \
    || [ Resources/icon.svg -nt Resources/AppIcon.icns ]; then
    if command -v rsvg-convert >/dev/null 2>&1; then
        ( cd Resources && ./make_icon.sh )
    else
        echo "warn: rsvg-convert missing, skipping icon regen" >&2
    fi
fi
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "${APP_PATH}/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so Gatekeeper at least lets the user open it manually
codesign --force --sign - "${APP_PATH}" 2>/dev/null || true

echo "==> done"
echo "    open ${APP_PATH}"
