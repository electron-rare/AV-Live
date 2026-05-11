#!/bin/bash
# Resynchronise les sources du bridge depuis ../data_feeds, puis build.
# Lancer depuis web_realart/.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../data_feeds"

if [ ! -d "$SRC" ]; then
    echo "ERR: $SRC introuvable. Sync skip."
else
    echo "[sync] data_feeds -> bridge/src"
    mkdir -p "$HERE/bridge/src/feeds"
    cp "$SRC/bridge.py" "$HERE/bridge/src/bridge.py"
    rsync -a --delete --exclude '__pycache__' "$SRC/feeds/" "$HERE/bridge/src/feeds/"
fi

echo "[build] docker compose build"
cd "$HERE"
docker compose build "$@"
echo "[ok]"
