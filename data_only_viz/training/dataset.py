"""Dataset IO + sliding-window extraction + by-session split."""
from __future__ import annotations

import json
import random
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Iterator

import numpy as np


@dataclass(frozen=True)
class RawFrame:
    ts: float
    session: str
    pid: int
<<<<<<< HEAD
    j3d: np.ndarray          # (32, 3) float32 (v3: body22 + 10 fingertips)
    expression: np.ndarray | None = None  # (EXPR_DIM,) or None
    mouth_open: float = 0.0
    hands_kp: np.ndarray | None = None  # (42, 3) or None
=======
    j3d: np.ndarray          # (32, 3) float32 (v2: body22 + 10 fingertips)
    expression: np.ndarray | None = None  # (EXPR_DIM,) or None
    mouth_open: float = 0.0
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)


@dataclass
class WindowRow:
    j3d_stack: np.ndarray          # (window_len, 32, 3) float32
    session: str
    pid_local: int
    first_ts: float
    expr_stack: np.ndarray | None = None   # (window_len, 10) or None
    mouth_open_stack: np.ndarray | None = None  # (window_len,) or None
<<<<<<< HEAD
    hands_kp_stack: np.ndarray | None = None  # (window_len, 42, 3) or None
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)


@dataclass
class DatasetRow:
    window_id: str
    label: str
    j3d_stack: np.ndarray          # (window_len, 32, 3) float32
    session: str
    pid_local: int
    auto_label_confidence: float
    manually_validated: bool
    expr_stack: np.ndarray | None = None   # (window_len, 10) or None
    mouth_open_stack: np.ndarray | None = None  # (window_len,) or None
<<<<<<< HEAD
    hands_kp_stack: np.ndarray | None = None  # (window_len, 42, 3) or None
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)


def load_frames_jsonl(path: Path) -> list[RawFrame]:
    rows: list[RawFrame] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            expr_raw = d.get("expression")
            expr = np.asarray(expr_raw, dtype=np.float32) if expr_raw is not None else None
<<<<<<< HEAD
            hands_raw = d.get("hands_kp")
            hands_kp = np.asarray(hands_raw, dtype=np.float32) if hands_raw is not None else None
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
            rows.append(RawFrame(
                ts=float(d["ts"]),
                session=str(d["session"]),
                pid=int(d["pid"]),
                j3d=np.asarray(d["j3d"], dtype=np.float32),
                expression=expr,
                mouth_open=float(d.get("mouth_open", 0.0)),
<<<<<<< HEAD
                hands_kp=hands_kp,
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
            ))
    return rows


def sliding_windows(frames: list[RawFrame],
                    window_len: int = 16,
                    stride: int = 4) -> Iterator[WindowRow]:
    """Yield (session, pid)-grouped windows."""
    by_key: dict[tuple[str, int], list[RawFrame]] = {}
    for fr in frames:
        by_key.setdefault((fr.session, fr.pid), []).append(fr)
    for (sess, pid), grp in by_key.items():
        grp.sort(key=lambda r: r.ts)
        if len(grp) < window_len:
            continue
        for start in range(0, len(grp) - window_len + 1, stride):
            chunk = grp[start:start + window_len]
            stack = np.stack([c.j3d for c in chunk]).astype(np.float32)
            # Expression stack: zeros if not present
            if any(c.expression is not None for c in chunk):
                expr_dim = max(
                    (len(c.expression) for c in chunk if c.expression is not None),
                    default=10,
                )
                expr_stack = np.zeros((window_len, expr_dim), dtype=np.float32)
                for t, c in enumerate(chunk):
                    if c.expression is not None:
                        n = min(expr_dim, len(c.expression))
                        expr_stack[t, :n] = c.expression[:n]
            else:
                expr_stack = None
            mouth_stack = np.array(
                [c.mouth_open for c in chunk], dtype=np.float32
            )
<<<<<<< HEAD
            # hands_kp stack: (window_len, 42, 3) if any frame has hands_kp
            if any(c.hands_kp is not None for c in chunk):
                hands_kp_stack = np.zeros((window_len, 42, 3), dtype=np.float32)
                for t, c in enumerate(chunk):
                    if c.hands_kp is not None:
                        hk = np.asarray(c.hands_kp, dtype=np.float32)
                        if hk.shape == (42, 3):
                            hands_kp_stack[t] = hk
            else:
                hands_kp_stack = None
            yield WindowRow(j3d_stack=stack, session=sess,
                            pid_local=pid, first_ts=chunk[0].ts,
                            expr_stack=expr_stack,
                            mouth_open_stack=mouth_stack,
                            hands_kp_stack=hands_kp_stack)
=======
            yield WindowRow(j3d_stack=stack, session=sess,
                            pid_local=pid, first_ts=chunk[0].ts,
                            expr_stack=expr_stack,
                            mouth_open_stack=mouth_stack)
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)


def write_dataset_jsonl(rows: Iterable[DatasetRow], path: Path) -> None:
    with path.open("w") as f:
        for r in rows:
            d: dict = {
                "window_id": r.window_id,
                "label": r.label,
                "j3d": r.j3d_stack.astype(np.float32).tolist(),
                "session": r.session,
                "pid_local": r.pid_local,
                "auto_label_confidence": float(r.auto_label_confidence),
                "manually_validated": bool(r.manually_validated),
            }
            if r.expr_stack is not None:
                d["expr_stack"] = r.expr_stack.astype(np.float32).tolist()
            if r.mouth_open_stack is not None:
                d["mouth_open_stack"] = r.mouth_open_stack.astype(np.float32).tolist()
<<<<<<< HEAD
            if r.hands_kp_stack is not None:
                d["hands_kp_stack"] = r.hands_kp_stack.astype(np.float32).tolist()
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
            f.write(json.dumps(d) + "\n")


def load_dataset_jsonl(path: Path) -> list[DatasetRow]:
    out: list[DatasetRow] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            expr_raw = d.get("expr_stack")
            expr = np.asarray(expr_raw, dtype=np.float32) if expr_raw is not None else None
            mouth_raw = d.get("mouth_open_stack")
            mouth = np.asarray(mouth_raw, dtype=np.float32) if mouth_raw is not None else None
<<<<<<< HEAD
            hands_raw = d.get("hands_kp_stack")
            hands_kp = np.asarray(hands_raw, dtype=np.float32) if hands_raw is not None else None
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
            out.append(DatasetRow(
                window_id=d["window_id"],
                label=d["label"],
                j3d_stack=np.asarray(d["j3d"], dtype=np.float32),
                session=d["session"],
                pid_local=int(d["pid_local"]),
                auto_label_confidence=float(d["auto_label_confidence"]),
                manually_validated=bool(d["manually_validated"]),
                expr_stack=expr,
                mouth_open_stack=mouth,
<<<<<<< HEAD
                hands_kp_stack=hands_kp,
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
            ))
    return out


def split_by_session(rows: list[DatasetRow],
                     ratios: tuple[float, float, float] = (0.7, 0.15, 0.15),
                     seed: int = 0,
                     ) -> tuple[list[DatasetRow], list[DatasetRow], list[DatasetRow]]:
    sessions = sorted({r.session for r in rows})
    rng = random.Random(seed)
    rng.shuffle(sessions)
    n = len(sessions)
    n_train = max(1, int(round(n * ratios[0])))
    n_val = max(1, int(round(n * ratios[1])))
    if n_train + n_val >= n:
        n_val = max(1, n - n_train - 1)
    train_s = set(sessions[:n_train])
    val_s = set(sessions[n_train:n_train + n_val])
    test_s = set(sessions[n_train + n_val:])
    train = [r for r in rows if r.session in train_s]
    val = [r for r in rows if r.session in val_s]
    test = [r for r in rows if r.session in test_s]
    return train, val, test
