#!/usr/bin/env python3
"""Convert DINOv2 ViT-S/14 to a CoreML .mlpackage for ANE-friendly inference.

The wrapped module takes (1, 3, 224, 224) RGB float32 in [0, 1], applies
ImageNet normalization internally, runs the ViT, and returns the CLS
embedding (1, 384) L2-normalised. We trace + convert with
``coremltools.convert(... compute_units=ComputeUnit.ALL, compute_precision=FP16)``.

Run with the Python 3.12 venv that has coremltools and torch::

    /tmp/coreml312/bin/python -m data_only_viz.scripts.convert_dinov2 [--force]

Output:
    ~/.cache/av-live-multihmr/dinov2_vits14.mlpackage
"""
from __future__ import annotations

import argparse
import logging
import sys
import time
import types
from pathlib import Path

import numpy as np

LOG = logging.getLogger("convert_dinov2")

OUT_DIR = Path.home() / ".cache" / "av-live-multihmr"
OUT_PATH = OUT_DIR / "dinov2_vits14.mlpackage"

_IMAGENET_MEAN = (0.485, 0.456, 0.406)
_IMAGENET_STD = (0.229, 0.224, 0.225)


def _build_wrapper():
    import torch
    import torch.nn as nn
    import torch.nn.functional as F

    backbone = torch.hub.load(
        "facebookresearch/dinov2",
        "dinov2_vits14",
        source="github",
        trust_repo=True,
    )
    backbone.eval()

    # Pretrained pos_embed is at 37x37 (518/14). We pre-resample to
    # 16x16 (224/14) once so the traced graph never needs an upsample.
    pe = backbone.pos_embed.data  # (1, 1+37*37, 384)
    cls_pe = pe[:, :1]
    patch_pe = pe[:, 1:]
    n_old = int(round((patch_pe.shape[1]) ** 0.5))
    dim = patch_pe.shape[-1]
    patch_pe = patch_pe.reshape(1, n_old, n_old, dim).permute(0, 3, 1, 2)
    patch_pe = F.interpolate(patch_pe, size=(16, 16), mode="bilinear",
                             align_corners=False)
    patch_pe = patch_pe.permute(0, 2, 3, 1).reshape(1, 16 * 16, dim)
    new_pe = torch.cat([cls_pe, patch_pe], dim=1).contiguous()
    backbone.pos_embed = nn.Parameter(new_pe, requires_grad=False)

    mean = torch.tensor(_IMAGENET_MEAN, dtype=torch.float32).view(1, 3, 1, 1)
    std = torch.tensor(_IMAGENET_STD, dtype=torch.float32).view(1, 3, 1, 1)

    class DinoV2Wrapper(nn.Module):
        def __init__(self):
            super().__init__()
            self.backbone = backbone
            self.register_buffer("mean", mean)
            self.register_buffer("std", std)

        def forward(self, x):
            x = (x - self.mean) / self.std
            bb = self.backbone
            x = bb.patch_embed(x)
            # cls_token is (1,1,384). Concat directly (B=1 fixed).
            x = torch.cat((bb.cls_token, x), dim=1)
            x = x + bb.pos_embed
            for blk in bb.blocks:
                x = blk(x)
            x = bb.norm(x)
            cls = x[:, 0]
            cls = cls / (cls.norm(dim=-1, keepdim=True) + 1e-8)
            return cls

    return DinoV2Wrapper().eval()


def _patch_coremltools_cast():
    """coremltools 9.0 _cast assumes x.val is a 0-d scalar. With recent
    torch (2.12) some aten::Int args land as 1-D length-1 arrays. Patch
    the helper to flatten before scalar-casting."""
    from coremltools.converters.mil.frontend.torch import ops as _ops
    from coremltools.converters.mil.mil import Builder as mb

    _orig = _ops._cast

    def _patched_cast(context, node, dtype, dtype_name):
        # Inputs are read inside _orig from context; we wrap the failure
        # path by checking the first input's val first.
        inputs = _ops._get_inputs(context, node, expected=1)
        x = inputs[0]
        if x.can_be_folded_to_const():
            val = x.val
            if hasattr(val, "shape") and getattr(val, "shape", ()) != ():
                # 1-D length-1 (or all-ones shape) -> extract scalar
                import numpy as _np
                arr = _np.asarray(val).reshape(-1)
                if arr.size == 1:
                    res = mb.const(val=dtype(arr[0]), name=node.name)
                    context.add(res, node.name)
                    return
        return _orig(context, node, dtype, dtype_name)

    _ops._cast = _patched_cast


def convert(force: bool = False) -> Path:
    import torch
    import coremltools as ct
    _patch_coremltools_cast()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if OUT_PATH.exists() and not force:
        LOG.info("already converted: %s", OUT_PATH)
        return OUT_PATH

    LOG.info("loading DINOv2 ViT-S/14 ...")
    wrap = _build_wrapper()
    example = torch.rand(1, 3, 224, 224, dtype=torch.float32)
    with torch.no_grad():
        ref_out = wrap(example)
    LOG.info("torch out shape=%s norm=%.4f", tuple(ref_out.shape),
             float(ref_out.norm(dim=-1).mean()))

    LOG.info("tracing ...")
    with torch.no_grad():
        traced = torch.jit.trace(wrap, example, strict=False)

    LOG.info("ct.convert (mlprogram FP16, computeUnits=ALL) ...")
    mlmodel = ct.convert(
        traced,
        source="pytorch",
        convert_to="mlprogram",
        inputs=[ct.TensorType(name="image", shape=example.shape,
                              dtype=np.float32)],
        outputs=[ct.TensorType(name="embedding", dtype=np.float32)],
        compute_precision=ct.precision.FLOAT16,
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.macOS14,
    )
    mlmodel.short_description = "DINOv2 ViT-S/14 person re-id (384-D, L2)"
    mlmodel.save(str(OUT_PATH))
    LOG.info("saved %s", OUT_PATH)

    pred = mlmodel.predict({"image": example.numpy().astype(np.float32)})
    coreml_out = list(pred.values())[0].reshape(-1)
    ref_np = ref_out.numpy().reshape(-1)
    cos = float(np.dot(coreml_out, ref_np) /
                (np.linalg.norm(coreml_out) * np.linalg.norm(ref_np) + 1e-8))
    LOG.info("CoreML vs Torch cosine on random input: %.4f", cos)
    return OUT_PATH


def bench(n_iter: int = 30) -> None:
    import coremltools as ct
    LOG.info("bench: load mlpackage ...")
    m = ct.models.MLModel(str(OUT_PATH),
                          compute_units=ct.ComputeUnit.ALL)
    crop = np.random.rand(1, 3, 224, 224).astype(np.float32)
    for _ in range(3):
        m.predict({"image": crop})
    times = []
    for _ in range(n_iter):
        t0 = time.perf_counter()
        m.predict({"image": crop})
        times.append((time.perf_counter() - t0) * 1e3)
    times.sort()
    p50 = times[len(times) // 2]
    p95 = times[int(len(times) * 0.95)]
    LOG.info("bench %d iter: p50=%.2f ms p95=%.2f ms mean=%.2f ms (~%.1f fps)",
             n_iter, p50, p95, sum(times) / len(times), 1000.0 / p50)


def main() -> int:
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(name)s %(message)s")
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--bench-only", action="store_true")
    ap.add_argument("--n-iter", type=int, default=30)
    args = ap.parse_args()

    if not args.bench_only:
        convert(force=args.force)
    bench(n_iter=args.n_iter)
    return 0


if __name__ == "__main__":
    sys.exit(main())
