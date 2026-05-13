"""Extract action-head v3 jsonl rows from a recorded MP4 using MediaPipe
Holistic. Populates real hands_kp (42, 3) and mouth_open (face lips
distance), unlike extract_j3d_offline.py (SMPL-X path) which writes zeros
for hands_kp.

Output jsonl row format (matches dataset.py load_frames_jsonl) :

    {
      "ts":         float seconds,
      "session":    str,
      "pid":        int (always 0 — Holistic is single-person),
      "j3d":        [[32, 3]] floats (body22 + 10 fingertips),
      "expression": [10] zeros (MediaPipe has no SMPL-X PCA),
      "mouth_open": float (lips inner distance),
      "hands_kp":   [[42, 3]] floats (21 L + 21 R, zero-padded if absent),
    }

Usage :

    uv run python -m data_only_viz.scripts.extract_mediapipe_offline \
        --session sess03 \
        --video ~/.cache/av-live-action/raw/sess03.mp4 \
        --out   ~/.cache/av-live-action/raw/sess03_mp.jsonl
"""
from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

import cv2
import numpy as np

from data_only_viz.action_head import (
    EXPR_DIM,
    HANDS_KP_DIMS,
    HANDS_KP_PER_HAND,
    HANDS_KP_TOTAL,
    J3D_BODY,
    J3D_FINGERS,
    J3D_FINGERS_PER_HAND,
    J3D_JOINTS,
)
from data_only_viz.action_head_pub import (
    MEDIAPIPE_HAND_FINGERTIPS,
    MEDIAPIPE_LIP_LOWER_INNER,
    MEDIAPIPE_LIP_UPPER_INNER,
    MEDIAPIPE_TO_22,
)

LOG = logging.getLogger("extract_mediapipe_offline")
DEFAULT_OUT_DIR = Path("~/.cache/av-live-action/raw").expanduser()


def _build_landmarker():
    """Build a MediaPipe HolisticLandmarker in VIDEO running mode."""
    from mediapipe.tasks.python import vision
    from mediapipe.tasks.python.core.base_options import BaseOptions
    from data_only_viz.holistic import _ensure_model
    model_path = _ensure_model()
    opts = vision.HolisticLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(model_path)),
        running_mode=vision.RunningMode.VIDEO,
        min_pose_detection_confidence=0.3,
        min_pose_landmarks_confidence=0.3,
        min_face_detection_confidence=0.3,
        min_face_landmarks_confidence=0.3,
        min_hand_landmarks_confidence=0.3,
    )
    return vision.HolisticLandmarker.create_from_options(opts)


def _lmk_list_to_array(lmks) -> np.ndarray | None:
    """Convert MediaPipe NormalizedLandmark / Landmark list to (N, 3) array."""
    if lmks is None:
        return None
    try:
        return np.asarray(
            [(lm.x, lm.y, getattr(lm, "z", 0.0)) for lm in lmks],
            dtype=np.float32,
        )
    except (AttributeError, TypeError):
        return None


def _build_j3d32(body3d_arr: np.ndarray | None,
                 hands_kp42: np.ndarray) -> np.ndarray | None:
    """Map MediaPipe body3d (33, 3) + hands_kp (42, 3) -> j3d (32, 3).

    body22 indices via MEDIAPIPE_TO_22, fingertips from hands_kp idx
    MEDIAPIPE_HAND_FINGERTIPS (4, 8, 12, 16, 20) for each side.
    """
    if body3d_arr is None or body3d_arr.shape[0] < 33:
        return None
    body22 = body3d_arr[list(MEDIAPIPE_TO_22)].astype(np.float32)
    tips = np.zeros((J3D_FINGERS, 3), dtype=np.float32)
    for side_idx in (0, 1):
        base = side_idx * HANDS_KP_PER_HAND
        for k, mp_tip in enumerate(MEDIAPIPE_HAND_FINGERTIPS):
            if base + mp_tip < hands_kp42.shape[0]:
                tips[side_idx * J3D_FINGERS_PER_HAND + k] = hands_kp42[base + mp_tip]
    return np.concatenate([body22, tips], axis=0)


def _mouth_open(face_arr: np.ndarray | None) -> float:
    if face_arr is None or face_arr.shape[0] <= MEDIAPIPE_LIP_LOWER_INNER:
        return 0.0
    upper = face_arr[MEDIAPIPE_LIP_UPPER_INNER]
    lower = face_arr[MEDIAPIPE_LIP_LOWER_INNER]
    return float(np.linalg.norm(upper - lower))


def _hands_kp42(left_arr: np.ndarray | None,
                right_arr: np.ndarray | None) -> np.ndarray:
    out = np.zeros((HANDS_KP_TOTAL, HANDS_KP_DIMS), dtype=np.float32)
    if left_arr is not None and left_arr.shape[0] >= HANDS_KP_PER_HAND:
        out[:HANDS_KP_PER_HAND] = left_arr[:HANDS_KP_PER_HAND]
    if right_arr is not None and right_arr.shape[0] >= HANDS_KP_PER_HAND:
        out[HANDS_KP_PER_HAND:] = right_arr[:HANDS_KP_PER_HAND]
    return out


def extract(session: str, video: Path, out: Path) -> int:
    """Run MediaPipe Holistic on every frame of video, write jsonl rows.

    Returns the number of frames where at least body3d was detected
    (rows written). Frames with no person are silently skipped.
    """
    import mediapipe as mp
    out.parent.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        raise RuntimeError(f"cannot open {video}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    landmarker = _build_landmarker()
    n_frames = 0
    n_rows = 0
    expr_zeros_list = np.zeros(EXPR_DIM, dtype=np.float32).tolist()
    try:
        with out.open("w") as f:
            while True:
                ok, frame = cap.read()
                if not ok:
                    break
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
                ts_ms = int(n_frames * 1000 / fps)
                try:
                    res = landmarker.detect_for_video(mp_img, ts_ms)
                except Exception:
                    LOG.exception("detect failed at frame=%d", n_frames)
                    n_frames += 1
                    continue
                body3d = _lmk_list_to_array(
                    getattr(res, "pose_world_landmarks", None)
                )
                face_arr = _lmk_list_to_array(
                    getattr(res, "face_landmarks", None)
                )
                left_arr = _lmk_list_to_array(
                    getattr(res, "left_hand_landmarks", None)
                )
                right_arr = _lmk_list_to_array(
                    getattr(res, "right_hand_landmarks", None)
                )
                hands_kp42 = _hands_kp42(left_arr, right_arr)
                j3d32 = _build_j3d32(body3d, hands_kp42)
                if j3d32 is None:
                    n_frames += 1
                    continue
                ts = n_frames / fps
                mouth = _mouth_open(face_arr)
                f.write(json.dumps({
                    "ts": ts,
                    "session": session,
                    "pid": 0,
                    "j3d": j3d32.tolist(),
                    "expression": expr_zeros_list,
                    "mouth_open": mouth,
                    "hands_kp": hands_kp42.tolist(),
                }) + "\n")
                n_rows += 1
                n_frames += 1
                if n_frames % 100 == 0:
                    LOG.info("frame=%d rows=%d", n_frames, n_rows)
    finally:
        cap.release()
        landmarker.close()
    LOG.info("done : %d frames, %d rows -> %s", n_frames, n_rows, out)
    return n_rows


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--session", required=True)
    p.add_argument("--video", required=True, type=Path)
    p.add_argument("--out", type=Path)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(name)s] %(message)s")
    DEFAULT_OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = args.out or (DEFAULT_OUT_DIR / f"{args.session}_mp.jsonl")
    extract(args.session, args.video, out)


if __name__ == "__main__":
    _cli()
