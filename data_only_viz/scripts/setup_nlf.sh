#!/usr/bin/env bash
set -euo pipefail
CACHE="$HOME/.cache/av-live-nlf"
mkdir -p "$CACHE"

# NLF Large multi-person TorchScript (470 MB)
CKPT="$CACHE/nlf_l_multi.torchscript"
if [ ! -f "$CKPT" ]; then
    echo "Downloading NLF-L multi-person (470 MB)..."
    curl -fL --progress-bar \
        "https://github.com/isarandi/nlf/releases/download/v0.3.2/nlf_l_multi_0.3.2.torchscript" \
        -o "$CKPT"
fi

# NLF Small multi-person TorchScript (284 MB) — fallback plus rapide
CKPT_S="$CACHE/nlf_s_multi.torchscript"
if [ ! -f "$CKPT_S" ]; then
    echo "Downloading NLF-S multi-person (284 MB)..."
    curl -fL --progress-bar \
        "https://github.com/isarandi/nlf/releases/download/v0.2.2/nlf_s_multi_0.2.2.torchscript" \
        -o "$CKPT_S"
fi

echo "Setup OK. Cache : $CACHE"
ls -lh "$CACHE"/*.torchscript
