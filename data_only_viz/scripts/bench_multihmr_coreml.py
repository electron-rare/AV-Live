"""Bench Multi-HMR CoreML — compute_units sweep + section split.

Bench Multi-HMR `.mlpackage` inference latency on M5 (or any Apple
Silicon). Decomposes the per-frame cost into copy_in / predict /
copy_out so we can see where time goes, then sweeps compute_units
(CPU_AND_GPU vs ALL vs CPU_AND_NE vs CPU_ONLY) and tests the
"reused MLMultiArray buffer" optimization.

Usage:
    uv run --project data_only_viz \
        python -m data_only_viz.scripts.bench_multihmr_coreml

The result reproduces the 2026-05-14 finding: predict() is ~99% of
latency, copy_in is <2 ms, copy_out is <1 ms. None of the I/O
micro-optims (reused buffer, vImage preprocess, async copy) can
help meaningfully — only changing the model itself does (INT8 quant
via `scripts/quantize_multihmr_int8.py`, lower resolution, or a
smaller architecture).

Pause the live worker before running for clean numbers:
    pgrep -f 'data_only_viz.main.*multi-hmr' | xargs kill -STOP
    # ...run bench...
    pgrep -f 'data_only_viz.main.*multi-hmr' | xargs kill -CONT
"""
from __future__ import annotations

import ctypes
import sys
import time
from pathlib import Path

import numpy as np
from Foundation import NSURL

from data_only_viz.multihmr_coreml import (
    DEFAULT_MLPACKAGE,
    _load_frameworks,
    _mlarray_to_np,
    _np_to_mlarray,
)

H = W = 672
NITER = 30
NWARM = 5


def _make_inputs():
    img = np.random.rand(1, 3, H, W).astype(np.float32)
    focal = float(H)
    K = np.array(
        [[[focal, 0, H / 2], [0, focal, H / 2], [0, 0, 1.0]]],
        dtype=np.float32,
    )
    return img, K


def _load_model(compute_units: int, mlpackage: Path):
    ns = _load_frameworks()
    MLModel = ns["MLModel"]
    MLModelConfiguration = ns["MLModelConfiguration"]
    cfg = MLModelConfiguration.alloc().init()
    cfg.setComputeUnits_(compute_units)
    url = NSURL.fileURLWithPath_(str(mlpackage))
    compiled = MLModel.compileModelAtURL_error_(url, None)
    if compiled is None:
        raise RuntimeError(f"compile failed cu={compute_units}")
    model = MLModel.modelWithContentsOfURL_configuration_error_(
        compiled, cfg, None)
    if model is None:
        raise RuntimeError(f"load failed cu={compute_units}")
    return model, ns


def _stats(ts):
    ts = sorted(ts)
    return (ts[len(ts) // 2],
            ts[len(ts) // 10],
            ts[(len(ts) * 9) // 10])


def bench_basic(label: str, compute_units: int, mlpackage: Path):
    try:
        model, ns = _load_model(compute_units, mlpackage)
    except Exception as e:  # noqa: BLE001
        print(f"[{label}] LOAD FAILED: {e}")
        return None
    MLDictionaryFeatureProvider = ns["MLDictionaryFeatureProvider"]
    MLFeatureValue = ns["MLFeatureValue"]
    img, K = _make_inputs()
    for _ in range(NWARM):
        img_ml = _np_to_mlarray(img); k_ml = _np_to_mlarray(K)
        feats = {"image": MLFeatureValue.featureValueWithMultiArray_(img_ml),
                 "cam_K": MLFeatureValue.featureValueWithMultiArray_(k_ml)}
        prov = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        out = model.predictionFromFeatures_error_(prov, None)
        if out is None:
            print(f"[{label}] predict returned None")
            return None
    ts = []
    for _ in range(NITER):
        t0 = time.perf_counter()
        img_ml = _np_to_mlarray(img); k_ml = _np_to_mlarray(K)
        feats = {"image": MLFeatureValue.featureValueWithMultiArray_(img_ml),
                 "cam_K": MLFeatureValue.featureValueWithMultiArray_(k_ml)}
        prov = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        out = model.predictionFromFeatures_error_(prov, None)
        for name in out.featureNames():
            fv = out.featureValueForName_(name)
            ml = fv.multiArrayValue()
            if ml is None:
                continue
            _ = _mlarray_to_np(ml)
        ts.append((time.perf_counter() - t0) * 1e3)
    med, p10, p90 = _stats(ts)
    print(f"[{label:34s}] med={med:6.1f}ms p10={p10:6.1f} "
          f"p90={p90:6.1f} fps={1000/med:5.1f}")
    return med


def bench_reused_input(label: str, compute_units: int, mlpackage: Path):
    try:
        model, ns = _load_model(compute_units, mlpackage)
    except Exception as e:  # noqa: BLE001
        print(f"[{label}] LOAD FAILED: {e}")
        return None
    MLDictionaryFeatureProvider = ns["MLDictionaryFeatureProvider"]
    MLFeatureValue = ns["MLFeatureValue"]
    img, K = _make_inputs()
    img_ml = _np_to_mlarray(img); k_ml = _np_to_mlarray(K)
    ptr_img = img_ml.dataPointer()
    addr_img = int(ptr_img) if isinstance(ptr_img, int) else \
        ctypes.cast(ptr_img, ctypes.c_void_p).value
    ptr_k = k_ml.dataPointer()
    addr_k = int(ptr_k) if isinstance(ptr_k, int) else \
        ctypes.cast(ptr_k, ctypes.c_void_p).value
    img_bytes = img.nbytes
    k_bytes = K.nbytes
    feats = {"image": MLFeatureValue.featureValueWithMultiArray_(img_ml),
             "cam_K": MLFeatureValue.featureValueWithMultiArray_(k_ml)}
    for _ in range(NWARM):
        ctypes.memmove(addr_img, img.ctypes.data, img_bytes)
        ctypes.memmove(addr_k, K.ctypes.data, k_bytes)
        prov = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        _ = model.predictionFromFeatures_error_(prov, None)
    ts = []
    for _ in range(NITER):
        t0 = time.perf_counter()
        ctypes.memmove(addr_img, img.ctypes.data, img_bytes)
        ctypes.memmove(addr_k, K.ctypes.data, k_bytes)
        prov = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        out = model.predictionFromFeatures_error_(prov, None)
        for name in out.featureNames():
            fv = out.featureValueForName_(name)
            ml = fv.multiArrayValue()
            if ml is None:
                continue
            _ = _mlarray_to_np(ml)
        ts.append((time.perf_counter() - t0) * 1e3)
    med, p10, p90 = _stats(ts)
    print(f"[{label:34s}] med={med:6.1f}ms p10={p10:6.1f} "
          f"p90={p90:6.1f} fps={1000/med:5.1f}")
    return med


def bench_section_split(compute_units: int, mlpackage: Path):
    model, ns = _load_model(compute_units, mlpackage)
    MLDictionaryFeatureProvider = ns["MLDictionaryFeatureProvider"]
    MLFeatureValue = ns["MLFeatureValue"]
    img, K = _make_inputs()
    for _ in range(NWARM):
        img_ml = _np_to_mlarray(img); k_ml = _np_to_mlarray(K)
        feats = {"image": MLFeatureValue.featureValueWithMultiArray_(img_ml),
                 "cam_K": MLFeatureValue.featureValueWithMultiArray_(k_ml)}
        prov = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        _ = model.predictionFromFeatures_error_(prov, None)
    t_in, t_pred, t_out = [], [], []
    for _ in range(NITER):
        t0 = time.perf_counter()
        img_ml = _np_to_mlarray(img); k_ml = _np_to_mlarray(K)
        feats = {"image": MLFeatureValue.featureValueWithMultiArray_(img_ml),
                 "cam_K": MLFeatureValue.featureValueWithMultiArray_(k_ml)}
        prov = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        t1 = time.perf_counter()
        out = model.predictionFromFeatures_error_(prov, None)
        t2 = time.perf_counter()
        for name in out.featureNames():
            fv = out.featureValueForName_(name)
            ml = fv.multiArrayValue()
            if ml is None:
                continue
            _ = _mlarray_to_np(ml)
        t3 = time.perf_counter()
        t_in.append((t1 - t0) * 1e3)
        t_pred.append((t2 - t1) * 1e3)
        t_out.append((t3 - t2) * 1e3)
    mi = lambda a: sorted(a)[len(a) // 2]
    print("[section-split CPU_AND_GPU]")
    print(f"   copy_in  : {mi(t_in):6.2f} ms")
    print(f"   predict  : {mi(t_pred):6.2f} ms")
    print(f"   copy_out : {mi(t_out):6.2f} ms")
    print(f"   total    : {mi(t_in)+mi(t_pred)+mi(t_out):6.2f} ms")


def main(argv: list[str]) -> int:
    mlpackage = DEFAULT_MLPACKAGE
    if len(argv) > 1:
        mlpackage = Path(argv[1])
    if not mlpackage.exists():
        print(f"mlpackage missing: {mlpackage}", file=sys.stderr)
        return 1
    print(f"bench target: {mlpackage}")
    print("=" * 70)
    print("Section split (alloc/predict/copy)")
    print("=" * 70)
    bench_section_split(1, mlpackage)
    print()
    print("=" * 70)
    print("Compute-units sweep (30 iter median)")
    print("=" * 70)
    bench_basic("A. CPU_AND_GPU (baseline)", 1, mlpackage)
    bench_basic("B. ALL (ANE+GPU+CPU)", 2, mlpackage)
    bench_basic("C. CPU_AND_NE (ANE-only)", 3, mlpackage)
    bench_basic("D. CPU_ONLY", 0, mlpackage)
    bench_reused_input("E. CPU_AND_GPU + reused buffer", 1, mlpackage)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
