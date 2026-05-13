#!/usr/bin/env bash
# Train action-head on MacStudio M3 Ultra (Tailscale 100.116.92.12).
#
# SSH direct grosmac→studio is broken since reboot 2026-05-12 ;
# we route via electron-server bastion (cf. CLAUDE.md root).
#
# Usage:
#   ./train_on_studio.sh                    # uses defaults
#   ./train_on_studio.sh --epochs 80 --lr 5e-4
#
# Local layout :
#   ~/.cache/av-live-action/dataset/dataset.jsonl   (input)
#   ~/.cache/av-live-action/checkpoints/            (output, after rsync back)
#
# Remote layout :
#   studio:~/av-live-action/repo/                   (rsynced code subset)
#   studio:~/av-live-action/dataset/                (rsynced dataset)
#   studio:~/av-live-action/checkpoints/            (training output)

set -euo pipefail

BASTION_USER_HOST="${BASTION_USER_HOST:-electron-server}"
STUDIO_USER_HOST="${STUDIO_USER_HOST:-clems@100.116.92.12}"
STUDIO_USER="${STUDIO_USER:-clems}"
STUDIO_UV="${STUDIO_UV:-/opt/homebrew/bin/uv}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
LOCAL_CACHE="$HOME/.cache/av-live-action"
LOCAL_DATASET="$LOCAL_CACHE/dataset"
LOCAL_CKPT="$LOCAL_CACHE/checkpoints"

REMOTE_ROOT="/Users/${STUDIO_USER}/av-live-action"
REMOTE_REPO="$REMOTE_ROOT/repo"
REMOTE_DATASET="$REMOTE_ROOT/dataset"
REMOTE_CKPT="$REMOTE_ROOT/checkpoints"

DATASET_FILE="${DATASET_FILE:-$LOCAL_DATASET/dataset.jsonl}"
CKPT_NAME="${CKPT_NAME:-action_head.pt}"

# Quote train args defensively before forwarding through bastion ssh +
# studio ssh (each layer reparses). Reject single quotes — they break
# the single-quoted payload in bastion_ssh and could allow injection.
for a in "$@"; do
  if [[ "$a" == *"'"* ]]; then
    printf '[train_on_studio] forbidden single quote in arg: %s\n' "$a" >&2
    exit 3
  fi
done
TRAIN_ARGS="$(printf '%q ' "$@")"

log() { printf '[train_on_studio] %s\n' "$*" >&2; }

[[ -f "$DATASET_FILE" ]] || { log "missing dataset: $DATASET_FILE"; exit 2; }
mkdir -p "$LOCAL_CKPT"

bastion_ssh() {
  # The remote shell on the bastion must receive the studio command
  # as a single argument, otherwise `;` and `&&` are parsed
  # bastion-side instead of studio-side.
  # All paths in commands MUST be absolute (no $HOME, no ~) since
  # we use single-quotes for the studio-side payload.
  ssh -o ConnectTimeout=5 "$BASTION_USER_HOST" \
      "ssh -o ConnectTimeout=5 $STUDIO_USER_HOST '$*'"
}

bastion_rsync() {
  # rsync via ssh ProxyJump through bastion. Direct grosmac->studio
  # known_hosts entry may be stale (SSH direct broken since reboot
  # 2026-05-12). accept-new lets us add the key on first use.
  local src="$1" dst="$2"
  rsync -avz --delete \
    -e "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -A -J $BASTION_USER_HOST" \
    "$src" "$dst"
}

log "== Studio reachability =="
bastion_ssh "echo studio OK ; $STUDIO_UV --version"

log "== Push code subset =="
bastion_ssh "mkdir -p $REMOTE_REPO/data_only_viz $REMOTE_DATASET $REMOTE_CKPT"
rsync -avz --delete \
  --exclude='.venv/' --exclude='__pycache__/' --exclude='.pytest_cache/' \
  --exclude='.ruff_cache/' --exclude='*.pyc' --exclude='.DS_Store' \
  --exclude='web/' --exclude='shaders/' \
  -e "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -A -J $BASTION_USER_HOST" \
  "$REPO_ROOT/data_only_viz/" \
  "$STUDIO_USER_HOST:av-live-action/repo/data_only_viz/"

log "== Push dataset =="
bastion_rsync "$LOCAL_DATASET/" "$STUDIO_USER_HOST:av-live-action/dataset/"

log "== Remote uv sync =="
# multihmr extra pulls torch (action-head training needs torch but no pyobjc).
# We piggy-back on the multihmr extras since torch is the main thing we need.
bastion_ssh "cd $REMOTE_REPO && $STUDIO_UV sync --no-progress --project data_only_viz --extra multihmr"

log "== Remote train (MPS) =="
# cwd must be the PARENT of data_only_viz/ so the package is importable as
# top-level. uv resolves the env via --project data_only_viz.
bastion_ssh "cd $REMOTE_REPO && \
             $STUDIO_UV run --project data_only_viz python -m data_only_viz.training.train_action_head \
                 --dataset $REMOTE_DATASET/$(basename "$DATASET_FILE") \
                 --ckpt-out $REMOTE_CKPT/$CKPT_NAME \
                 --device mps \
                 $TRAIN_ARGS"

log "== Pull checkpoint back =="
bastion_rsync "$STUDIO_USER_HOST:av-live-action/checkpoints/" "$LOCAL_CKPT/"

log "== Done. Checkpoint: $LOCAL_CKPT/$CKPT_NAME =="
ls -la "$LOCAL_CKPT/$CKPT_NAME"
