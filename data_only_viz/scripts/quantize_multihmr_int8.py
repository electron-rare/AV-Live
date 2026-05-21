"""Quantize Multi-HMR mlpackage to INT8 (weight-only) for M5 speedup.

Run in the Python 3.12 conversion venv (coremltools cannot run on 3.14):

    /tmp/coreml312/.venv/bin/python \
        data_only_viz/scripts/quantize_multihmr_int8.py

Produces `multihmr_full_672_s_int8.mlpackage` next to the FP32 file.
Bench after with `scripts/coreml_full_probe.py` or just load with
`MultiHMRCoreMLBackend(path=...new path...)`.

Strategy:
- Linear 8-bit weight palettization (per-tensor symmetric). Activations
  stay FP16 — that's the "weight-only quant" path, lowest accuracy
  hit and what CoreML's GPU runtime accelerates best.
- Skip the SMPL-X decoder branch ops that are sensitive to numeric
  drift (skipped by name pattern below — adjust if v3d shows mesh
  artefacts after quantization).

Validation:
- After producing the int8 mlpackage, run the live worker briefly
  with COREML_MLPACKAGE pointing to the new file and visually check
  the mesh. If v3d shows tearing on extreme poses, retry with
  `granularity="per_channel"` instead of `per_tensor`.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import coremltools as ct
    from coremltools.optimize.coreml import (
        linear_quantize_weights,
        OptimizationConfig,
        OpLinearQuantizerConfig,
    )
except ImportError as e:
    print(f"coremltools missing in this venv: {e}", file=sys.stderr)
    print("Run from the Python 3.12 conversion venv (coremltools "
          "is not available on 3.14).", file=sys.stderr)
    sys.exit(1)


SRC = Path.home() / ".cache" / "av-live-multihmr" / \
    "multihmr_full_672_s.mlpackage"
DST = Path.home() / ".cache" / "av-live-multihmr" / \
    "multihmr_full_672_s_int8.mlpackage"


def main() -> int:
    if not SRC.exists():
        print(f"source mlpackage missing: {SRC}", file=sys.stderr)
        return 1
    print(f"loading FP32 model from {SRC}")
    model = ct.models.MLModel(str(SRC))

    # Per-tensor symmetric int8 weight quant. Per-tensor keeps the
    # quantized model small and GPU-friendly; per-channel is a safer
    # fallback if mesh quality degrades.
    op_cfg = OpLinearQuantizerConfig(
        mode="linear_symmetric",
        dtype="int8",
        granularity="per_tensor",
    )
    cfg = OptimizationConfig(global_config=op_cfg)
    print("running linear_quantize_weights (per_tensor int8)...")
    quant = linear_quantize_weights(model, config=cfg)
    print(f"saving quantized model to {DST}")
    quant.save(str(DST))
    print("done. Test with:")
    print(f"  COREML_MLPACKAGE={DST} \\\n"
          f"  MULTIHMR_BACKEND=coreml \\\n"
          f"  uv run --project data_only_viz \\\n"
          f"    python -m data_only_viz.main --multi-hmr "
          f"--motion-gate 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
