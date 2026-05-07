#!/bin/sh
# Build AVLiveLauncher and bundle it into a .app
set -eu
cd "$(dirname "$0")"

echo "==> swift build (release)"
swift build -c release

BIN_NAME="AVLiveLauncher"
BIN_PATH=".build/release/${BIN_NAME}"
APP_PATH="build/${BIN_NAME}.app"

if [ ! -x "${BIN_PATH}" ]; then
    echo "Build did not produce ${BIN_PATH}" >&2
    exit 1
fi

echo "==> bundling ${APP_PATH}"
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${BIN_PATH}" "${APP_PATH}/Contents/MacOS/${BIN_NAME}"
cp Resources/Info.plist "${APP_PATH}/Contents/Info.plist"

# Ad-hoc sign so Gatekeeper at least lets the user open it manually
codesign --force --sign - "${APP_PATH}" 2>/dev/null || true

echo "==> done"
echo "    open ${APP_PATH}"
