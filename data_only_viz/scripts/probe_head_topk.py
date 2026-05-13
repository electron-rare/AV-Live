"""Task 2 — Validate apply_topk(K=4) as drop-in replacement for
apply_threshold in Multi-HMR head.

Compares v3d output between threshold-based (original) and topk-based
(patched) Multi-HMR on the same input. Pass criterion: for the same
detections (when K >= n_threshold_detected), v3d cosine similarity > 0.99.
"""
from __future__ import annotations

import os
import sys
import types
from pathlib import Path

import numpy as np
import torch

CACHE = Path.home() / ".cache" / "av-live-multihmr"
CKPT = CACHE / "checkpoints" / "multiHMR_672_S.pt"
MULTIHMR_REPO = CACHE / "multi-hmr"

sys.path.insert(0, str(MULTIHMR_REPO))
for mod in ("pyrender", "pyvista", "anny"):
    sys.modules.setdefault(mod, types.ModuleType(mod))

DEVICE = "mps" if torch.backends.mps.is_available() else "cpu"
IMG_SIZE = 672


def apply_topk(K, _scores):
    """Drop-in pour apply_threshold. _scores shape (B, H, W, C).
    Renvoie 4-tuple LongTensor (batch_idx, h_idx, w_idx, c_idx) chacun
    de longueur B*K (au lieu de variable). K candidate top-scoring
    tokens par image.
    """
    if isinstance(K, list):
        K = K[0]
    B, H, W, C = _scores.shape
    flat = _scores.reshape(B, -1)
    _, idx_flat = torch.topk(flat, k=K, dim=1)
    wc = W * C
    idx_b = (torch.arange(B, device=_scores.device)
             .unsqueeze(1).expand(-1, K).reshape(-1))
    idx_flat_flat = idx_flat.reshape(-1)
    idx_h = idx_flat_flat // wc
    idx_w = (idx_flat_flat // C) % W
    idx_c = idx_flat_flat % C
    return (idx_b.long(), idx_h.long(), idx_w.long(), idx_c.long())


prev = os.getcwd()
try:
    os.chdir(MULTIHMR_REPO)
    from model import Model
    import model as model_mod
    torch_dev = torch.device(DEVICE)
    ckpt = torch.load(str(CKPT), map_location=torch_dev, weights_only=False)
    kw = {k: v for k, v in vars(ckpt["args"]).items()}
    kw["type"] = ckpt["args"].train_return_type
    kw["img_size"] = ckpt["args"].img_size[0]
    model = Model(**kw).to(torch_dev)
    model.load_state_dict(ckpt["model_state_dict"], strict=False)
    model.eval()
finally:
    os.chdir(prev)

focal = float(IMG_SIZE)
K_mat = torch.tensor([[[focal, 0.0, IMG_SIZE / 2.0],
                       [0.0, focal, IMG_SIZE / 2.0],
                       [0.0, 0.0, 1.0]]], device=DEVICE)

# Use a real test image (multi-hmr example or webcam capture)
import cv2
img_path = "/Users/electron/.cache/av-live-multihmr/multi-hmr/example_data/4446582661_b188f82f3c_c.jpg"
img = cv2.imread(img_path)
h, w = img.shape[:2]
side = min(h, w)
y0 = (h - side) // 2; x0 = (w - side) // 2
img = cv2.resize(img[y0:y0+side, x0:x0+side], (IMG_SIZE, IMG_SIZE))
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
x = (torch.from_numpy(img_rgb).permute(2, 0, 1).float() / 255.0
     ).unsqueeze(0).to(DEVICE)
print(f"loaded image {img_path}")

# --- Pass 1 : original apply_threshold a tres bas seuil ---
print("==> Pass 1 : apply_threshold(0.15)")
with torch.no_grad():
    humans_orig = model(x, is_training=False, nms_kernel_size=5,
                        det_thresh=0.15, K=K_mat)
print(f"  detected: {len(humans_orig)}")
for i, h in enumerate(humans_orig[:4]):
    sc = h.get("scores", 0.0)
    if hasattr(sc, "item"):
        sc = sc.item()
    print(f"    [{i}] score={sc:.3f}  v3d.shape={tuple(h['v3d'].shape)}")

# --- Pass 2 : monkey-patch apply_threshold avec apply_topk(K=4) ---
print("\n==> Pass 2 : apply_topk(K=4)")
original_apply_threshold = model_mod.apply_threshold

def topk_wrapper(det_thresh, _scores):
    return apply_topk(4, _scores)

model_mod.apply_threshold = topk_wrapper

with torch.no_grad():
    humans_topk = model(x, is_training=False, nms_kernel_size=5,
                        det_thresh=0.15, K=K_mat)
print(f"  detected: {len(humans_topk)}")
for i, h in enumerate(humans_topk[:4]):
    sc = h.get("scores", 0.0)
    if hasattr(sc, "item"):
        sc = sc.item()
    print(f"    [{i}] score={sc:.3f}  v3d.shape={tuple(h['v3d'].shape)}")

# Restore
model_mod.apply_threshold = original_apply_threshold

# --- Comparison ---
print("\n==> Comparison")
if len(humans_orig) == 0 or len(humans_topk) == 0:
    print("  NO DETECTIONS in one path — adjust threshold lower")
    sys.exit(0)

# Match by score (highest first in both)
o = sorted(humans_orig, key=lambda h: -(
    h.get("scores", 0).item() if hasattr(h.get("scores", 0), "item")
    else h.get("scores", 0)))[:min(len(humans_orig), 4)]
t = sorted(humans_topk, key=lambda h: -(
    h.get("scores", 0).item() if hasattr(h.get("scores", 0), "item")
    else h.get("scores", 0)))[:len(o)]

for i, (ho, ht) in enumerate(zip(o, t)):
    vo = ho["v3d"].detach().cpu().numpy().flatten()
    vt = ht["v3d"].detach().cpu().numpy().flatten()
    dot = float(np.dot(vo, vt))
    nv = float(np.linalg.norm(vo) * np.linalg.norm(vt) + 1e-9)
    cos = dot / nv
    mae = float(np.mean(np.abs(vo - vt)))
    sco = (ho.get("scores", 0).item()
           if hasattr(ho.get("scores", 0), "item") else ho.get("scores", 0))
    sct = (ht.get("scores", 0).item()
           if hasattr(ht.get("scores", 0), "item") else ht.get("scores", 0))
    print(f"  [{i}] cosine={cos:.6f}  mae={mae*1000:.3f}mm  "
          f"score_orig={sco:.4f} score_topk={sct:.4f}")
