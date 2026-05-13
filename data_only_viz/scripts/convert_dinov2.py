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
from pathlib import Path

import numpy as np

LOG = logging.getLogger("convert_dinov2")

OUT_DIR = Path.home() / ".cache" / "av-live-multihmr"
OUT_PATH = OUT_DIR / "dinov2_vits14.mlpackage"

# ImageNet stats (DINOv2 expects these).
_IMAGENET_MEAN = (0.485, 0.456, 0.406)
_IMAGENET_STD = (0.229, 0.224, 0.225)


def _build_wrapper():
    import torch
    import torch.nn as nn

    # Load DINOv2 ViT-S/14 from local torch.hub cache (offline ok).
    backbone = torch.hub.load(
        "facebookresearch/dinov2",
        "dinov2_vits14",
        source="github",
        trust_repo=True,
    )
    backbone.eval()

    # Monkey-patch interpolate_pos_encoding so we don't hit the bicubic
    # upsample op (unsupported by coremltools). At fixed 224x224 input
    # with patch=14 the layout is exactly 16x16 = 256 patches, which
    # matches the pretrained pos_embed grid -> no interpolation needed.
    def _no_interp_pos_encoding(self, x, w, h):
        # Just return the stored pos_embed (cast to current dtype).
        return self.pos_embed.to(x.dtype)

    import types
    backbone.interpolate_pos_encoding = types.MethodType(
        _no_interp_pos_encoding, backbone)

    mean = torch.tensor(_IMAGENET_MEAN, dtype=torch.float32).view(1, 3, 1, 1)
    std = torch.tensor(_IMAGENET_STD, dtype=torch.float32).view(1, 3, 1, 1)

    class DinoV2Wrapper(nn.Module):
        def __init__(self):
            super().__init__()
            self.backbone = backbone
            self.register_buffer("mean", mean)
            self.register_buffer("std", std)

        def forward(self, x: "torch.Tensor") -> "torch.Tensor":
            # x: (1, 3, 224, 224) in [0, 1]. Normalise then forward.
            x = (x - self.mean) / self.std
            cls = self.backbone(x)  # (1, 384) - CLS token by default
            # L2 normalise so cosine sim = dot product.
            cls = cls / (cls.norm(dim=-1, keepdim=True) + 1e-8)
            return cls

    wrap = DinoV2Wrapper().eval()
    return wrap


def convert(force: bool = False) -> Path:
    import torch
    import coremltools as ct

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if OUT_PATH.exists() and not force:
        LOG.info("already converted: %s", OUT_PATH)
        return OUT_PATH

    LOG.info("loading DINOv2 ViT-S/14 from torch.hub ...")
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

    # Sanity numerical check
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
    # warmup
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
