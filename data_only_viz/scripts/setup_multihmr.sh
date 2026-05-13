#!/usr/bin/env bash
# Setup Multi-HMR : clone repo, telecharge checkpoint base (88 MB), prepare
# le dossier SMPL-X. SMPLX_NEUTRAL.npz necessite une inscription manuelle
# sur https://smpl-x.is.tue.mpg.de/ (academic license MPII).
set -euo pipefail
CACHE="$HOME/.cache/av-live-multihmr"
mkdir -p "$CACHE/checkpoints" "$CACHE/models/smplx"

if [ ! -d "$CACHE/multi-hmr" ]; then
    echo "==> Clone Multi-HMR"
    git clone --depth=1 https://github.com/naver/multi-hmr.git "$CACHE/multi-hmr"
fi

CKPT="$CACHE/checkpoints/multiHMR_896_L.pt"
if [ ! -f "$CKPT" ]; then
    echo "==> Telechargement checkpoint multiHMR_896_L (ViT-L)"
    # Source primaire : Naver Labs Europe ; fallback : HuggingFace mirror
    if ! curl -fL --progress-bar \
        "https://download.europe.naverlabs.com/ComputerVision/MultiHMR/multiHMR_896_L.pt" \
        -o "$CKPT"; then
        echo "==> Fallback HuggingFace"
        curl -fL --progress-bar \
            "https://huggingface.co/naver/multiHMR_896_L/resolve/main/multiHMR_896_L.pt" \
            -o "$CKPT"
    fi
fi

SMPLX="$CACHE/models/smplx/SMPLX_NEUTRAL.npz"
if [ ! -f "$SMPLX" ]; then
    echo ""
    echo "MANUEL REQUIS :"
    echo "  1. Inscrivez-vous sur https://smpl-x.is.tue.mpg.de/"
    echo "  2. Telechargez 'SMPL-X v1.1 (NPZ + PKL)'"
    echo "  3. Extraire SMPLX_NEUTRAL.npz vers : $SMPLX"
fi

echo "Setup OK. Cache : $CACHE"
