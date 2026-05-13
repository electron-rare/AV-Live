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
STUDIO_UV="${STUDIO_UV:-/opt/homebrew/bin/uv}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
LOCAL_CACHE="$HOME/.cache/av-live-action"
LOCAL_DATASET="$LOCAL_CACHE/dataset"
LOCAL_CKPT="$LOCAL_CACHE/checkpoints"

REMOTE_ROOT="\$HOME/av-live-action"
REMOTE_REPO="$REMOTE_ROOT/repo"
REMOTE_DATASET="$REMOTE_ROOT/dataset"
REMOTE_CKPT="$REMOTE_ROOT/checkpoints"

DATASET_FILE="${DATASET_FILE:-$LOCAL_DATASET/dataset.jsonl}"
CKPT_NAME="${CKPT_NAME:-action_head.pt}"
TRAIN_ARGS="$*"

log() { printf '[train_on_studio] %s\n' "$*" >&2; }

[[ -f "$DATASET_FILE" ]] || { log "missing dataset: $DATASET_FILE"; exit 2; }
mkdir -p "$LOCAL_CKPT"

bastion_ssh() {
  ssh -o ConnectTimeout=5 "$BASTION_USER_HOST" \
      "ssh -o ConnectTimeout=5 $STUDIO_USER_HOST $*"
}

bastion_rsync() {
  # rsync via ssh ProxyCommand through bastion.
  local src="$1" dst="$2"
  rsync -avz --delete \
    -e "ssh -o ConnectTimeout=5 -A -J $BASTION_USER_HOST" \
    "$src" "$dst"
}

log "== Studio reachability =="
bastion_ssh "echo studio OK ; $STUDIO_UV --version"

log "== Push code subset =="
bastion_ssh "mkdir -p $REMOTE_REPO/data_only_viz $REMOTE_DATASET $REMOTE_CKPT"
bastion_rsync "$REPO_ROOT/data_only_viz/" \
              "$STUDIO_USER_HOST:av-live-action/repo/data_only_viz/"

log "== Push dataset =="
bastion_rsync "$LOCAL_DATASET/" "$STUDIO_USER_HOST:av-live-action/dataset/"

log "== Remote uv sync =="
bastion_ssh "cd $REMOTE_REPO/data_only_viz && $STUDIO_UV sync --no-progress"

log "== Remote train (MPS) =="
bastion_ssh "cd $REMOTE_REPO/data_only_viz && \
             $STUDIO_UV run python -m data_only_viz.training.train_action_head \
                 --dataset $REMOTE_DATASET/$(basename "$DATASET_FILE") \
                 --ckpt-out $REMOTE_CKPT/$CKPT_NAME \
                 --device mps \
                 $TRAIN_ARGS"

log "== Pull checkpoint back =="
bastion_rsync "$STUDIO_USER_HOST:av-live-action/checkpoints/" "$LOCAL_CKPT/"

log "== Done. Checkpoint: $LOCAL_CKPT/$CKPT_NAME =="
ls -la "$LOCAL_CKPT/$CKPT_NAME"
