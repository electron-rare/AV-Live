"""DINOv2 ViT-S/14 person re-id backend (CoreML via pyobjc).

Loads the .mlpackage produced by ``scripts/convert_dinov2.py`` and runs
inference one crop at a time (pyobjc + MLDictionaryFeatureProvider).
Same pattern as ``multihmr_coreml.py`` so Python 3.14 works (no
coremltools dependency at runtime).

Embeddings are L2-normalised inside the CoreML graph, so cosine sim
between two outputs is a plain dot product.

Public API::

    reid = DinoReid(mlpackage_path)            # optional path
    emb = reid.embed_crops(list_of_uint8_HWC)  # -> np.ndarray (N, 384)
    DinoReid.is_available()                    # bool
"""
from __future__ import annotations

import logging
import time
from pathlib import Path
from typing import Sequence

import numpy as np

LOG = logging.getLogger("dino_reid")

DEFAULT_MLPACKAGE = (
    Path.home() / ".cache" / "av-live-multihmr" / "dinov2_vits14.mlpackage"
)

EMBED_DIM = 384
INPUT_SIZE = 224

# MLMultiArrayDataType raw values (from CoreML headers).
ML_DTYPE_FLOAT32 = 65568
ML_DTYPE_FLOAT16 = 65552
ML_DTYPE_DOUBLE = 65600


def _resize_crop(crop_uint8: np.ndarray) -> np.ndarray:
    """Resize an HxWx3 uint8 crop to (3, 224, 224) float32 in [0, 1].

    Uses ``cv2.resize`` when available, falls back to a simple stride
    sampler otherwise (avoids hard cv2 dep in test envs)."""
    if crop_uint8.ndim != 3 or crop_uint8.shape[2] != 3:
        raise ValueError(f"crop must be HxWx3 uint8, got {crop_uint8.shape}")
    if crop_uint8.shape[0] == INPUT_SIZE and crop_uint8.shape[1] == INPUT_SIZE:
        rgb = crop_uint8
    else:
        try:
            import cv2
            rgb = cv2.resize(crop_uint8, (INPUT_SIZE, INPUT_SIZE),
                             interpolation=cv2.INTER_AREA)
        except ImportError:
            h, w = crop_uint8.shape[:2]
            ys = (np.linspace(0, h - 1, INPUT_SIZE)).astype(np.int32)
            xs = (np.linspace(0, w - 1, INPUT_SIZE)).astype(np.int32)
            rgb = crop_uint8[ys][:, xs]
    return (rgb.astype(np.float32) / 255.0).transpose(2, 0, 1)


class DinoReid:
    """Forward DINOv2 ViT-S/14 over RGB crops, return L2-normalised
    embeddings (N, 384)."""

    def __init__(self, mlpackage_path: Path | str | None = None) -> None:
        self.path = Path(mlpackage_path) if mlpackage_path else DEFAULT_MLPACKAGE
        if not self.path.exists():
            raise FileNotFoundError(f"mlpackage missing: {self.path}")

        import objc
        from Foundation import NSURL

        self._objc = objc
        self._NSURL = NSURL

        ns: dict = {}
        objc.loadBundle("CoreML", ns,
                        "/System/Library/Frameworks/CoreML.framework")
        self._ns = ns

        MLModel = ns["MLModel"]
        MLModelConfiguration = ns["MLModelConfiguration"]
        cfg = MLModelConfiguration.alloc().init()
        try:
            # 2 = MLComputeUnitsAll (CPU+GPU+ANE). DINOv2 ViT-S/14
            # converts cleanly and ANE serves it well.
            cfg.setComputeUnits_(2)
        except Exception:  # noqa: BLE001
            pass

        url = NSURL.fileURLWithPath_(str(self.path))
        compiled = MLModel.compileModelAtURL_error_(url, None)
        if compiled is None:
            raise RuntimeError(f"compile failed for {self.path}")
        model = MLModel.modelWithContentsOfURL_configuration_error_(
            compiled, cfg, None)
        if model is None:
            raise RuntimeError(f"load failed for {compiled}")
        self._model = model

        # Discover the output feature name (single tensor).
        desc = model.modelDescription()
        out_names = [str(n) for n in desc.outputDescriptionsByName().keys()]
        self._out_name = out_names[0] if out_names else "embedding"
        LOG.info("dino_reid loaded (%s, out=%s)", self.path.name,
                 self._out_name)

    @classmethod
    def is_available(cls, mlpackage_path: Path | str | None = None) -> bool:
        p = Path(mlpackage_path) if mlpackage_path else DEFAULT_MLPACKAGE
        if not p.exists():
            return False
        try:
            import objc  # noqa: F401
            from Foundation import NSURL  # noqa: F401
            return True
        except Exception:  # noqa: BLE001
            return False

    # ------------------------------------------------------------------
    # MLMultiArray plumbing — mirrors multihmr_coreml._np_to_mlarray /
    # _mlarray_to_np. Float32 in, float32-or-float16 out.
    # ------------------------------------------------------------------
    def _np_to_mlarray(self, arr: np.ndarray):
        import ctypes
        MLMultiArray = self._ns["MLMultiArray"]
        arr = np.ascontiguousarray(arr, dtype=np.float32)
        shape = [int(s) for s in arr.shape]
        ml = MLMultiArray.alloc().initWithShape_dataType_error_(
            shape, ML_DTYPE_FLOAT32, None)
        if ml is None:
            raise RuntimeError("MLMultiArray alloc failed")
        ptr = ml.dataPointer()
        addr = int(ptr) if isinstance(ptr, int) else ctypes.cast(
            ptr, ctypes.c_void_p).value
        if addr is None:
            raise RuntimeError("dataPointer null")
        ctypes.memmove(addr, arr.ctypes.data, arr.nbytes)
        return ml

    def _mlarray_to_np(self, ml) -> np.ndarray:
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
            raise RuntimeError("dataPointer null")
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
            raise RuntimeError(f"unsupported dtype {dtype_id}")
        return arr.reshape(shape)

    def _predict_one(self, image_chw: np.ndarray) -> np.ndarray:
        MLDictionaryFeatureProvider = self._ns["MLDictionaryFeatureProvider"]
        MLFeatureValue = self._ns["MLFeatureValue"]
        x4 = image_chw[np.newaxis, ...] if image_chw.ndim == 3 else image_chw
        img_ml = self._np_to_mlarray(x4)
        feats = {"image": MLFeatureValue.featureValueWithMultiArray_(img_ml)}
        provider = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        if provider is None:
            raise RuntimeError("provider alloc failed")
        out = self._model.predictionFromFeatures_error_(provider, None)
        if out is None:
            raise RuntimeError("predict failed")
        fv = out.featureValueForName_(self._out_name)
        ml = fv.multiArrayValue()
        return self._mlarray_to_np(ml).reshape(-1)

    def embed_crops(
        self, crops_uint8: Sequence[np.ndarray],
    ) -> np.ndarray:
        """Embed a list of HxWx3 uint8 RGB crops -> (N, 384) float32.

        Loops one crop at a time (the CoreML model is traced for B=1).
        For typical N <= 4 this is still 10-15 ms total on M5."""
        if not crops_uint8:
            return np.zeros((0, EMBED_DIM), dtype=np.float32)
        t0 = time.perf_counter()
        out = np.zeros((len(crops_uint8), EMBED_DIM), dtype=np.float32)
        for i, c in enumerate(crops_uint8):
            chw = _resize_crop(c)
            out[i] = self._predict_one(chw)
        dt_ms = (time.perf_counter() - t0) * 1e3
        if LOG.isEnabledFor(logging.DEBUG) or dt_ms > 50.0:
            LOG.log(
                logging.DEBUG if dt_ms <= 50.0 else logging.INFO,
                "embedded %d crops in %.1f ms", len(crops_uint8), dt_ms)
        return out
