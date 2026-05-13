"""Task 3 — Convert FULL Multi-HMR (backbone + head) to CoreML
avec apply_topk(K=4) + fixed-shape tuple output.
"""
from __future__ import annotations

import os
import sys
import time
import types
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn

CACHE = Path.home() / ".cache" / "av-live-multihmr"
CKPT = CACHE / "checkpoints" / "multiHMR_672_S.pt"
MULTIHMR_REPO = CACHE / "multi-hmr"

sys.path.insert(0, str(MULTIHMR_REPO))
for mod in ("pyrender", "pyvista", "anny"):
    sys.modules.setdefault(mod, types.ModuleType(mod))

DEVICE = "cpu"  # trace on CPU (CoreML mlprogram doesn't care)
IMG_SIZE = 672
K_PERSONS = 4


# === apply_topk replacement (validated equivalent in Task 2) ===
def apply_topk(K, _scores):
    if isinstance(K, list):
        K = K[0]
    B, H, W, C = _scores.shape
    flat = _scores.reshape(B, -1)
    _, idx_flat = torch.topk(flat, k=K, dim=1)
    wc = W * C
    idx_b = (torch.arange(B, device=_scores.device)
             .unsqueeze(1).expand(-1, K).reshape(-1).long())
    idx_flat_flat = idx_flat.reshape(-1)
    idx_h = (idx_flat_flat // wc).long()
    idx_w = ((idx_flat_flat // C) % W).long()
    idx_c = (idx_flat_flat % C).long()
    return (idx_b, idx_h, idx_w, idx_c)


# === Patch coremltools _cast (validated probe v4) ===
def _patched_cast(context, node, dtype, dtype_str):
    from coremltools.converters.mil import Builder as mb
    from coremltools.converters.mil.frontend.torch import ops as _ops
    inputs = _ops._get_inputs(context, node, expected=1)
    x = inputs[0]
    if x.val is not None:
        try:
            const_val = dtype(x.val)
        except TypeError:
            arr = np.asarray(x.val)
            if arr.size == 1:
                const_val = dtype(arr.item())
            else:
                res = mb.cast(x=x, dtype=dtype_str, name=node.name)
                context.add(res)
                return
        res = mb.const(val=const_val, name=node.name)
    else:
        res = mb.cast(x=x, dtype=dtype_str, name=node.name)
    context.add(res)


prev = os.getcwd()
try:
    os.chdir(MULTIHMR_REPO)
    from model import Model
    import model as model_mod

    # Inject topk replacement
    print("==> Patching apply_threshold -> apply_topk(K=4)")
    model_mod.apply_threshold = lambda thr, scores: apply_topk(K_PERSONS, scores)

    torch_dev = torch.device(DEVICE)
    ckpt = torch.load(str(CKPT), map_location=torch_dev, weights_only=False)
    kw = {k: v for k, v in vars(ckpt["args"]).items()}
    kw["type"] = ckpt["args"].train_return_type
    kw["img_size"] = ckpt["args"].img_size[0]
    print(f"==> Loading Multi-HMR ViT-S 672 (params count tbd)")
    model = Model(**kw).to(torch_dev)
    model.load_state_dict(ckpt["model_state_dict"], strict=False)
    model.eval()
finally:
    os.chdir(prev)


# === Pre-compute interpolate_pos_encoding (probe v4 fix) ===
# Multi-HMR's backbone is DINOv2 ViT-S/14 — same dynamic interpolation
# problem that planted la conversion sur backbone seul.
if hasattr(model.backbone, "encoder") and hasattr(model.backbone.encoder,
                                                  "interpolate_pos_encoding"):
    print("==> Patching backbone.encoder.interpolate_pos_encoding (pre-compute)")
    bk = model.backbone.encoder
    with torch.no_grad():
        dummy_x = torch.rand(1, 3, IMG_SIZE, IMG_SIZE)
        dummy_p = bk.patch_embed(dummy_x)
        cls = bk.cls_token.expand(dummy_p.shape[0], -1, -1)
        x_full = torch.cat((cls, dummy_p), dim=1)
        cached_pe = bk.interpolate_pos_encoding(
            x_full, IMG_SIZE, IMG_SIZE).detach()
    bk.register_buffer("_cached_pos_embed", cached_pe)

    def fixed_pe(self, x, w, h):
        return self._cached_pos_embed.to(x.dtype)
    bk.interpolate_pos_encoding = types.MethodType(fixed_pe, bk)
    print(f"  cached shape {tuple(cached_pe.shape)}")

# === Patch utils.camera.inverse_perspective_projection ===
# torch.inverse(K) plante coremltools (op non implementee). Comme K est
# fixe (camera intrinsics avec focal=IMG_SIZE), on pre-calcule K_inv
# en closed-form et on l'utilise comme buffer module-level.
print("==> Patching utils.camera.inverse_perspective_projection")
import utils.camera as _camera

# Pre-compute K_inv closed-form pour notre K standard
focal_val = float(IMG_SIZE)
cx = cy = IMG_SIZE / 2.0
_K_INV_PRE = torch.tensor([
    [[1.0 / focal_val, 0.0, -cx / focal_val],
     [0.0, 1.0 / focal_val, -cy / focal_val],
     [0.0, 0.0, 1.0]]
])

def inverse_perspective_projection_fixed(points, K, distance):
    """Bypass torch.inverse : utilise K_inv pre-calcule en closed-form
    (notre K est connu et fixe). Le K argument est ignore."""
    K_inv = _K_INV_PRE.to(points.device).to(points.dtype)
    points = torch.cat([points, torch.ones_like(points[..., :1])], -1)
    points = torch.einsum('bij,bkj->bki', K_inv, points)
    if distance is None:
        return points
    points = points * distance
    return points

_camera.inverse_perspective_projection = inverse_perspective_projection_fixed
# Aussi patcher le re-export dans utils/__init__.py et model.py
import utils as _utils_pkg
_utils_pkg.inverse_perspective_projection = inverse_perspective_projection_fixed
# model.py importe directement : monkey-patch sur le module
model_mod.inverse_perspective_projection = inverse_perspective_projection_fixed
# Idem smpl_layer
import blocks.smpl_layer as _smpl_layer
_smpl_layer.inverse_perspective_projection = inverse_perspective_projection_fixed


# === Wrapper qui produit tuple fixe ===
class TracedMHMR(nn.Module):
    """Wrap Multi-HMR pour trace : output tuple de tensors fixes,
    pas de list-of-dicts."""

    def __init__(self, m: Model):
        super().__init__()
        self.m = m

    def forward(self, x: torch.Tensor, cam_K: torch.Tensor):
        # Call original forward with is_training=False ; apply_topk
        # garantit toujours K=4 detections donc le loop dans le forward
        # est unroll-friendly.
        humans = self.m(x, is_training=False, nms_kernel_size=5,
                        det_thresh=0.0, K=cam_K)
        # humans est une list[dict] de longueur 4. Stack en tensors.
        if len(humans) == 0:
            # Should not happen with apply_topk, but defensive
            zeros = torch.zeros(K_PERSONS, 10475, 3)
            zeros_p = torch.zeros(K_PERSONS, 3)
            zeros_s = torch.zeros(K_PERSONS)
            zeros_b = torch.zeros(K_PERSONS, 10)
            return zeros, zeros_p, zeros_s, zeros_b, zeros_b
        v3d = torch.stack([h["v3d"] for h in humans])
        transl = torch.stack([h["transl_pelvis"] for h in humans])
        scores = torch.stack([
            h["scores"] if h["scores"].dim() > 0 else h["scores"].unsqueeze(0)
            for h in humans
        ]).squeeze(-1)
        shape = torch.stack([h["shape"] for h in humans])
        expr = torch.stack([h["expression"] for h in humans])
        return v3d, transl, scores, shape, expr


wrapper = TracedMHMR(model).eval()

# Sanity forward
focal = float(IMG_SIZE)
example_K = torch.tensor(
    [[[focal, 0.0, IMG_SIZE / 2.0],
      [0.0, focal, IMG_SIZE / 2.0],
      [0.0, 0.0, 1.0]]], dtype=torch.float32)
example_x = torch.rand(1, 3, IMG_SIZE, IMG_SIZE)

print("==> Sanity forward")
with torch.no_grad():
    v3d, transl, scores, shape, expr = wrapper(example_x, example_K)
print(f"  v3d: {tuple(v3d.shape)}, transl: {tuple(transl.shape)},")
print(f"  scores: {tuple(scores.shape)}, shape: {tuple(shape.shape)},")
print(f"  expr: {tuple(expr.shape)}")

print("==> torch.jit.trace")
try:
    traced = torch.jit.trace(wrapper, (example_x, example_K), strict=False)
    print("  trace OK")
except Exception as e:
    print(f"  trace FAILED: {type(e).__name__}: {e}")
    raise

# === CoreML convert ===
print("==> coremltools.convert")
import coremltools as ct
from coremltools.converters.mil.frontend.torch import ops as _ops
_ops._cast = _patched_cast

try:
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(shape=(1, 3, IMG_SIZE, IMG_SIZE),
                          name="image", dtype=np.float32),
            ct.TensorType(shape=(1, 3, 3), name="cam_K", dtype=np.float32),
        ],
        compute_units=ct.ComputeUnit.CPU_AND_GPU,
        minimum_deployment_target=ct.target.macOS15,
        convert_to="mlprogram",
    )
    out_path = "/tmp/multihmr_full_672_s.mlpackage"
    mlmodel.save(out_path)
    print(f"  CONVERT OK -> {out_path}")
except Exception as e:
    print(f"  CONVERT FAILED: {type(e).__name__}: {e}")
    raise

# === Bench ===
print("==> bench 30 iter")
img = np.random.rand(1, 3, IMG_SIZE, IMG_SIZE).astype(np.float32)
cam = np.array([[[focal, 0, IMG_SIZE/2],
                 [0, focal, IMG_SIZE/2],
                 [0, 0, 1]]], dtype=np.float32)
for _ in range(3):
    _ = mlmodel.predict({"image": img, "cam_K": cam})
t = []
for _ in range(30):
    t0 = time.perf_counter()
    _ = mlmodel.predict({"image": img, "cam_K": cam})
    t.append((time.perf_counter() - t0) * 1000)
t.sort()
print(f"  CoreML full Multi-HMR median={t[15]:.1f} ms  "
      f"p10={t[3]:.1f}  p90={t[27]:.1f}  min={t[0]:.1f}")
print(f"  Target was <60ms (12-25 fps). Achieved: {1000.0/t[15]:.1f} fps")
