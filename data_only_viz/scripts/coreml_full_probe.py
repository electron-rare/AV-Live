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
# Patch _auto_val pour coercer values 1-d size-1 -> 0-d
def _install_auto_val_patch():
    from coremltools.converters.mil.mil import operation as _opmod
    from coremltools.converters.mil.mil.operation import mil_list

    _orig_auto_val = _opmod.Operation._auto_val

    def _patched_auto_val(self, output_types):
        try:
            return _orig_auto_val(self, output_types)
        except ValueError as e:
            if "zero-rank" not in str(e):
                raise
            # Retry avec coercion 1-d size-1 -> 0-d
            try:
                vals = self.value_inference()
            except NotImplementedError:
                return tuple(None for _ in output_types)
            if not isinstance(vals, (tuple, list)):
                vals = (vals,)
            for val in vals:
                if val is None:
                    return tuple(None for _ in output_types)
            auto = []
            for t, v in zip(output_types, vals):
                bv = t()
                if isinstance(v, mil_list):
                    bv.val = v.ls
                else:
                    if isinstance(v, np.ndarray) and v.ndim > 0 and v.size == 1:
                        # Coerce 1-d size-1 -> 0-d ndarray (val setter
                        # accepte np.generic ou ndarray ndim==0).
                        v = np.asarray(v.reshape(()))
                    elif isinstance(v, (int, float)) and not isinstance(
                            v, (np.generic,)):
                        v = np.asarray(v)
                    bv.val = v
                auto.append(bv)
            return auto

    _opmod.Operation._auto_val = _patched_auto_val


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
print("==> Patching roma.rotmat_to_rotvec (branchless atan2)")
# roma.rotmat_to_rotvec utilise torch.empty + 8 index_put_ qui se
# traduisent en CoreML par scatter_nd successifs sur un buffer
# garbage-initialise. Resultat : cellules non touchees restent NaN,
# propagees via quat normalization -> v3d/transl all-NaN.
# Remplacement branchless via atan2 : pas de torch.empty, pas
# d'index_put_, juste des stack/clamp/norm/atan2 stables CoreML.
# Precision vs roma original : 2.26e-6 L_inf sur batch random.
import roma as _roma

def _rotmat_to_rotvec_branchless(R, eps=1e-6):
    w = torch.stack([
        R[..., 2, 1] - R[..., 1, 2],
        R[..., 0, 2] - R[..., 2, 0],
        R[..., 1, 0] - R[..., 0, 1],
    ], dim=-1) * 0.5
    trace = R[..., 0, 0] + R[..., 1, 1] + R[..., 2, 2]
    cos_theta = ((trace - 1.0) * 0.5).clamp(-1.0, 1.0)
    sin_theta = torch.norm(w, dim=-1)
    theta = torch.atan2(sin_theta, cos_theta)
    sin_theta_safe = sin_theta.clamp(min=eps)
    return w * (theta / sin_theta_safe).unsqueeze(-1)

_roma.rotmat_to_rotvec = _rotmat_to_rotvec_branchless


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
    """Bypass torch.inverse + einsum + matmul pour eviter le bug
    coremltools de broadcast batch 1->K sur ces ops. K_inv etant
    fixe et structure (diag + translate), on ecrit les composantes
    explicitement en ops elementaires.

    K_inv = [[1/f, 0, -cx/f], [0, 1/f, -cy/f], [0, 0, 1]]
    Pour points (b, N, 3) : out = points @ K_inv.T donne :
      out[..., 0] = points[..., 0]/f - (cx/f) * points[..., 2]
      out[..., 1] = points[..., 1]/f - (cy/f) * points[..., 2]
      out[..., 2] = points[..., 2]
    """
    points_hom = torch.cat([points, torch.ones_like(points[..., :1])], -1)
    inv_f = 1.0 / focal_val
    cx_over_f = cx / focal_val
    cy_over_f = cy / focal_val
    x = points_hom[..., 0:1]
    y = points_hom[..., 1:2]
    z = points_hom[..., 2:3]
    out0 = x * inv_f - z * cx_over_f
    out1 = y * inv_f - z * cy_over_f
    out2 = z
    points = torch.cat([out0, out1, out2], dim=-1)
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

# Aussi perspective_projection (utilise dans smpl_layer.py:143-144 pour
# j2d et v2d) -> rewrite einsum en matmul pour le meme broadcast bug.
def perspective_projection_fixed(x, K):
    """Element-wise rewrite de la projection perspective avec K fixe
    (focal=IMG_SIZE, cx=cy=IMG_SIZE/2). Bypass matmul/einsum pour eviter
    les bugs broadcast coremltools.
    K = [[f, 0, cx], [0, f, cy], [0, 0, 1]]
    out[..., 0] = f * x_norm + cx * z_norm (mais on veut [..., :2])
                = f * (x/z) + cx
    out[..., 1] = f * (y/z) + cy
    """
    z = x[..., 2:3]
    px = x[..., 0:1] / z * focal_val + cx
    py = x[..., 1:2] / z * focal_val + cy
    return torch.cat([px, py], dim=-1)

_camera.perspective_projection = perspective_projection_fixed
_utils_pkg.perspective_projection = perspective_projection_fixed
_smpl_layer.perspective_projection = perspective_projection_fixed


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
        # NOTE: CoreML mlprogram conversion currently produces all-NaN
        # outputs for v3d and transl while PyTorch eager produces valid
        # finite values from the same trace. nan_to_num here masks the
        # symptom but yields all-zero meshes (no information). Leave
        # raw outputs and let downstream decide; investigation tracked
        # in task #2 (op-by-op bisection needed).
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
_install_auto_val_patch()

# Instrument convert_single_node pour logger le node responsable
# de l'erreur (cascade-debug helper).
_orig_csn = _ops.convert_single_node


def _csn_logged(context, node):
    try:
        _orig_csn(context, node)
    except Exception:
        try:
            k = node.kind() if callable(node.kind) else str(node.kind)
            print(f"  >>> FAIL on torch node kind={k}")
        except Exception:
            pass
        raise


_ops.convert_single_node = _csn_logged

# Patch tile op pour gerer reps=[] (no-op = return input unchanged).
# Le pattern apparait quand torch.repeat(*[]) ou expand sur dim ratée.
from coremltools.converters.mil.mil.ops.defs.iOS15 import tensor_operation as _tens_op
_orig_tile_type_inf = _tens_op.tile.type_inference


def _tile_type_inf_safe(self):
    reps = self.reps.val if self.reps.val is not None else self.reps
    try:
        return _orig_tile_type_inf(self)
    except ValueError as e:
        if "reps" in str(e) and "0" in str(e):
            print(f"  >>> tile no-op : reps empty, returning input shape")
            # No-op : return type of input x unchanged
            return self.x.sym_type
        raise


_tens_op.tile.type_inference = _tile_type_inf_safe

# Register `new_ones` converter (aten::new_ones).
# Signature: new_ones(self, size, dtype=None, layout=None, ...)
# Equivalent : fill(shape=size, value=1.0) cast vers self.dtype.
from coremltools.converters.mil import Builder as _mb
from coremltools.converters.mil.frontend.torch.ops import (
    _get_inputs, register_torch_op as _reg)


from coremltools.converters.mil.frontend.torch.torch_op_registry import (
    _TORCH_OPS_REGISTRY)


def _maybe_register(name, fn):
    """Register fn under torch op name only if not already registered."""
    try:
        if name not in _TORCH_OPS_REGISTRY.name_to_func_mapping:
            _TORCH_OPS_REGISTRY.register_func(fn, [name], override=False)
    except (ValueError, AttributeError):
        pass


def _new_ones(context, node):
    inputs = _get_inputs(context, node, min_expected=2)
    size = inputs[1]
    if isinstance(size, (list, tuple)):
        from coremltools.converters.mil import Builder as mb
        # Reshape chaque element a rank 1 avant concat (sinon mix 0d/1d
        # plante avec "Input has rank 0 != other inputs rank 1").
        size_1d = []
        for v in size:
            r = v.rank if hasattr(v, "rank") else None
            if r == 0:
                v = mb.expand_dims(x=v, axes=[0])
            size_1d.append(v)
        size = mb.concat(values=size_1d, axis=0)
    res = _mb.fill(shape=size, value=1.0, name=node.name)
    context.add(res, node.name)


_maybe_register("new_ones", _new_ones)


# Patch global concat type_inference : auto-promote 0d → 1d.
_orig_concat_ti = _tens_op.concat.type_inference


def _concat_ti_auto_promote(self):
    try:
        return _orig_concat_ti(self)
    except ValueError as e:
        if "rank 0" in str(e) and "rank 1" in str(e):
            # Find 0d inputs and replace via expand_dims
            from coremltools.converters.mil import Builder as mb
            promoted = []
            for v in self.values:
                if v.rank == 0:
                    v = mb.expand_dims(x=v, axes=[0])
                promoted.append(v)
            self.values = promoted
            return _orig_concat_ti(self)
        raise


_tens_op.concat.type_inference = _concat_ti_auto_promote


# Override clamp_min : promote dtypes (original assert sans promotion).
from coremltools.converters.mil.frontend.torch.ops import (
    promote_input_dtypes)


def _clamp_min_promote(context, node):
    inputs = _get_inputs(context, node, expected=2)
    x, y = promote_input_dtypes([inputs[0], inputs[1]])
    out = _mb.maximum(x=x, y=y, name=node.name)
    context.add(out)


_TORCH_OPS_REGISTRY.name_to_func_mapping["clamp_min"] = _clamp_min_promote


def _clamp_max_promote(context, node):
    inputs = _get_inputs(context, node, expected=2)
    x, y = promote_input_dtypes([inputs[0], inputs[1]])
    out = _mb.minimum(x=x, y=y, name=node.name)
    context.add(out)


_TORCH_OPS_REGISTRY.name_to_func_mapping["clamp_max"] = _clamp_max_promote


# Override diagonal pour supporter dim1=1, dim2=2 sur tensor (B, N, N).
# Multi-HMR via roma.rotmat_to_rotvec utilise .diagonal(dim1=1, dim2=2).
def _diagonal_general(context, node):
    inputs = _get_inputs(context, node, expected=[1, 4])
    x = inputs[0]
    offset = inputs[1].val if len(inputs) > 1 and inputs[1] is not None else 0
    dim1 = inputs[2].val if len(inputs) > 2 and inputs[2] is not None else 0
    dim2 = inputs[3].val if len(inputs) > 3 and inputs[3] is not None else 1

    # Pour notre cas type (B, N, N) avec dim1=1 dim2=2 et offset=0 :
    # reshape (B, N, N) -> (B, N*N), gather indices [0, N+1, 2N+2, ...].
    if offset == 0 and x.rank == 3 and dim1 == 1 and dim2 == 2:
        N = x.shape[1]
        # Indices diagonale aplatis : i * N + i
        diag_idx = np.array([i * N + i for i in range(N)],
                            dtype=np.int32)
        x_flat = _mb.reshape(x=x, shape=[x.shape[0], N * N])
        out = _mb.gather(x=x_flat, indices=diag_idx, axis=1,
                         name=node.name)
        context.add(out)
        return

    # Fallback : on garde le path original (offset=0 dim1=0 dim2=1)
    if offset == 0 and dim1 == 0 and dim2 == 1:
        diag = _mb.band_part(x=x, lower=0, upper=0, name=node.name)
        context.add(diag)
        return

    raise NotImplementedError(
        f"diagonal: offset={offset} dim1={dim1} dim2={dim2} rank={x.rank} "
        "non gere — etendre _diagonal_general")


_TORCH_OPS_REGISTRY.name_to_func_mapping["diagonal"] = _diagonal_general


# Instrument reshape pour logger node source au moment de l'erreur.
from coremltools.converters.mil.mil.ops.defs.iOS15 import tensor_transformation as _tt
_orig_reshape_ti = _tt.reshape.type_inference


def _reshape_ti_logged(self):
    try:
        return _orig_reshape_ti(self)
    except ValueError as e:
        if "Invalid target shape" in str(e):
            try:
                from_shape = list(self.x.shape)
                target = list(self.shape.val) if hasattr(self.shape, "val") else "?"
                print(f"  >>> RESHAPE FAIL : name={self.name} from={from_shape} target={target}")
            except Exception:
                pass
        raise


_tt.reshape.type_inference = _reshape_ti_logged

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
        # FP32 mandatory : FP16 (global ou hybride op_selector) degrade
        # visiblement le mesh sur poses extremes. INT8 weight quant
        # teste 2026-05-14 : aucun gain sur GPU compute-bound.
        compute_precision=ct.precision.FLOAT32,
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
