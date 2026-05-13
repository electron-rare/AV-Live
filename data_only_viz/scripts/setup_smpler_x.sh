#!/usr/bin/env bash
# Setup SMPLer-X-S inference pipeline pour ARM Mac (M5).
#
# Stratégie : SMPLer-X vendorise sa propre copie de mmpose dans
# transformer_utils/mmpose/, donc on n'a besoin que de :
#   - mmcv-lite (pour `from mmcv import Config`)
#   - smplx (pour decode SMPL-X params)
#   - YOLO/Ultralytics (déjà dans extras pose) pour body detection
#
# On évite mmdet/mmcv-full/mmpose pip installs qui plantent sur ARM
# Python 3.14.
set -euo pipefail

CACHE="$HOME/.cache/av-live-smplerx"
# Repo source = git submodule electron-rare/SMPLer-X (fork S-Lab 1.0)
# initialise au niveau du repo AV-Live racine.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO="$REPO_ROOT/third_party/SMPLer-X"

mkdir -p "$CACHE/checkpoints" "$CACHE/models/smplx"

if [ ! -d "$REPO/main" ]; then
    echo "==> Init git submodule SMPLer-X"
    ( cd "$REPO_ROOT" && git submodule update --init third_party/SMPLer-X )
fi

CKPT="$CACHE/checkpoints/smpler_x_s32.pth.tar"
if [ ! -f "$CKPT" ]; then
    echo "==> Telechargement SMPLer-X-S checkpoint (ViT-S, ~150 MB)"
    curl -fL --progress-bar \
        "https://huggingface.co/caizhongang/SMPLer-X/resolve/main/smpler_x_s32.pth.tar" \
        -o "$CKPT" \
        || { echo "ERREUR download checkpoint"; exit 1; }
fi

SMPLX="$CACHE/models/smplx/SMPLX_NEUTRAL.npz"
SHARED="$HOME/.cache/av-live-multihmr/models/smplx/SMPLX_NEUTRAL.npz"
if [ ! -f "$SMPLX" ]; then
    if [ -f "$SHARED" ]; then
        echo "==> Symlink SMPLX_NEUTRAL.npz depuis cache Multi-HMR"
        ln -sf "$SHARED" "$SMPLX"
    else
        echo ""
        echo "MANUEL REQUIS :"
        echo "  1. Inscrivez-vous sur https://smpl-x.is.tue.mpg.de/"
        echo "  2. Telechargez 'SMPL-X v1.1 (NPZ + PKL)'"
        echo "  3. Extraire SMPLX_NEUTRAL.npz vers : $SMPLX"
        echo "  OU lance d'abord scripts/setup_multihmr.sh et symlink."
    fi
fi

echo "Setup OK. Cache : $CACHE"
echo "Files :"
ls -lh "$CACHE/checkpoints/" 2>/dev/null
echo ""
echo "Next: ajouter 'mmcv-lite' au pyproject.toml et 'uv sync --extra smplerx'"
