#!/usr/bin/env bash
# Push the Multi-HMR mlpackage + server to macm1 (M1 Max, 32-core GPU)
# and launch the inference server in the background.
#
# Prereqs on macm1 :
#   * passwordless ssh (Tailscale alias 'macm1' or LAN)
#   * uv installed
#   * Python 3.12 available via uv (uv pulls it)
#
# Usage:
#   ./scripts/setup_remote_macm1.sh
#   MACM1_HOST=clems@192.168.0.175 ./scripts/setup_remote_macm1.sh
set -euo pipefail

HOST="${MACM1_HOST:-macm1}"
PORT="${MULTIHMR_SERVER_PORT:-57140}"
MLPACKAGE_LOCAL="${MLPACKAGE_LOCAL:-$HOME/.cache/av-live-multihmr/multihmr_full_672_s.mlpackage}"
REMOTE_TMP="/tmp/av-live-multihmr"
REMOTE_VENV="/tmp/av-live-multihmr/venv"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Target host : $HOST"
echo "==> mlpackage   : $MLPACKAGE_LOCAL"

if [ ! -d "$MLPACKAGE_LOCAL" ]; then
    echo "ERROR: mlpackage missing at $MLPACKAGE_LOCAL" >&2
    exit 1
fi

echo "==> Creating remote tmp dir"
ssh "$HOST" "mkdir -p $REMOTE_TMP"

echo "==> rsync mlpackage (~70 MB, may take a moment first time)"
rsync -a --delete \
    "$MLPACKAGE_LOCAL/" \
    "$HOST:$REMOTE_TMP/multihmr_full_672_s.mlpackage/"

echo "==> rsync multihmr_server.py"
rsync -a "$SCRIPT_DIR/multihmr_server.py" \
    "$HOST:$REMOTE_TMP/multihmr_server.py"

echo "==> Provision Python 3.12 venv with uv (idempotent)"
ssh "$HOST" "bash -lc 'set -e
  if [ ! -x $REMOTE_VENV/bin/python ]; then
    uv venv --python 3.12 $REMOTE_VENV --quiet
  fi
  uv pip install --python $REMOTE_VENV/bin/python --quiet \
      coremltools numpy opencv-python-headless
'"

echo "==> Killing any stale server on :$PORT"
ssh "$HOST" "bash -lc 'pkill -f multihmr_server.py 2>/dev/null || true; sleep 0.3'"

echo "==> Launching server (background)"
ssh "$HOST" "bash -lc 'cd $REMOTE_TMP && \
    MULTIHMR_SERVER_PORT=$PORT \
    nohup $REMOTE_VENV/bin/python multihmr_server.py \
        --mlpackage $REMOTE_TMP/multihmr_full_672_s.mlpackage \
        --port $PORT \
        >> $REMOTE_TMP/server.log 2>&1 &
    echo \$! > $REMOTE_TMP/server.pid
    disown || true'"

echo "==> Waiting for server to be ready"
REMOTE_ADDR=$(ssh "$HOST" 'echo $SSH_CONNECTION' | awk '{print $3}')
# Fallback to host alias if SSH_CONNECTION trick fails.
if [ -z "${REMOTE_ADDR:-}" ]; then REMOTE_ADDR="$HOST"; fi

for i in $(seq 1 30); do
    if ssh "$HOST" "bash -lc 'nc -z 127.0.0.1 $PORT 2>/dev/null'"; then
        echo "==> Server up on $HOST:$PORT (probed via localhost on host)"
        echo "==> Reachable from this Mac at $REMOTE_ADDR:$PORT"
        ssh "$HOST" "tail -n 20 $REMOTE_TMP/server.log" || true
        exit 0
    fi
    sleep 1
done

echo "ERROR: server did not come up within 30s. Last log lines:" >&2
ssh "$HOST" "tail -n 60 $REMOTE_TMP/server.log" || true
exit 1
