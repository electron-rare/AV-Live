"""Record webcam frames + timestamps for action-head training.

Usage:
    uv run python -m data_only_viz.scripts.capture_actions \
        --session sess03 --duration 600
"""
from __future__ import annotations

import argparse
import logging
import time
from pathlib import Path

import cv2

LOG = logging.getLogger("capture_actions")
RAW_DIR = Path("~/.cache/av-live-action/raw").expanduser()


def capture(session: str, duration_s: float,
            cam_index: int = 0, fps: int = 30,
            size: int = 672) -> Path:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    out = RAW_DIR / f"{session}.mp4"
    ts_out = RAW_DIR / f"{session}.ts.txt"
    cap = cv2.VideoCapture(cam_index)
    if not cap.isOpened():
        raise RuntimeError(f"cannot open camera {cam_index}")
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(out), fourcc, fps, (size, size))
    try:
        t_start = time.perf_counter()
        with ts_out.open("w") as ts_f:
            n = 0
            while time.perf_counter() - t_start < duration_s:
                ok, frame = cap.read()
                if not ok:
                    LOG.warning("frame read failed")
                    break
                h, w = frame.shape[:2]
                side = min(h, w)
                y0 = (h - side) // 2
                x0 = (w - side) // 2
                crop = frame[y0:y0 + side, x0:x0 + side]
                resized = cv2.resize(crop, (size, size))
                writer.write(resized)
                ts_f.write(f"{n} {time.perf_counter() - t_start:.6f}\n")
                n += 1
                cv2.imshow("capture (q=quit)", resized)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
        LOG.info("wrote %s (%d frames)", out, n)
        return out
    finally:
        cap.release()
        writer.release()
        cv2.destroyAllWindows()


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--session", required=True)
    p.add_argument("--duration", type=float, default=600.0)
    p.add_argument("--cam-index", type=int, default=0)
    p.add_argument("--fps", type=int, default=30)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(name)s] %(message)s")
    capture(args.session, args.duration,
            cam_index=args.cam_index, fps=args.fps)


if __name__ == "__main__":
    _cli()
