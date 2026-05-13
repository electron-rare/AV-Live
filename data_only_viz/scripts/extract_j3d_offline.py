<<<<<<< HEAD
<<<<<<< HEAD
"""Extract j3d (32 SMPL-X joint anchors) from a recorded MP4 using the
=======
"""Extract j3d (22 SMPL-X joint anchors) from a recorded MP4 using the
>>>>>>> 2a732fa (fix(data-only-viz): action-head review fixes)
=======
"""Extract j3d (32 SMPL-X joint anchors) from a recorded MP4 using the
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
Multi-HMR CoreML backend, write per-frame per-person jsonl rows.

Usage:
    uv run python -m data_only_viz.scripts.extract_j3d_offline \
        --session sess03 \
        --video ~/.cache/av-live-action/raw/sess03.mp4 \
        --out   ~/.cache/av-live-action/raw/sess03.jsonl
"""
from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

import cv2
import numpy as np

<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
from data_only_viz.action_head import EXPR_DIM, HANDS_KP_DIMS, HANDS_KP_TOTAL
=======
from data_only_viz.action_head import EXPR_DIM
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
from data_only_viz.action_head import EXPR_DIM, HANDS_KP_DIMS, HANDS_KP_TOTAL
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
from data_only_viz.action_head_pub import (
    SMPLX_JOINT_ANCHOR_VERTS,
    SMPLX_UPPER_LIP_VERT,
    SMPLX_LOWER_LIP_VERT,
)
<<<<<<< HEAD
=======
from data_only_viz.action_head_pub import SMPLX_JOINT_ANCHOR_VERTS
>>>>>>> 2a732fa (fix(data-only-viz): action-head review fixes)
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
from data_only_viz.multihmr_coreml import MultiHMRCoreMLBackend

LOG = logging.getLogger("extract_j3d_offline")
IMG_SIZE = 672
DEFAULT_OUT_DIR = Path("~/.cache/av-live-action/raw").expanduser()


def _default_K(size: int = IMG_SIZE) -> np.ndarray:
    """Synthetic camera intrinsics, focal ~ image size, principal point centred."""
    f = float(size)
    cx = cy = f * 0.5
    return np.array(
        [[f, 0.0, cx], [0.0, f, cy], [0.0, 0.0, 1.0]],
        dtype=np.float32,
    )


def _frame_to_chw(frame_bgr: np.ndarray, size: int = IMG_SIZE) -> np.ndarray:
    """BGR uint8 (H, W, 3) -> float32 CHW (3, size, size) in [0, 1]."""
    h, w = frame_bgr.shape[:2]
    side = min(h, w)
    y0 = (h - side) // 2
    x0 = (w - side) // 2
    crop = frame_bgr[y0:y0 + side, x0:x0 + side]
    resized = cv2.resize(crop, (size, size))
    rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    return rgb.transpose(2, 0, 1)  # CHW


<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
def _person_to_j3d32(
    person: dict,
    anchors: tuple[int, ...],
) -> tuple[np.ndarray, np.ndarray, float] | None:
    """Return (j3d32, expression, mouth_open) or None if v3d absent/too small."""
<<<<<<< HEAD
=======
def _person_to_j3d22(person: dict, anchors: tuple[int, ...]) -> np.ndarray | None:
>>>>>>> 2a732fa (fix(data-only-viz): action-head review fixes)
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
    v3d = person.get("v3d")
    if v3d is None:
        return None
    # CoreMLArray wraps numpy but lacks __array__; unwrap before asarray.
    if hasattr(v3d, "numpy") and not isinstance(v3d, np.ndarray):
        v3d = v3d.numpy()
    v3d_np = np.asarray(v3d, dtype=np.float32)
    if v3d_np.shape[0] < max(anchors) + 1:
        return None
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
    j3d32 = v3d_np[list(anchors)].astype(np.float32)
    # expression
    expr = person.get("expression")
    if expr is not None:
        if hasattr(expr, "numpy") and not isinstance(expr, np.ndarray):
            expr = expr.numpy()
        expr_np = np.asarray(expr, dtype=np.float32).flatten()
    else:
        expr_np = np.zeros(EXPR_DIM, dtype=np.float32)
    # mouth_open
    if v3d_np.shape[0] > max(SMPLX_UPPER_LIP_VERT, SMPLX_LOWER_LIP_VERT):
        mouth = float(np.linalg.norm(
            v3d_np[SMPLX_UPPER_LIP_VERT] - v3d_np[SMPLX_LOWER_LIP_VERT]
        ))
    else:
        mouth = 0.0
    return j3d32, expr_np, mouth
<<<<<<< HEAD
=======
    return v3d_np[list(anchors)].astype(np.float32)
>>>>>>> 2a732fa (fix(data-only-viz): action-head review fixes)
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)


def extract(session: str, video: Path, out: Path,
            det_thresh: float = 0.3,
            mlpackage_path: Path | None = None,
            anchors: tuple[int, ...] = SMPLX_JOINT_ANCHOR_VERTS) -> int:
    """Returns the number of (frame, person) rows written."""
    out.parent.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        raise RuntimeError(f"cannot open {video}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    backend = MultiHMRCoreMLBackend(mlpackage_path) if mlpackage_path \
        else MultiHMRCoreMLBackend()
    K = _default_K(IMG_SIZE)
    n_frames = 0
    n_rows = 0
    with out.open("w") as f:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            chw = _frame_to_chw(frame)
            try:
                persons = backend.infer(chw, K, det_thresh=det_thresh)
            except Exception:
                LOG.exception("infer failed at frame=%d", n_frames)
                n_frames += 1
                continue
            ts = n_frames / fps
            for i, person in enumerate(persons):
<<<<<<< HEAD
<<<<<<< HEAD
                result = _person_to_j3d32(person, anchors)
                if result is None:
                    continue
                j3d32, expr_np, mouth = result
=======
                j3d = _person_to_j3d22(person, anchors)
                if j3d is None:
                    continue
>>>>>>> 2a732fa (fix(data-only-viz): action-head review fixes)
=======
                result = _person_to_j3d32(person, anchors)
                if result is None:
                    continue
                j3d32, expr_np, mouth = result
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
                f.write(json.dumps({
                    "ts": ts,
                    "session": session,
                    "pid": int(person.get("pid", i)),
<<<<<<< HEAD
<<<<<<< HEAD
                    "j3d": j3d32.tolist(),
                    "expression": expr_np.tolist(),
                    "mouth_open": mouth,
                    "hands_kp": np.zeros(
                        (HANDS_KP_TOTAL, HANDS_KP_DIMS), dtype=np.float32
                    ).tolist(),
<<<<<<< HEAD
=======
                    "j3d": j3d.tolist(),
>>>>>>> 2a732fa (fix(data-only-viz): action-head review fixes)
=======
                    "j3d": j3d32.tolist(),
                    "expression": expr_np.tolist(),
                    "mouth_open": mouth,
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
                }) + "\n")
                n_rows += 1
            n_frames += 1
            if n_frames % 100 == 0:
                LOG.info("frame=%d rows=%d", n_frames, n_rows)
    cap.release()
    LOG.info("done: %d frames, %d rows -> %s", n_frames, n_rows, out)
    return n_rows


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--session", required=True)
    p.add_argument("--video", required=True, type=Path)
    p.add_argument("--out", type=Path)
    p.add_argument("--det-thresh", type=float, default=0.3)
    p.add_argument("--mlpackage", type=Path, default=None)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(name)s] %(message)s")
    DEFAULT_OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = args.out or (DEFAULT_OUT_DIR / f"{args.session}.jsonl")
    extract(args.session, args.video, out,
            det_thresh=args.det_thresh, mlpackage_path=args.mlpackage)


if __name__ == "__main__":
    _cli()
