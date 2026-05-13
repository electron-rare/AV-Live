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

CKPT="$CACHE/checkpoints/multiHMR_672_S.pt"
if [ ! -f "$CKPT" ]; then
    echo "==> Telechargement checkpoint multiHMR_672_S (ViT-S)"
    # Source primaire : Naver Labs Europe ; fallback : HuggingFace mirror
    if ! curl -fL --progress-bar \
        "https://download.europe.naverlabs.com/ComputerVision/MultiHMR/multiHMR_672_S.pt" \
        -o "$CKPT"; then
        echo "==> Fallback HuggingFace"
        curl -fL --progress-bar \
            "https://huggingface.co/naver/multiHMR_672_S/resolve/main/multiHMR_672_S.pt" \
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

# Mean params SMPL (init parameters) — necessaire au constructeur Model
MEAN="$CACHE/models/smpl_mean_params.npz"
if [ ! -f "$MEAN" ]; then
    echo "==> Telechargement smpl_mean_params (1.3 KB)"
    curl -fL --progress-bar \
        "https://openmmlab-share.oss-cn-hangzhou.aliyuncs.com/mmhuman3d/models/smpl_mean_params.npz?versionId=CAEQHhiBgICN6M3V6xciIDU1MzUzNjZjZGNiOTQ3OWJiZTJmNThiZmY4NmMxMTM4" \
        -o "$MEAN"
fi

# Symlink relatif 'models' dans le repo Multi-HMR pour que SMPLX_DIR='models'
# (utils/constants.py) trouve les .npz.
if [ ! -e "$CACHE/multi-hmr/models" ]; then
    ln -sfn ../models "$CACHE/multi-hmr/models"
fi

# CoreML conversion patches : remplace les torch.einsum dans utils/camera.py
# par des ops element-wise (broadcast-friendly). Sans ca, ct.convert echoue
# avec "Invalid target shape in reshape op ([1, N, 3] to [K*N, 3, 1])"
# quand batch K detections != 1. Idempotent.
CAM="$CACHE/multi-hmr/utils/camera.py"
if [ -f "$CAM" ] && ! grep -q "_apply_intrinsics_componentwise" "$CAM"; then
    echo "==> Patch utils/camera.py (einsum -> componentwise)"
    python3 - "$CAM" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text()
helper = '''
def _apply_intrinsics_componentwise(K, y):
    """CoreML-friendly: out[b,k,i] = sum_j K[b,i,j] * y[b,k,j]
    Replaces torch.einsum('bij,bkj->bki', K, y) with pure broadcast ops.
    """
    K00 = K[:, 0:1, 0:1]; K01 = K[:, 0:1, 1:2]; K02 = K[:, 0:1, 2:3]
    K10 = K[:, 1:2, 0:1]; K11 = K[:, 1:2, 1:2]; K12 = K[:, 1:2, 2:3]
    K20 = K[:, 2:3, 0:1]; K21 = K[:, 2:3, 1:2]; K22 = K[:, 2:3, 2:3]
    y0 = y[:, :, 0:1]; y1 = y[:, :, 1:2]; y2 = y[:, :, 2:3]
    out0 = K00 * y0 + K01 * y1 + K02 * y2
    out1 = K10 * y0 + K11 * y1 + K12 * y2
    out2 = K20 * y0 + K21 * y1 + K22 * y2
    return torch.cat([out0, out1, out2], dim=-1)


'''
src = src.replace(
    "def perspective_projection(x, K):",
    helper + "def perspective_projection(x, K):",
)
src = src.replace(
    "y = torch.einsum('bij,bkj->bki', K, y)  # (bs, N, 3)",
    "y = _apply_intrinsics_componentwise(K, y)",
)
src = src.replace(
    "points = torch.einsum('bij,bkj->bki', torch.inverse(K), points)",
    "points = _apply_intrinsics_componentwise(torch.inverse(K), points)",
)
p.write_text(src)
print("  camera.py patched")
PYEOF
fi

# CoreML conversion patch : smplx/lbs.py landmarks einsum (mеme bug broadcast)
# Patch best-effort sur tous les venvs presents (data_only_viz + /tmp/coreml312).
for VENV in \
    "$(dirname "$(dirname "$(readlink -f "$0")")")/.venv" \
    "/tmp/coreml312"; do
    LBS="$VENV/lib/python3.14/site-packages/smplx/lbs.py"
    [ -f "$LBS" ] || LBS="$VENV/lib/python3.12/site-packages/smplx/lbs.py"
    if [ -f "$LBS" ] && grep -q "torch.einsum('blfi,blf->bli'" "$LBS"; then
        echo "==> Patch $LBS (landmarks einsum)"
        python3 - "$LBS" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = s.replace(
    "landmarks = torch.einsum('blfi,blf->bli', [lmk_vertices, lmk_bary_coords])\n    return landmarks",
    "# CoreML-friendly: replace einsum('blfi,blf->bli', ...) with broadcast+sum\n    landmarks = (lmk_vertices * lmk_bary_coords.unsqueeze(-1)).sum(dim=2)\n    return landmarks",
)
p.write_text(s)
print("  smplx/lbs.py patched")
PYEOF
    fi
done

echo "Setup OK. Cache : $CACHE"
