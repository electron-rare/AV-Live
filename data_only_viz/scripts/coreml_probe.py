"""DINOv2 ViT-S 672x672 backbone CoreML conversion + bench.

Probe v4 (2026-05-13) — résultat : conversion OK avec 2 patches,
bench M5 CoreML CPU_AND_GPU = 25 ms vs PyTorch MPS = 275 ms = 11.8x
speedup. ANE compute unit n'apporte rien (et ralentit) sur ce modele.

Patches requis :
  1. Pre-calculer interpolate_pos_encoding en buffer fige (sinon
     coremltools rejette l'interpolation dynamique).
  2. Patcher coremltools._cast pour gerer val non-scalaire via
     numpy.asarray().item() ou fallback mb.cast (sinon plante
     `dtype(x.val)` sur shape arithmetic int().
"""
from __future__ import annotations

import time
import types
import numpy as np
import torch
import coremltools as ct

H = W = 672


def _patched_cast(context, node, dtype, dtype_str):
    """Wrap coremltools _cast pour gerer x.val non-0d."""
    from coremltools.converters.mil import Builder as mb
    from coremltools.converters.mil.frontend.torch import ops as _ops
    inputs = _ops._get_inputs(context, node, expected=1)
    x = inputs[0]
    if x.val is not None:
        v = x.val
        try:
            const_val = dtype(v)
        except TypeError:
            arr = np.asarray(v)
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


def install_coreml_patches() -> None:
    from coremltools.converters.mil.frontend.torch import ops as _ops
    _ops._cast = _patched_cast


def build_dinov2_with_fixed_pos_embed():
    model = torch.hub.load(
        "facebookresearch/dinov2", "dinov2_vits14",
        pretrained=True, trust_repo=True)
    model.eval()
    with torch.no_grad():
        dummy_p = model.patch_embed(torch.rand(1, 3, H, W))
        cls = model.cls_token.expand(dummy_p.shape[0], -1, -1)
        x_full = torch.cat((cls, dummy_p), dim=1)
        cached_pe = model.interpolate_pos_encoding(x_full, H, W).detach()
    model.register_buffer("_cached_pos_embed", cached_pe)

    def fixed_pe(self, x, w, h):
        return self._cached_pos_embed.to(x.dtype)
    model.interpolate_pos_encoding = types.MethodType(fixed_pe, model)
    return model


def convert(model, out_path: str) -> ct.models.MLModel:
    example = torch.rand(1, 3, H, W)
    traced = torch.jit.trace(model, example, strict=False)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(
            shape=(1, 3, H, W), name="image", dtype=np.float32)],
        compute_units=ct.ComputeUnit.CPU_AND_GPU,
        minimum_deployment_target=ct.target.macOS15,
        convert_to="mlprogram",
    )
    mlmodel.save(out_path)
    return mlmodel


def bench(mlmodel, n: int = 50) -> dict:
    img = np.random.rand(1, 3, H, W).astype(np.float32)
    for _ in range(5):
        _ = mlmodel.predict({"image": img})
    t = []
    for _ in range(n):
        t0 = time.perf_counter()
        _ = mlmodel.predict({"image": img})
        t.append((time.perf_counter() - t0) * 1000)
    t.sort()
    return {
        "median_ms": t[n // 2],
        "p10_ms": t[max(0, int(n * 0.1) - 1)],
        "p90_ms": t[min(n - 1, int(n * 0.9))],
        "min_ms": t[0],
    }


if __name__ == "__main__":
    install_coreml_patches()
    model = build_dinov2_with_fixed_pos_embed()
    out = "/tmp/dinov2_vits14_672.mlpackage"
    print(f"==> convert -> {out}")
    mlmodel = convert(model, out)
    print(f"==> bench 50 iter")
    stats = bench(mlmodel)
    print(f"  CoreML CPU_AND_GPU : {stats}")
