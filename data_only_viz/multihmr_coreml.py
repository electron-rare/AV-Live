"""Multi-HMR CoreML backend (ANE/GPU/CPU via Apple's CoreML framework).

Python 3.14 cannot use `coremltools.MLModel` because `libcoremlpython`
and `libmilstoragepython` native extensions are not distributed for
3.14. We load CoreML.framework directly via `objc.loadBundle()` —
same pattern as `coreml_pose.py`.

Unlike `coreml_pose.py`, this backend does NOT use Vision: Vision is
limited to image inputs and cannot feed a second MLMultiArray (cam_K).
We invoke `MLModel.predictionFromFeatures:error:` directly with a
`MLDictionaryFeatureProvider` wrapping two `MLMultiArray`s.

Public API:
    backend = MultiHMRCoreMLBackend(mlpackage_path)
    humans = backend.infer(image_chw_f32, K_33_f32, det_thresh=0.3)
    # humans is a list[dict] with the same keys as the PyTorch model
    # output. Values are CoreMLArray instances that quack like torch
    # tensors (.detach().cpu().numpy() / .item()).
"""
from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Any

import numpy as np
import objc
from Foundation import NSURL

LOG = logging.getLogger("multihmr_coreml")

DEFAULT_MLPACKAGE = (
    Path.home() / ".cache" / "av-live-multihmr"
    / "multihmr_full_672_s.mlpackage"
)

# Multi-HMR exported with apply_topk(K=4): outputs are fixed shape.
N_PERSONS_FIXED = 4
N_VERTS = 10475

# CoreML output names from the exported .mlpackage. The exported
# `multihmr_full_672_s.mlpackage` (2026-05-14 re-convert) renumbered
# the MIL vars; verified against the on-disk artifact's spec.
OUT_V3D = "var_2420"          # (4, 10475, 3)
OUT_TRANSL = "var_2423"       # (4, 1, 3)
OUT_SCORES = "var_2436"       # (4,)
OUT_BETAS = "var_2439"        # (4, 10)
OUT_EXPR = "var_2442"         # (4, 10)
# var_2445 (4, 127, 3) = j3d joints — present but unused here.

# DINOv2 backbone was trained on ImageNet-normalized RGB; the public
# `infer()` contract takes [0,1] CHW input and applies this here so
# every caller stays normalization-agnostic. Feeding raw [0,1] to the
# model collapses all detection scores to ~0.01 ("0 detections" bug).
_IMG_NORM_MEAN = np.array([0.485, 0.456, 0.406],
                          dtype=np.float32).reshape(1, 3, 1, 1)
_IMG_NORM_STD = np.array([0.229, 0.224, 0.225],
                         dtype=np.float32).reshape(1, 3, 1, 1)

# MLMultiArrayDataType raw values (from CoreML headers).
ML_DTYPE_FLOAT32 = 65568
ML_DTYPE_FLOAT16 = 65552
ML_DTYPE_DOUBLE = 65600
ML_DTYPE_INT32 = 131104


_NS: dict[str, Any] = {}
_FRAMEWORKS_LOADED = False


def _load_frameworks() -> dict[str, Any]:
    global _FRAMEWORKS_LOADED
    if _FRAMEWORKS_LOADED:
        return _NS
    objc.loadBundle("CoreML", _NS,
                    "/System/Library/Frameworks/CoreML.framework")
    _FRAMEWORKS_LOADED = True
    return _NS


class CoreMLArray:
    """Tiny tensor-like adapter so the existing worker hot path can
    treat CoreML outputs the same way it treats torch tensors.

    Supports `.detach().cpu().numpy()` and `.item()`. The wrapper is
    a no-op around a numpy array; we keep the chain so callers don't
    need any conditional branch."""

    __slots__ = ("_arr",)

    def __init__(self, arr: np.ndarray) -> None:
        self._arr = arr

    def detach(self) -> "CoreMLArray":
        return self

    def cpu(self) -> "CoreMLArray":
        return self

    def numpy(self) -> np.ndarray:
        return self._arr

    def item(self) -> float:
        return float(self._arr.reshape(-1)[0])

    @property
    def shape(self) -> tuple[int, ...]:
        return tuple(self._arr.shape)


def _np_to_mlarray(arr: np.ndarray):
    """Create a contiguous float32 MLMultiArray from a numpy array.

    We always feed FLOAT32 — even though outputs are FLOAT16, CoreML
    will auto-cast on the input side."""
    ns = _load_frameworks()
    MLMultiArray = ns["MLMultiArray"]
    arr = np.ascontiguousarray(arr, dtype=np.float32)
    shape = [int(s) for s in arr.shape]
    ml = MLMultiArray.alloc().initWithShape_dataType_error_(
        shape, ML_DTYPE_FLOAT32, None)
    if ml is None:
        raise RuntimeError("MLMultiArray alloc failed")
    # Copy bytes through dataPointer (raw void*). pyobjc exposes it as
    # a memoryview-like opaque; we use ctypes to memcpy.
    import ctypes
    ptr = ml.dataPointer()
    n_bytes = arr.nbytes
    # pyobjc returns either an objc.varlist or a Python int pointer.
    addr = int(ptr) if isinstance(ptr, int) else ctypes.cast(
        ptr, ctypes.c_void_p).value
    if addr is None:
        raise RuntimeError("MLMultiArray dataPointer null")
    ctypes.memmove(addr, arr.ctypes.data, n_bytes)
    return ml


def _mlarray_to_np(ml) -> np.ndarray:
    """Copy an MLMultiArray (FLOAT16 or FLOAT32) into a numpy float32."""
    import ctypes
    shape = tuple(int(s) for s in ml.shape())
    dtype_id = int(ml.dataType())
    count = 1
    for s in shape:
        count *= s
    ptr = ml.dataPointer()
    addr = int(ptr) if isinstance(ptr, int) else ctypes.cast(
        ptr, ctypes.c_void_p).value
    if addr is None:
        raise RuntimeError("MLMultiArray dataPointer null")
    if dtype_id == ML_DTYPE_FLOAT16:
        raw = (ctypes.c_uint16 * count).from_address(addr)
        arr = np.ctypeslib.as_array(raw).view(np.float16).astype(np.float32)
    elif dtype_id == ML_DTYPE_FLOAT32:
        raw = (ctypes.c_float * count).from_address(addr)
        arr = np.ctypeslib.as_array(raw).copy()
    elif dtype_id == ML_DTYPE_DOUBLE:
        raw = (ctypes.c_double * count).from_address(addr)
        arr = np.ctypeslib.as_array(raw).astype(np.float32)
    else:
        raise RuntimeError(f"unsupported MLMultiArray dtype {dtype_id}")
    return arr.reshape(shape)


class MultiHMRCoreMLBackend:
    """CoreML inference wrapper for Multi-HMR (full_672_s)."""

    def __init__(self, mlpackage_path: Path | None = None) -> None:
        self.path = Path(mlpackage_path) if mlpackage_path else DEFAULT_MLPACKAGE
        if not self.path.exists():
            raise FileNotFoundError(f"mlpackage missing: {self.path}")
        ns = _load_frameworks()
        MLModel = ns["MLModel"]
        MLModelConfiguration = ns["MLModelConfiguration"]
        cfg = MLModelConfiguration.alloc().init()
        # MLComputeUnits: 0=CPUOnly, 1=CPUAndGPU, 2=All (ANE+GPU+CPU),
        # 3=CPUAndNeuralEngine. Bench M5 2026-05-14 (under live-worker
        # contention, 30 iter median, full Multi-HMR predict+copy):
        #   CPU_AND_GPU = 252 ms  (baseline)
        #   ALL         = 246 ms  (within noise, ANE doesn't help)
        #   CPU_AND_NE  = 1301 ms (ANE solo catastrophic)
        #   CPU_ONLY    = 1152 ms
        # Standalone (no contention) FP32 = 139 ms = 7.2 fps. Default
        # stays CPU+GPU. Override with COREML_COMPUTE_UNITS env var
        # (`all`, `cpu_and_gpu`, `cpu_and_ne`, `cpu_only`) for A/B testing.
        cu_env = os.environ.get("COREML_COMPUTE_UNITS", "").strip().lower()
        cu_map = {"cpu_only": 0, "cpu_and_gpu": 1, "all": 2,
                  "cpu_and_ne": 3}
        cu = cu_map.get(cu_env, 1)
        try:
            cfg.setComputeUnits_(cu)
        except Exception:  # noqa: BLE001
            pass
        url = NSURL.fileURLWithPath_(str(self.path))
        # .mlpackage must be compiled to .mlmodelc before MLModel can
        # load it. compileModelAtURL_error_ returns an NSURL to a
        # temp .mlmodelc bundle.
        compiled_url = MLModel.compileModelAtURL_error_(url, None)
        if compiled_url is None:
            raise RuntimeError(f"compileModelAtURL failed for {self.path}")
        model = MLModel.modelWithContentsOfURL_configuration_error_(
            compiled_url, cfg, None)
        if model is None:
            raise RuntimeError(f"MLModel load failed for {compiled_url}")
        self._model = model
        self._ns = ns
        cu_name = {0: "CPU_ONLY", 1: "CPU+GPU", 2: "ALL", 3: "CPU+NE"}.get(
            cu, str(cu))
        LOG.info("Multi-HMR CoreML model loaded (%s, computeUnits=%s)",
                 self.path.name, cu_name)

    @staticmethod
    def is_available(mlpackage_path: Path | None = None) -> bool:
        p = Path(mlpackage_path) if mlpackage_path else DEFAULT_MLPACKAGE
        if not p.exists():
            return False
        try:
            _load_frameworks()
            return True
        except Exception:  # noqa: BLE001
            return False

    def _predict(self, image_4d: np.ndarray, K_33: np.ndarray) -> dict:
        ns = self._ns
        MLDictionaryFeatureProvider = ns["MLDictionaryFeatureProvider"]
        MLFeatureValue = ns["MLFeatureValue"]
        img_ml = _np_to_mlarray(image_4d)
        k_ml = _np_to_mlarray(K_33)
        feats = {
            "image": MLFeatureValue.featureValueWithMultiArray_(img_ml),
            "cam_K": MLFeatureValue.featureValueWithMultiArray_(k_ml),
        }
        provider = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        if provider is None:
            raise RuntimeError("MLDictionaryFeatureProvider alloc failed")
        out = self._model.predictionFromFeatures_error_(provider, None)
        if out is None:
            raise RuntimeError("MLModel predict failed")
        names = [str(n) for n in out.featureNames()]
        result = {}
        for n in names:
            fv = out.featureValueForName_(n)
            ml = fv.multiArrayValue()
            if ml is None:
                continue
            result[n] = _mlarray_to_np(ml)
        return result

    def infer(
        self,
        image_chw_float32: np.ndarray,
        K_33: np.ndarray,
        det_thresh: float = 0.3,
    ) -> list[dict]:
        """Run a forward pass and return list of humans dicts.

        Args:
            image_chw_float32: (3, 672, 672) or (1, 3, 672, 672), RGB in
                [0,1]. ImageNet normalization is applied internally.
            K_33: (3, 3) or (1, 3, 3) camera intrinsics.
            det_thresh: scores threshold; CoreML forwards K=4 always.

        Returns:
            list[dict] with keys v3d, transl_pelvis, scores, shape,
            expression. Values are CoreMLArray wrappers.
        """
        img = np.asarray(image_chw_float32, dtype=np.float32)
        if img.ndim == 3:
            img = img[np.newaxis, ...]
        if img.shape != (1, 3, 672, 672):
            raise ValueError(f"image shape {img.shape}, expected (1,3,672,672)")
        K = np.asarray(K_33, dtype=np.float32)
        if K.ndim == 2:
            K = K[np.newaxis, ...]
        if K.shape != (1, 3, 3):
            raise ValueError(f"K shape {K.shape}, expected (1,3,3)")

        img = (img - _IMG_NORM_MEAN) / _IMG_NORM_STD
        raw = self._predict(img, K)
        v3d = raw.get(OUT_V3D)
        transl = raw.get(OUT_TRANSL)
        scores = raw.get(OUT_SCORES)
        betas = raw.get(OUT_BETAS)
        expr = raw.get(OUT_EXPR)
        if any(x is None for x in (v3d, transl, scores, betas, expr)):
            raise RuntimeError(
                "missing outputs; got keys=" + ",".join(raw.keys()))

        humans: list[dict] = []
        for k in range(N_PERSONS_FIXED):
            sc = float(scores[k])
            if sc < det_thresh:
                continue
            humans.append({
                "v3d": CoreMLArray(v3d[k]),                # (10475, 3)
                "transl_pelvis": CoreMLArray(transl[k]),   # (1, 3)
                "scores": CoreMLArray(np.array([sc], dtype=np.float32)),
                "shape": CoreMLArray(betas[k]),            # (10,)
                "expression": CoreMLArray(expr[k]),        # (10,)
            })
        return humans
