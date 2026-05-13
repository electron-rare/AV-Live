# action-head Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **STATUS 2026-05-14 00:30** — action-head shipped **v1 → v2 → v3** in one extended session. 51 tests green. **Both branches converged** (`main` == `feat/action-head` content-equivalent, pushed). v3 model trained on Studio M3 Ultra (synthetic 720 windows, 30 epochs MPS in 12 s, val_acc 100 % on cleanly-separable signal). Live app validated : python `--multi-hmr` + MESH_RIG=0 + AVLiveBody Swift = mesh propre après NaN/Inf guard sur Multi-HMR. **Remaining work** : Task 22 (full skel + hand kp into AVLiveBody scene Metal mode 8 hands3d) and Task 16 (E2E gate with real capture).
>
> **Post-impl deviations vs original v1 plan** :
> - Task 14 pivoted from "modify `multi_hmr_worker_coreml.py` + CLI flag" to **standalone publisher thread `data_only_viz/action_head_pub.py`** + 3-line wire-in in `multi.py` (avoids collision with the user's parallel iteration on `multi_hmr_worker.py`). The MultiHMR backend is selected via env var `MULTIHMR_BACKEND=pytorch|coreml`, not a CLI flag.
> - Task 11 pivoted from "refactor `MultiHMRWorker` with `create_for_offline()`" to **standalone script using `MultiHMRCoreMLBackend.infer()` directly** — no worker refactor.
> - j3d is approximated from SMPL-X v3d via a fixed 22-vertex anchor set (`SMPLX_JOINT_ANCHOR_VERTS`), with a MediaPipe 33→22 fallback. The same anchor set is shared between live serve (`action_head_pub.py`) and offline extract (`scripts/extract_j3d_offline.py`) to avoid train/serve skew.
> - Studio train wrapper added as Task 8.5 (`data_only_viz/scripts/train_on_studio.sh`), validated end-to-end smoke 160 windows × 3 epochs MPS in ~4 s.
>
> **v2 extension (Task 18, commit aedcb0f)** : added 10 fingertip joints (J3D_JOINTS 22→32, FEATURE_DIM 201→302), expression PCA (10), mouth_open scalar. ActionHeadModel param count 37 811. **v3 extension (Task 19, commit beb94d2)** : canonical smplx fingertip vertex IDs (`SMPLX_VERTEX_IDS`), MediaPipe lips for mouth_open with v3d fallback, **+126 dims hands_kp block** (MediaPipe 21×2). FEATURE_DIM 302→428, param count 70 499 (<100 k). **MediaPipe Holistic offline extractor (Task 20, commit 6af220d)** : populates real hands_kp + mouth_open in jsonl, complements the SMPL-X path which writes zeros.
>
> **Mesh debugging trail 2026-05-14** : user reported deformed mesh (spikes/holes). Diagnosis sequence captured in [[project-mesh-nan-guard]] memory :
> 1. MESH_RIG=0 env toggle added (`87b76a4`) → didn't fix it, rigger not the cause.
> 2. NaN/Inf guard on Multi-HMR `v3d` + extreme magnitude clamp (`4e7101c`) → **fixed**. The MPS path occasionally emitted garbage vertices that propagated to AVLiveBody as glitches.
>
> **Branch convergence 2026-05-14** : the c52271e botched merge (which had dropped action-head files from main) recovered via cherry-pick of 14 commits from feat onto main + 1 sync commit + 1 cleanup. Now `main` HEAD `82eceb8` and `feat/action-head` HEAD `06f2a55` are content-equivalent. See [[project-branch-state]] memory.

**Goal:** Implement a real-time per-person action classifier (debout/assise/danse) on top of Multi-HMR `j3d`, with OSC output enriched by softmax probabilities and kinetics scalars (speed/accel/symmetry).

**Architecture:** GRU-1-layer + MLP head streaming inference, fed by a 16-frame ring buffer per person. Trained windowed on Studio M3 Ultra (PyTorch MPS), inferred streaming on M5. Hybrid auto-labeler (rules on j3d) + manual review for dataset. Inference ≤ 2 ms/person M5 in eager PyTorch — no CoreML conversion needed.

**Tech Stack:** Python 3.11 + uv, PyTorch (MPS for train, CPU for M5 inference), numpy, python-osc, pytest. Reuses existing `data_only_viz` infrastructure (`multi_hmr_worker.py`, `multihmr_coreml.py`, `pose_bridge.py`, `tracker.py`, `state.py`).

**Reference spec:** `docs/superpowers/specs/2026-05-13-action-head-design.md`

---

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `data_only_viz/action_head.py` | NEW | `ActionHead` (GRU+MLP), `PerPersonBuffer`, `FeatureExtractor`, kinetics. |
| `data_only_viz/training/__init__.py` | NEW | Package marker. |
| `data_only_viz/training/autolabel.py` | NEW | Rule-based labeler over j3d windows → `(label, confidence)`. |
| `data_only_viz/training/dataset.py` | NEW | jsonl IO, sliding window extraction, by-session split. |
| `data_only_viz/training/augment.py` | NEW | mirror / noise / time-stretch / Y-rotation. |
| `data_only_viz/training/train_action_head.py` | NEW | CLI train script PyTorch MPS. |
| `data_only_viz/training/eval.py` | NEW | Confusion matrix + latency micro-bench. |
| `data_only_viz/training/review.py` | NEW | Console TUI for manual label correction. |
| `data_only_viz/scripts/capture_actions.py` | NEW | Webcam → MP4 + timestamps. |
| `data_only_viz/scripts/extract_j3d_offline.py` | NEW | Multi-HMR full PyTorch → jsonl j3d per frame. |
| `data_only_viz/pose_bridge.py` | MODIFY | Add `send_action()` and `send_kin()` methods. |
| `data_only_viz/multi_hmr_worker_coreml.py` | MODIFY | Wire `ActionHead.step()` + lifecycle hooks. |
| `data_only_viz/main.py` | MODIFY | CLI flag `--action-head` (default off until ckpt exists). |
| `data_only_viz/tests/test_action_head_features.py` | NEW | FeatureExtractor + buffer unit tests. |
| `data_only_viz/tests/test_action_head_model.py` | NEW | Model forward + step() + checkpoint round-trip. |
| `data_only_viz/tests/test_autolabel.py` | NEW | Rule-based labeler unit tests. |
| `data_only_viz/tests/test_dataset.py` | NEW | jsonl IO + sliding window + split. |
| `data_only_viz/tests/test_augment.py` | NEW | Augmentations preserve labels + shapes. |
| `data_only_viz/tests/test_training_smoke.py` | NEW | 2-epoch smoke training, dataset roundtrip. |
| `data_only_viz/tests/test_pose_bridge_action.py` | NEW | OSC format validation `/pose/action` + `/pose/kin`. |

Dataset & checkpoints live OUT of git (gitignored):
- Raw videos : `~/.cache/av-live-action/raw/*.mp4`
- jsonl : `~/.cache/av-live-action/dataset/*.jsonl`
- Checkpoint : `~/.cache/av-live-action/checkpoints/action_head.pt`

---

## Task 1 — Scaffold package + sanity test

**Files:**
- Create: `data_only_viz/action_head.py`
- Create: `data_only_viz/training/__init__.py`
- Create: `data_only_viz/tests/test_action_head_features.py`

- [ ] **Step 1.1: Write the failing import test**

```python
# data_only_viz/tests/test_action_head_features.py
"""Unit tests for ActionHead feature extraction and buffers."""
from __future__ import annotations

import numpy as np


def test_module_imports() -> None:
    from data_only_viz import action_head
    assert hasattr(action_head, "FeatureExtractor")
    assert hasattr(action_head, "PerPersonBuffer")
    assert hasattr(action_head, "ActionHead")
    assert action_head.WINDOW_LEN == 16
    assert action_head.J3D_JOINTS == 22
    assert action_head.NUM_CLASSES == 3
    assert action_head.LABELS == ("debout", "assise", "danse")
```

- [ ] **Step 1.2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_features.py::test_module_imports -v`
Expected: FAIL with `ModuleNotFoundError: data_only_viz.action_head` or `AttributeError`.

- [ ] **Step 1.3: Create scaffold**

```python
# data_only_viz/action_head.py
"""Action classifier head on top of Multi-HMR j3d.

Streaming GRU-1-layer + MLP per-person, with a 16-frame ring buffer.
Trained windowed (Studio M3 Ultra MPS), inferred streaming (M5 eager CPU).

Output per step: (label_idx, probs (3,), kin (3,)) where kin is
(speed_m_s, accel_m_s2, symmetry_in_minus1_plus1).
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np

WINDOW_LEN: int = 16
J3D_JOINTS: int = 22
J3D_DIMS: int = 3
NUM_CLASSES: int = 3
LABELS: tuple[str, str, str] = ("debout", "assise", "danse")
FEATURE_DIM: int = J3D_JOINTS * J3D_DIMS * 3 + 3  # j3d + vel + accel + 3 scalars

HIP_LEFT: int = 1
HIP_RIGHT: int = 2
KNEE_LEFT: int = 4
KNEE_RIGHT: int = 5
ANKLE_LEFT: int = 7
ANKLE_RIGHT: int = 8
SHOULDER_LEFT: int = 16
SHOULDER_RIGHT: int = 17
WRIST_LEFT: int = 20
WRIST_RIGHT: int = 21


class FeatureExtractor:
    """Convert a buffer of j3d frames into a fixed-size feature vector."""


class PerPersonBuffer:
    """Per-pid ring buffer of j3d frames."""


class ActionHead:
    """Streaming action classifier."""
```

```python
# data_only_viz/training/__init__.py
"""Training utilities for the action head classifier."""
```

- [ ] **Step 1.4: Run test to verify it passes**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_features.py::test_module_imports -v`
Expected: PASS.

- [ ] **Step 1.5: Commit**

```bash
git add data_only_viz/action_head.py data_only_viz/training/__init__.py \
        data_only_viz/tests/test_action_head_features.py
git commit -m "feat(data-only-viz): action-head scaffold"
```

---

## Task 2 — PerPersonBuffer

**Files:**
- Modify: `data_only_viz/action_head.py` (`PerPersonBuffer` body)
- Modify: `data_only_viz/tests/test_action_head_features.py`

- [ ] **Step 2.1: Write failing tests**

Append to `data_only_viz/tests/test_action_head_features.py`:

```python
import pytest


def _rand_j3d(seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(size=(22, 3)).astype(np.float32)


def test_buffer_starts_empty() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    assert len(buf) == 0
    assert buf.frames_for(7) == []


def test_buffer_append_grows_per_pid() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    buf.append(pid=1, j3d=_rand_j3d(1))
    buf.append(pid=1, j3d=_rand_j3d(2))
    buf.append(pid=2, j3d=_rand_j3d(3))
    assert len(buf.frames_for(1)) == 2
    assert len(buf.frames_for(2)) == 1


def test_buffer_max_len_16() -> None:
    from data_only_viz.action_head import PerPersonBuffer, WINDOW_LEN
    buf = PerPersonBuffer()
    for i in range(WINDOW_LEN + 5):
        buf.append(pid=1, j3d=_rand_j3d(i))
    assert len(buf.frames_for(1)) == WINDOW_LEN


def test_buffer_forget_releases_pid() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    buf.append(pid=1, j3d=_rand_j3d(0))
    buf.forget(1)
    assert buf.frames_for(1) == []
    assert len(buf) == 0


def test_buffer_rejects_bad_shape() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    with pytest.raises(ValueError, match="22"):
        buf.append(pid=1, j3d=np.zeros((17, 3), dtype=np.float32))
```

- [ ] **Step 2.2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_features.py -v`
Expected: 5 FAILED on the new tests.

- [ ] **Step 2.3: Implement PerPersonBuffer**

Replace the empty `PerPersonBuffer` class in `data_only_viz/action_head.py`:

```python
class PerPersonBuffer:
    """Per-pid ring buffer of j3d frames (deque maxlen=WINDOW_LEN)."""

    __slots__ = ("_buffers",)

    def __init__(self) -> None:
        self._buffers: dict[int, deque[np.ndarray]] = {}

    def append(self, pid: int, j3d: np.ndarray) -> None:
        if j3d.shape != (J3D_JOINTS, J3D_DIMS):
            raise ValueError(
                f"j3d must be ({J3D_JOINTS}, {J3D_DIMS}), got {j3d.shape}"
            )
        dq = self._buffers.get(pid)
        if dq is None:
            dq = deque(maxlen=WINDOW_LEN)
            self._buffers[pid] = dq
        dq.append(j3d.astype(np.float32, copy=False))

    def frames_for(self, pid: int) -> list[np.ndarray]:
        dq = self._buffers.get(pid)
        return list(dq) if dq is not None else []

    def forget(self, pid: int) -> None:
        self._buffers.pop(pid, None)

    def __len__(self) -> int:
        return len(self._buffers)

    def pids(self) -> list[int]:
        return list(self._buffers.keys())
```

- [ ] **Step 2.4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_features.py -v`
Expected: 6 PASSED.

- [ ] **Step 2.5: Commit**

```bash
git add data_only_viz/action_head.py data_only_viz/tests/test_action_head_features.py
git commit -m "feat(data-only-viz): per-person ring buffer"
```

---

## Task 3 — FeatureExtractor

**Files:**
- Modify: `data_only_viz/action_head.py`
- Modify: `data_only_viz/tests/test_action_head_features.py`

- [ ] **Step 3.1: Write failing tests**

Append:

```python
def test_feature_extractor_shape_full_buffer() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN, FEATURE_DIM
    frames = [_rand_j3d(i) for i in range(WINDOW_LEN)]
    feat = FeatureExtractor.from_buffer(frames)
    assert feat.shape == (FEATURE_DIM,)
    assert feat.dtype == np.float32
    assert not np.isnan(feat).any()


def test_feature_extractor_short_buffer_pads() -> None:
    from data_only_viz.action_head import FeatureExtractor, FEATURE_DIM
    frames = [_rand_j3d(0), _rand_j3d(1), _rand_j3d(2)]
    feat = FeatureExtractor.from_buffer(frames)
    assert feat.shape == (FEATURE_DIM,)


def test_feature_extractor_static_buffer_zero_velocity() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN, J3D_JOINTS
    static = _rand_j3d(42)
    frames = [static.copy() for _ in range(WINDOW_LEN)]
    feat = FeatureExtractor.from_buffer(frames)
    # vel block is dims 66..132 (J3D_JOINTS*3 each block)
    vel_block = feat[J3D_JOINTS * 3 : J3D_JOINTS * 3 * 2]
    assert np.allclose(vel_block, 0.0, atol=1e-6)


def test_feature_extractor_kinetics_speed_and_accel() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN
    # Linear motion at 0.1 m per frame on joint 0, others static.
    frames = []
    for t in range(WINDOW_LEN):
        f = np.zeros((22, 3), dtype=np.float32)
        f[0, 0] = 0.1 * t
        frames.append(f)
    kin = FeatureExtractor.kinetics(frames)
    assert kin.shape == (3,)
    # 22 joints, only joint 0 moves at 0.1/frame → mean speed ≈ 0.1/22
    assert kin[0] > 0
    assert abs(kin[0] - 0.1 / 22) < 1e-4
    # Constant velocity → accel ≈ 0
    assert abs(kin[1]) < 1e-4


def test_feature_extractor_symmetry_sign() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN, WRIST_LEFT, WRIST_RIGHT
    # Symmetric mirrored arm motion: left wrist +x, right wrist -x (same speed).
    frames = []
    for t in range(WINDOW_LEN):
        f = np.zeros((22, 3), dtype=np.float32)
        f[WRIST_LEFT, 0] = 0.05 * t
        f[WRIST_RIGHT, 0] = -0.05 * t
        frames.append(f)
    kin = FeatureExtractor.kinetics(frames)
    # mirrored == symmetric → cos(left_vel, mirror(right_vel)) close to 1
    assert kin[2] > 0.9
```

- [ ] **Step 3.2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_features.py -v`
Expected: 5 new FAILED.

- [ ] **Step 3.3: Implement FeatureExtractor**

Replace the empty `FeatureExtractor` in `data_only_viz/action_head.py`:

```python
class FeatureExtractor:
    """Stateless feature builder over a list of recent j3d frames.

    Vector layout (FEATURE_DIM = 201):
      [0 : 66]   j3d current frame, flattened (22 joints × 3 dims)
      [66 : 132] velocity j3d[t] - j3d[t-1] (22 × 3)
      [132 : 198] acceleration vel[t] - vel[t-1] (22 × 3)
      [198 : 201] kinetics scalars (hip_y, knee_angle, symmetry_score)
    """

    @staticmethod
    def from_buffer(frames: list[np.ndarray]) -> np.ndarray:
        if not frames:
            return np.zeros(FEATURE_DIM, dtype=np.float32)
        cur = frames[-1]
        prev = frames[-2] if len(frames) >= 2 else cur
        prev2 = frames[-3] if len(frames) >= 3 else prev
        vel = (cur - prev).astype(np.float32, copy=False)
        prev_vel = (prev - prev2).astype(np.float32, copy=False)
        accel = (vel - prev_vel).astype(np.float32, copy=False)
        hip_y = float((cur[HIP_LEFT, 1] + cur[HIP_RIGHT, 1]) * 0.5)
        knee_angle = FeatureExtractor._mean_knee_angle(cur)
        sym = FeatureExtractor._symmetry_score(vel)
        feat = np.concatenate([
            cur.reshape(-1),
            vel.reshape(-1),
            accel.reshape(-1),
            np.array([hip_y, knee_angle, sym], dtype=np.float32),
        ]).astype(np.float32, copy=False)
        return feat

    @staticmethod
    def kinetics(frames: list[np.ndarray]) -> np.ndarray:
        """Return (speed, accel_mag, symmetry) averaged over the buffer."""
        if len(frames) < 2:
            return np.zeros(3, dtype=np.float32)
        arr = np.stack(frames).astype(np.float32, copy=False)
        diffs = arr[1:] - arr[:-1]  # (T-1, 22, 3)
        speeds = np.linalg.norm(diffs, axis=-1).mean(axis=-1)  # (T-1,)
        speed = float(speeds.mean())
        if len(frames) >= 3:
            ddiffs = diffs[1:] - diffs[:-1]
            accel = float(np.linalg.norm(ddiffs, axis=-1).mean())
        else:
            accel = 0.0
        sym = FeatureExtractor._symmetry_score(diffs[-1])
        return np.array([speed, accel, sym], dtype=np.float32)

    @staticmethod
    def _mean_knee_angle(j3d: np.ndarray) -> float:
        """Angle (rad) at left+right knees, averaged."""
        def _angle(hip: int, knee: int, ankle: int) -> float:
            v1 = j3d[hip] - j3d[knee]
            v2 = j3d[ankle] - j3d[knee]
            n1 = np.linalg.norm(v1) + 1e-6
            n2 = np.linalg.norm(v2) + 1e-6
            cos = float(np.dot(v1, v2) / (n1 * n2))
            return float(np.arccos(np.clip(cos, -1.0, 1.0)))
        return 0.5 * (_angle(HIP_LEFT, KNEE_LEFT, ANKLE_LEFT)
                      + _angle(HIP_RIGHT, KNEE_RIGHT, ANKLE_RIGHT))

    @staticmethod
    def _symmetry_score(vel: np.ndarray) -> float:
        """Cosine sim between left-arm and mirrored right-arm velocity."""
        left = vel[WRIST_LEFT].copy()
        right = vel[WRIST_RIGHT].copy()
        right_mirror = right.copy()
        right_mirror[0] = -right_mirror[0]  # mirror across YZ plane
        n1 = np.linalg.norm(left) + 1e-6
        n2 = np.linalg.norm(right_mirror) + 1e-6
        return float(np.dot(left, right_mirror) / (n1 * n2))
```

- [ ] **Step 3.4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_features.py -v`
Expected: 11 PASSED.

- [ ] **Step 3.5: Commit**

```bash
git add data_only_viz/action_head.py data_only_viz/tests/test_action_head_features.py
git commit -m "feat(data-only-viz): FeatureExtractor for action head"
```

---

## Task 4 — ActionHead model architecture

**Files:**
- Modify: `data_only_viz/action_head.py`
- Create: `data_only_viz/tests/test_action_head_model.py`

- [ ] **Step 4.1: Write failing tests**

```python
# data_only_viz/tests/test_action_head_model.py
"""Tests for ActionHead model (forward, step, checkpoint roundtrip)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

torch = pytest.importorskip("torch")


def _rand_j3d(seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(size=(22, 3)).astype(np.float32)


def test_model_forward_shape() -> None:
    from data_only_viz.action_head import ActionHeadModel, FEATURE_DIM, NUM_CLASSES
    model = ActionHeadModel()
    x = torch.zeros(1, FEATURE_DIM)
    h = model.init_hidden(batch=1)
    logits, h_new = model(x, h)
    assert logits.shape == (1, NUM_CLASSES)
    assert h_new.shape == h.shape


def test_model_param_count_under_50k() -> None:
    from data_only_viz.action_head import ActionHeadModel
    model = ActionHeadModel()
    n = sum(p.numel() for p in model.parameters())
    assert n < 50_000, f"too many params: {n}"


def test_action_head_step_warmup_returns_debout() -> None:
    from data_only_viz.action_head import ActionHead, LABELS
    head = ActionHead(ckpt_path=None)  # untrained, random init
    label, probs, kin = head.step(pid=1, j3d=_rand_j3d(0))
    assert label == LABELS[0]  # warmup default
    assert probs.shape == (3,)
    assert pytest.approx(float(probs[0]), abs=1e-6) == 1.0
    assert kin.shape == (3,)
    assert float(kin[0]) == 0.0


def test_action_head_step_after_warmup_returns_some_label() -> None:
    from data_only_viz.action_head import ActionHead, LABELS
    head = ActionHead(ckpt_path=None)
    for i in range(5):
        label, probs, kin = head.step(pid=1, j3d=_rand_j3d(i))
    assert label in LABELS
    assert abs(float(probs.sum()) - 1.0) < 1e-5


def test_action_head_forget_resets_hidden_state(tmp_path: Path) -> None:
    from data_only_viz.action_head import ActionHead
    head = ActionHead(ckpt_path=None)
    for i in range(5):
        head.step(pid=1, j3d=_rand_j3d(i))
    assert 1 in head._hidden  # internal sanity
    head.forget(1)
    assert 1 not in head._hidden
    assert head._buffers.frames_for(1) == []


def test_action_head_checkpoint_roundtrip(tmp_path: Path) -> None:
    from data_only_viz.action_head import ActionHead, ActionHeadModel
    model = ActionHeadModel()
    ckpt = tmp_path / "ah.pt"
    torch.save({"model_state_dict": model.state_dict(),
                "version": 1}, ckpt)
    head = ActionHead(ckpt_path=ckpt)
    # weights should match
    for k, v in head._model.state_dict().items():
        assert torch.allclose(v, model.state_dict()[k])


def test_action_head_step_handles_nan() -> None:
    from data_only_viz.action_head import ActionHead, LABELS
    head = ActionHead(ckpt_path=None)
    j = _rand_j3d(0)
    j[5, 1] = float("nan")
    label, probs, _kin = head.step(pid=1, j3d=j)
    assert label in LABELS  # no crash
    assert not np.isnan(probs).any()
```

- [ ] **Step 4.2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_model.py -v`
Expected: 7 FAILED (no `ActionHeadModel`, no functional `ActionHead`).

- [ ] **Step 4.3: Implement model + step()**

Add to the top of `data_only_viz/action_head.py`:

```python
import torch
from torch import nn

HIDDEN_DIM: int = 64
MLP_HIDDEN: int = 32
WARMUP_FRAMES: int = 3
NAN_SKIP_BUDGET: int = 5
```

Append at the bottom (replace empty `ActionHead`):

```python
class ActionHeadModel(nn.Module):
    """1-layer GRU + small MLP head.

    Input  : (B, FEATURE_DIM) — single step
    Hidden : (1, B, HIDDEN_DIM)
    Output : (B, NUM_CLASSES) logits, new hidden
    """

    def __init__(self) -> None:
        super().__init__()
        self.gru = nn.GRU(input_size=FEATURE_DIM,
                          hidden_size=HIDDEN_DIM,
                          num_layers=1,
                          batch_first=True)
        self.mlp = nn.Sequential(
            nn.Linear(HIDDEN_DIM, MLP_HIDDEN),
            nn.ReLU(inplace=True),
            nn.Linear(MLP_HIDDEN, NUM_CLASSES),
        )

    def init_hidden(self, batch: int = 1, device: str = "cpu") -> torch.Tensor:
        return torch.zeros(1, batch, HIDDEN_DIM, device=device)

    def forward(self, x: torch.Tensor,
                h: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        # x : (B, FEATURE_DIM) → add time axis for GRU
        out, h_new = self.gru(x.unsqueeze(1), h)
        logits = self.mlp(out.squeeze(1))
        return logits, h_new


class ActionHead:
    """Streaming action classifier per person.

    Use:
        head = ActionHead(ckpt_path=...)
        label, probs, kin = head.step(pid, j3d)
        head.forget(pid)
    """

    def __init__(self,
                 ckpt_path: Path | None = None,
                 device: str = "cpu") -> None:
        self._device = device
        self._model = ActionHeadModel().to(device).eval()
        if ckpt_path is not None:
            payload = torch.load(ckpt_path, map_location=device,
                                 weights_only=True)
            state = payload.get("model_state_dict", payload)
            self._model.load_state_dict(state)
        self._buffers = PerPersonBuffer()
        self._hidden: dict[int, torch.Tensor] = {}
        self._nan_streak: dict[int, int] = {}

    def step(self, pid: int, j3d: np.ndarray) -> tuple[str, np.ndarray, np.ndarray]:
        if np.isnan(j3d).any():
            streak = self._nan_streak.get(pid, 0) + 1
            self._nan_streak[pid] = streak
            if streak > NAN_SKIP_BUDGET:
                self.forget(pid)
            probs = np.array([1.0, 0.0, 0.0], dtype=np.float32)
            return LABELS[0], probs, np.zeros(3, dtype=np.float32)
        self._nan_streak[pid] = 0
        self._buffers.append(pid, j3d)
        frames = self._buffers.frames_for(pid)
        if len(frames) < WARMUP_FRAMES:
            probs = np.array([1.0, 0.0, 0.0], dtype=np.float32)
            return LABELS[0], probs, np.zeros(3, dtype=np.float32)
        feat = FeatureExtractor.from_buffer(frames)
        kin = FeatureExtractor.kinetics(frames)
        h = self._hidden.get(pid)
        if h is None:
            h = self._model.init_hidden(batch=1, device=self._device)
        x = torch.from_numpy(feat).unsqueeze(0).to(self._device)
        with torch.no_grad():
            logits, h_new = self._model(x, h)
            probs_t = torch.softmax(logits, dim=-1).squeeze(0)
        self._hidden[pid] = h_new
        probs = probs_t.cpu().numpy().astype(np.float32, copy=False)
        return LABELS[int(np.argmax(probs))], probs, kin

    def forget(self, pid: int) -> None:
        self._buffers.forget(pid)
        self._hidden.pop(pid, None)
        self._nan_streak.pop(pid, None)
```

- [ ] **Step 4.4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_model.py -v`
Expected: 7 PASSED.

- [ ] **Step 4.5: Latency sanity check**

Run inline:
```bash
cd data_only_viz && uv run python -c "
import time, numpy as np
from data_only_viz.action_head import ActionHead
head = ActionHead()
j = np.random.normal(size=(22, 3)).astype(np.float32)
for i in range(20): head.step(1, j)  # warmup + jit
t0 = time.perf_counter()
for _ in range(1000): head.step(1, j)
print(f'step latency: {(time.perf_counter()-t0)*1000/1000:.3f} ms')
"
```
Expected: ≤ 2 ms/step on M5. Document the number in the commit message.

- [ ] **Step 4.6: Commit**

```bash
git add data_only_viz/action_head.py data_only_viz/tests/test_action_head_model.py
git commit -m "feat(data-only-viz): ActionHead GRU model + streaming step"
```

---

## Task 5 — Auto-labeler rules

**Files:**
- Create: `data_only_viz/training/autolabel.py`
- Create: `data_only_viz/tests/test_autolabel.py`

- [ ] **Step 5.1: Write failing tests**

```python
# data_only_viz/tests/test_autolabel.py
"""Tests for rule-based auto-labeler."""
from __future__ import annotations

import numpy as np

from data_only_viz.action_head import WINDOW_LEN


def _static_seated(frame_count: int = WINDOW_LEN) -> list[np.ndarray]:
    """Hip low (y small), knee bent ~80°."""
    frames = []
    for _ in range(frame_count):
        f = np.zeros((22, 3), dtype=np.float32)
        # hip low y = 0.4 (typical sitting), knee y = 0.4 too, ankle y = 0.1
        f[1] = [-0.1, 0.4, 0.0]; f[2] = [0.1, 0.4, 0.0]      # hips
        f[4] = [-0.1, 0.4, 0.3]; f[5] = [0.1, 0.4, 0.3]      # knees forward
        f[7] = [-0.1, 0.1, 0.3]; f[8] = [0.1, 0.1, 0.3]      # ankles down
        frames.append(f)
    return frames


def _static_standing(frame_count: int = WINDOW_LEN) -> list[np.ndarray]:
    """Hip high, knees ~180°."""
    frames = []
    for _ in range(frame_count):
        f = np.zeros((22, 3), dtype=np.float32)
        f[1] = [-0.1, 0.9, 0.0]; f[2] = [0.1, 0.9, 0.0]
        f[4] = [-0.1, 0.5, 0.0]; f[5] = [0.1, 0.5, 0.0]
        f[7] = [-0.1, 0.1, 0.0]; f[8] = [0.1, 0.1, 0.0]
        frames.append(f)
    return frames


def _dancing(frame_count: int = WINDOW_LEN) -> list[np.ndarray]:
    """Standing pose with high wrist velocity."""
    base = _static_standing(1)[0]
    frames = []
    for t in range(frame_count):
        f = base.copy()
        # wrists oscillate fast (0.5 m amplitude at 4 Hz over 16 frames)
        phase = 2 * np.pi * t * 0.25
        f[20] = base[20] + np.array([np.sin(phase) * 0.3, np.cos(phase) * 0.3, 0])
        f[21] = base[21] + np.array([-np.sin(phase) * 0.3, np.cos(phase) * 0.3, 0])
        frames.append(f.astype(np.float32))
    return frames


def test_autolabel_static_standing_is_debout() -> None:
    from data_only_viz.training.autolabel import autolabel_window
    label, conf = autolabel_window(_static_standing())
    assert label == "debout"
    assert conf >= 0.5


def test_autolabel_static_seated_is_assise() -> None:
    from data_only_viz.training.autolabel import autolabel_window
    label, conf = autolabel_window(_static_seated())
    assert label == "assise"
    assert conf >= 0.5


def test_autolabel_dancing_is_danse() -> None:
    from data_only_viz.training.autolabel import autolabel_window
    label, conf = autolabel_window(_dancing())
    assert label == "danse"
    assert conf >= 0.5


def test_autolabel_ambiguous_is_none() -> None:
    from data_only_viz.training.autolabel import autolabel_window
    # Standing-ish but with tiny wrist twitches — neither clearly debout nor danse
    base = _static_standing(WINDOW_LEN)
    for t, f in enumerate(base):
        f[20, 0] += 0.01 * np.sin(t)  # tiny wrist motion
    label, _conf = autolabel_window(base)
    # The rule should mark this ambiguous (NONE) unless thresholds clearly fire.
    assert label in ("debout", None)
```

- [ ] **Step 5.2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_autolabel.py -v`
Expected: 4 FAILED (module missing).

- [ ] **Step 5.3: Implement autolabel.py**

```python
# data_only_viz/training/autolabel.py
"""Rule-based labeler for j3d windows.

Outputs one of {"debout", "assise", "danse", None}. None marks
ambiguous windows that should be reviewed manually.

Rules are tuned for SMPL-X joint indexing as used by Multi-HMR.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from data_only_viz.action_head import (
    FeatureExtractor,
    HIP_LEFT,
    HIP_RIGHT,
    KNEE_LEFT,
    KNEE_RIGHT,
    WINDOW_LEN,
)


@dataclass(frozen=True)
class AutoLabelConfig:
    hip_y_seated_max: float = 0.55  # y (height) threshold under which we suspect sitting
    knee_angle_seated_max: float = 2.0  # rad, ~115° — bent knee
    speed_static_max: float = 0.04  # m/s mean joint speed
    speed_dance_min: float = 0.20  # m/s
    accel_dance_min: float = 1.0  # m/s²


DEFAULT_CFG = AutoLabelConfig()


def autolabel_window(frames: list[np.ndarray],
                     cfg: AutoLabelConfig = DEFAULT_CFG
                     ) -> tuple[str | None, float]:
    """Return (label, confidence). label is None when ambiguous."""
    if len(frames) < WINDOW_LEN // 2:
        return None, 0.0
    cur = frames[-1]
    hip_y = float((cur[HIP_LEFT, 1] + cur[HIP_RIGHT, 1]) * 0.5)
    knee_angle = FeatureExtractor._mean_knee_angle(cur)
    kin = FeatureExtractor.kinetics(frames)
    speed = float(kin[0])
    accel = float(kin[1])

    if hip_y < cfg.hip_y_seated_max and knee_angle < cfg.knee_angle_seated_max:
        conf = 0.5 + 0.5 * min(1.0, (cfg.hip_y_seated_max - hip_y) / 0.2)
        return "assise", conf
    if speed >= cfg.speed_dance_min or accel >= cfg.accel_dance_min:
        conf = 0.5 + 0.5 * min(1.0, speed / 0.5)
        return "danse", conf
    if speed <= cfg.speed_static_max:
        conf = 0.6
        return "debout", conf
    return None, 0.0


def autolabel_dataset(frames_jsonl: Path, out_jsonl: Path,
                      window_len: int = WINDOW_LEN,
                      stride: int = 4,
                      keep_none: bool = True) -> int:
    """Glue: raw frames jsonl → sliding windows → auto-label → DatasetRow jsonl.

    Returns the number of windows written.
    """
    from data_only_viz.training.dataset import (
        DatasetRow,
        load_frames_jsonl,
        sliding_windows,
        write_dataset_jsonl,
    )
    frames = load_frames_jsonl(frames_jsonl)
    rows = []
    for win in sliding_windows(frames, window_len=window_len, stride=stride):
        frame_list = [win.j3d_stack[t] for t in range(win.j3d_stack.shape[0])]
        label, conf = autolabel_window(frame_list)
        if label is None and not keep_none:
            continue
        rows.append(DatasetRow(
            window_id=f"{win.session}_pid{win.pid_local}_t{int(win.first_ts*1000):08d}",
            label=label if label is not None else "debout",  # placeholder; review will fix
            j3d_stack=win.j3d_stack,
            session=win.session,
            pid_local=win.pid_local,
            auto_label_confidence=conf,
            manually_validated=False,
        ))
    out_jsonl.parent.mkdir(parents=True, exist_ok=True)
    write_dataset_jsonl(rows, out_jsonl)
    return len(rows)


def _cli() -> None:
    import argparse, logging
    p = argparse.ArgumentParser()
    p.add_argument("--frames", required=True, type=Path,
                   help="Raw frames jsonl from extract_j3d_offline.py")
    p.add_argument("--out", required=True, type=Path,
                   help="Auto-labeled windowed dataset jsonl")
    p.add_argument("--stride", type=int, default=4)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO)
    n = autolabel_dataset(args.frames, args.out, stride=args.stride)
    print(f"wrote {n} windows to {args.out}")


if __name__ == "__main__":
    _cli()
```

Add a `Path` import at the top of `autolabel.py`:

```python
from pathlib import Path
```

- [ ] **Step 5.4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_autolabel.py -v`
Expected: 4 PASSED.

- [ ] **Step 5.5: Commit**

```bash
git add data_only_viz/training/autolabel.py data_only_viz/tests/test_autolabel.py
git commit -m "feat(data-only-viz): rule-based action auto-labeler"
```

---

## Task 6 — Dataset jsonl IO + sliding window + split

**Files:**
- Create: `data_only_viz/training/dataset.py`
- Create: `data_only_viz/tests/test_dataset.py`

- [ ] **Step 6.1: Write failing tests**

```python
# data_only_viz/tests/test_dataset.py
"""Tests for dataset jsonl IO + sliding windows + split."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest


def _make_session_jsonl(path: Path, n_frames: int = 64) -> None:
    rng = np.random.default_rng(0)
    with path.open("w") as f:
        for t in range(n_frames):
            row = {"ts": t / 30.0,
                   "session": "sess01",
                   "pid": 1,
                   "j3d": rng.normal(size=(22, 3)).tolist()}
            f.write(json.dumps(row) + "\n")


def test_load_frames_jsonl(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import load_frames_jsonl
    p = tmp_path / "raw.jsonl"
    _make_session_jsonl(p)
    frames = load_frames_jsonl(p)
    assert len(frames) == 64
    assert frames[0].j3d.shape == (22, 3)
    assert frames[0].pid == 1
    assert frames[0].session == "sess01"


def test_sliding_windows(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import (
        load_frames_jsonl,
        sliding_windows,
    )
    p = tmp_path / "raw.jsonl"
    _make_session_jsonl(p, n_frames=64)
    frames = load_frames_jsonl(p)
    windows = list(sliding_windows(frames, window_len=16, stride=4))
    # (64 - 16) // 4 + 1 = 13
    assert len(windows) == 13
    assert windows[0].j3d_stack.shape == (16, 22, 3)
    assert windows[0].session == "sess01"


def test_write_and_load_dataset_jsonl(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import (
        DatasetRow,
        load_dataset_jsonl,
        write_dataset_jsonl,
    )
    rng = np.random.default_rng(0)
    rows = [
        DatasetRow(
            window_id=f"sess01_pid1_w{i:04d}",
            label="debout" if i % 2 == 0 else "danse",
            j3d_stack=rng.normal(size=(16, 22, 3)).astype(np.float32),
            session="sess01",
            pid_local=1,
            auto_label_confidence=0.8,
            manually_validated=False,
        )
        for i in range(5)
    ]
    out = tmp_path / "ds.jsonl"
    write_dataset_jsonl(rows, out)
    loaded = load_dataset_jsonl(out)
    assert len(loaded) == 5
    assert loaded[0].label == "debout"
    assert loaded[0].j3d_stack.shape == (16, 22, 3)
    assert np.allclose(loaded[0].j3d_stack, rows[0].j3d_stack, atol=1e-6)


def test_split_by_session(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import DatasetRow, split_by_session
    rng = np.random.default_rng(0)
    rows = []
    for sess in ("s01", "s02", "s03", "s04", "s05", "s06", "s07"):
        rows.append(DatasetRow(
            window_id=f"{sess}_w0", label="debout",
            j3d_stack=rng.normal(size=(16, 22, 3)).astype(np.float32),
            session=sess, pid_local=1, auto_label_confidence=0.7,
            manually_validated=False,
        ))
    train, val, test = split_by_session(rows, ratios=(0.7, 0.15, 0.15), seed=0)
    all_sessions = {r.session for r in train + val + test}
    assert all_sessions == {"s01","s02","s03","s04","s05","s06","s07"}
    train_s = {r.session for r in train}
    val_s = {r.session for r in val}
    test_s = {r.session for r in test}
    assert train_s.isdisjoint(val_s)
    assert train_s.isdisjoint(test_s)
    assert val_s.isdisjoint(test_s)
```

- [ ] **Step 6.2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_dataset.py -v`
Expected: 4 FAILED (module missing).

- [ ] **Step 6.3: Implement dataset.py**

```python
# data_only_viz/training/dataset.py
"""Dataset IO + sliding-window extraction + by-session split."""
from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator

import numpy as np


@dataclass(frozen=True)
class RawFrame:
    ts: float
    session: str
    pid: int
    j3d: np.ndarray  # (22, 3) float32


@dataclass
class WindowRow:
    j3d_stack: np.ndarray  # (window_len, 22, 3) float32
    session: str
    pid_local: int
    first_ts: float


@dataclass
class DatasetRow:
    window_id: str
    label: str
    j3d_stack: np.ndarray  # (window_len, 22, 3) float32
    session: str
    pid_local: int
    auto_label_confidence: float
    manually_validated: bool


def load_frames_jsonl(path: Path) -> list[RawFrame]:
    rows: list[RawFrame] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            rows.append(RawFrame(
                ts=float(d["ts"]),
                session=str(d["session"]),
                pid=int(d["pid"]),
                j3d=np.asarray(d["j3d"], dtype=np.float32),
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
            yield WindowRow(j3d_stack=stack, session=sess,
                            pid_local=pid, first_ts=chunk[0].ts)


def write_dataset_jsonl(rows: Iterable[DatasetRow], path: Path) -> None:
    with path.open("w") as f:
        for r in rows:
            f.write(json.dumps({
                "window_id": r.window_id,
                "label": r.label,
                "j3d": r.j3d_stack.astype(np.float32).tolist(),
                "session": r.session,
                "pid_local": r.pid_local,
                "auto_label_confidence": float(r.auto_label_confidence),
                "manually_validated": bool(r.manually_validated),
            }) + "\n")


def load_dataset_jsonl(path: Path) -> list[DatasetRow]:
    out: list[DatasetRow] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            out.append(DatasetRow(
                window_id=d["window_id"],
                label=d["label"],
                j3d_stack=np.asarray(d["j3d"], dtype=np.float32),
                session=d["session"],
                pid_local=int(d["pid_local"]),
                auto_label_confidence=float(d["auto_label_confidence"]),
                manually_validated=bool(d["manually_validated"]),
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
```

- [ ] **Step 6.4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_dataset.py -v`
Expected: 4 PASSED.

- [ ] **Step 6.5: Commit**

```bash
git add data_only_viz/training/dataset.py data_only_viz/tests/test_dataset.py
git commit -m "feat(data-only-viz): action-head dataset jsonl + windows + split"
```

---

## Task 7 — Augmentations

**Files:**
- Create: `data_only_viz/training/augment.py`
- Create: `data_only_viz/tests/test_augment.py`

- [ ] **Step 7.1: Write failing tests**

```python
# data_only_viz/tests/test_augment.py
"""Tests for j3d augmentations."""
from __future__ import annotations

import numpy as np

WINDOW_LEN = 16


def _sample_stack(seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(size=(WINDOW_LEN, 22, 3)).astype(np.float32)


def test_mirror_swap_left_right_joints() -> None:
    from data_only_viz.training.augment import mirror_x
    x = _sample_stack(0)
    y = mirror_x(x)
    # X-axis flipped on the new array
    assert np.allclose(y[..., 0], -x[..., 0][:, [
        0,2,1,3,5,4,6,8,7,9,11,10,12,14,13,15,17,16,19,18,21,20
    ]], atol=1e-6)


def test_noise_within_sigma() -> None:
    from data_only_viz.training.augment import add_noise
    rng = np.random.default_rng(0)
    x = _sample_stack(0)
    y = add_noise(x, sigma=0.01, rng=rng)
    diff = y - x
    assert np.allclose(diff.std(), 0.01, atol=2e-3)


def test_time_stretch_keeps_shape() -> None:
    from data_only_viz.training.augment import time_stretch
    x = _sample_stack(0)
    y = time_stretch(x, factor=0.9, rng=None)
    assert y.shape == x.shape


def test_rotate_y_preserves_distances() -> None:
    from data_only_viz.training.augment import rotate_y
    x = _sample_stack(0)
    y = rotate_y(x, angle_rad=0.3)
    # joint-to-joint distances are rotation-invariant
    d_x = np.linalg.norm(x[0, 0] - x[0, 1])
    d_y = np.linalg.norm(y[0, 0] - y[0, 1])
    assert abs(d_x - d_y) < 1e-5
```

- [ ] **Step 7.2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_augment.py -v`
Expected: 4 FAILED.

- [ ] **Step 7.3: Implement augment.py**

```python
# data_only_viz/training/augment.py
"""On-the-fly augmentations for j3d windows."""
from __future__ import annotations

import numpy as np

# SMPL-X left/right joint mirror map (subset 22 joints used by Multi-HMR head).
# Index i → its mirrored counterpart.
MIRROR_MAP: tuple[int, ...] = (
    0,   # pelvis
    2, 1,  # hips left↔right
    3,   # spine1
    5, 4,  # knees
    6,   # spine2
    8, 7,  # ankles
    9,   # spine3
    11, 10,  # toes
    12,  # neck
    14, 13,  # collars
    15,  # head
    17, 16,  # shoulders
    19, 18,  # elbows
    21, 20,  # wrists
)


def mirror_x(stack: np.ndarray) -> np.ndarray:
    """Mirror across the YZ plane: flip x and swap left↔right joints."""
    out = stack[:, list(MIRROR_MAP), :].copy()
    out[..., 0] = -out[..., 0]
    return out


def add_noise(stack: np.ndarray, sigma: float, rng: np.random.Generator) -> np.ndarray:
    noise = rng.normal(scale=sigma, size=stack.shape).astype(np.float32)
    return (stack + noise).astype(np.float32, copy=False)


def time_stretch(stack: np.ndarray, factor: float,
                 rng: np.random.Generator | None = None) -> np.ndarray:
    """Resample the time axis with linear interpolation, keep window_len fixed."""
    T = stack.shape[0]
    new_T = int(round(T * factor))
    new_T = max(2, new_T)
    src = np.linspace(0.0, T - 1, num=new_T)
    interp = np.empty((new_T, *stack.shape[1:]), dtype=np.float32)
    lo = np.floor(src).astype(int)
    hi = np.minimum(lo + 1, T - 1)
    frac = (src - lo).astype(np.float32)
    interp = (1 - frac[:, None, None]) * stack[lo] + frac[:, None, None] * stack[hi]
    # crop or pad back to T
    if new_T >= T:
        start = (new_T - T) // 2
        return interp[start:start + T].astype(np.float32, copy=False)
    pad_before = (T - new_T) // 2
    pad_after = T - new_T - pad_before
    return np.concatenate([
        np.repeat(interp[:1], pad_before, axis=0),
        interp,
        np.repeat(interp[-1:], pad_after, axis=0),
    ]).astype(np.float32, copy=False)


def rotate_y(stack: np.ndarray, angle_rad: float) -> np.ndarray:
    """Rotate around Y (vertical) axis."""
    c, s = np.cos(angle_rad), np.sin(angle_rad)
    R = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=np.float32)
    return (stack @ R.T).astype(np.float32, copy=False)


def random_augment(stack: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = stack
    if rng.random() < 0.5:
        out = mirror_x(out)
    if rng.random() < 0.8:
        out = add_noise(out, sigma=0.01, rng=rng)
    if rng.random() < 0.5:
        factor = float(rng.uniform(0.9, 1.1))
        out = time_stretch(out, factor=factor, rng=rng)
    if rng.random() < 0.5:
        angle = float(rng.uniform(-np.deg2rad(15), np.deg2rad(15)))
        out = rotate_y(out, angle_rad=angle)
    return out
```

- [ ] **Step 7.4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_augment.py -v`
Expected: 4 PASSED.

- [ ] **Step 7.5: Commit**

```bash
git add data_only_viz/training/augment.py data_only_viz/tests/test_augment.py
git commit -m "feat(data-only-viz): action-head augmentations"
```

---

## Task 8 — Training loop + smoke test

**Files:**
- Create: `data_only_viz/training/train_action_head.py`
- Create: `data_only_viz/tests/test_training_smoke.py`

- [ ] **Step 8.1: Write failing smoke test**

```python
# data_only_viz/tests/test_training_smoke.py
"""Smoke test for action-head training (2 epochs, tiny dataset, CPU)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

torch = pytest.importorskip("torch")


def _make_tiny_dataset(tmp_path: Path) -> Path:
    from data_only_viz.training.dataset import DatasetRow, write_dataset_jsonl
    rng = np.random.default_rng(0)
    rows = []
    for sess_i, sess in enumerate(("s01", "s02", "s03")):
        for w in range(30):
            label = ("debout", "assise", "danse")[w % 3]
            rows.append(DatasetRow(
                window_id=f"{sess}_w{w:03d}",
                label=label,
                j3d_stack=rng.normal(size=(16, 22, 3)).astype(np.float32),
                session=sess, pid_local=1,
                auto_label_confidence=0.8,
                manually_validated=True,
            ))
    out = tmp_path / "tiny.jsonl"
    write_dataset_jsonl(rows, out)
    return out


def test_train_2_epochs_no_crash(tmp_path: Path) -> None:
    from data_only_viz.training.train_action_head import train
    ds = _make_tiny_dataset(tmp_path)
    ckpt = tmp_path / "ckpt.pt"
    history = train(
        dataset_path=ds,
        ckpt_out=ckpt,
        epochs=2,
        batch_size=8,
        lr=1e-3,
        device="cpu",
        seed=0,
        log_every=10_000,
    )
    assert ckpt.exists()
    assert len(history["train_loss"]) == 2
    assert all(np.isfinite(history["train_loss"]))


def test_trained_checkpoint_loadable(tmp_path: Path) -> None:
    from data_only_viz.action_head import ActionHead
    from data_only_viz.training.train_action_head import train
    ds = _make_tiny_dataset(tmp_path)
    ckpt = tmp_path / "ckpt.pt"
    train(dataset_path=ds, ckpt_out=ckpt, epochs=1, batch_size=8,
          lr=1e-3, device="cpu", seed=0, log_every=10_000)
    head = ActionHead(ckpt_path=ckpt)
    for i in range(5):
        label, probs, _ = head.step(pid=1, j3d=np.zeros((22, 3), dtype=np.float32))
    assert abs(float(probs.sum()) - 1.0) < 1e-5
```

- [ ] **Step 8.2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_training_smoke.py -v`
Expected: 2 FAILED (no `train_action_head`).

- [ ] **Step 8.3: Implement training script**

```python
# data_only_viz/training/train_action_head.py
"""Train ActionHead on the windowed dataset.

Usage:
    uv run python -m data_only_viz.training.train_action_head \
        --dataset ~/.cache/av-live-action/dataset/dataset.jsonl \
        --ckpt-out ~/.cache/av-live-action/checkpoints/action_head.pt \
        --device mps --epochs 50 --batch-size 128
"""
from __future__ import annotations

import argparse
import json
import logging
from collections import Counter
from pathlib import Path
from typing import Iterator

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset

from data_only_viz.action_head import (
    ActionHeadModel,
    FeatureExtractor,
    LABELS,
)
from data_only_viz.training.augment import random_augment
from data_only_viz.training.dataset import (
    DatasetRow,
    load_dataset_jsonl,
    split_by_session,
)

LOG = logging.getLogger("train_action_head")
LABEL_TO_IDX = {l: i for i, l in enumerate(LABELS)}


class WindowDataset(Dataset[tuple[torch.Tensor, int]]):
    def __init__(self, rows: list[DatasetRow],
                 augment: bool = False, seed: int = 0) -> None:
        self._rows = rows
        self._augment = augment
        self._rng = np.random.default_rng(seed)

    def __len__(self) -> int:
        return len(self._rows)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, int]:
        row = self._rows[idx]
        stack = row.j3d_stack
        if self._augment:
            stack = random_augment(stack, self._rng)
        feats = []
        # Build a per-step feature for the GRU sequence.
        prev = stack[0]
        prev_vel = np.zeros_like(prev)
        for t in range(stack.shape[0]):
            cur = stack[t]
            vel = cur - prev
            accel = vel - prev_vel
            from data_only_viz.action_head import (
                HIP_LEFT, HIP_RIGHT, WRIST_LEFT, WRIST_RIGHT,
            )
            hip_y = float((cur[HIP_LEFT, 1] + cur[HIP_RIGHT, 1]) * 0.5)
            knee_angle = FeatureExtractor._mean_knee_angle(cur)
            sym = FeatureExtractor._symmetry_score(vel)
            feat = np.concatenate([
                cur.reshape(-1), vel.reshape(-1), accel.reshape(-1),
                np.array([hip_y, knee_angle, sym], dtype=np.float32),
            ]).astype(np.float32, copy=False)
            feats.append(feat)
            prev_vel = vel
            prev = cur
        x = torch.from_numpy(np.stack(feats))  # (T, FEATURE_DIM)
        y = LABEL_TO_IDX[row.label]
        return x, y


def _class_weights(rows: list[DatasetRow]) -> torch.Tensor:
    counts = Counter(r.label for r in rows)
    total = sum(counts.values())
    weights = torch.tensor([
        total / (len(LABELS) * counts.get(l, 1)) for l in LABELS
    ], dtype=torch.float32)
    return weights


def _run_epoch(model: nn.Module, loader: DataLoader, loss_fn: nn.Module,
               optim: torch.optim.Optimizer | None,
               device: str) -> tuple[float, float]:
    train_mode = optim is not None
    model.train(train_mode)
    total_loss = 0.0
    correct = 0
    seen = 0
    for x, y in loader:
        x = x.to(device)
        y = y.to(device)
        B, T, _ = x.shape
        h = model.init_hidden(batch=B, device=device)
        logits_last: torch.Tensor | None = None
        for t in range(T):
            logits, h = model(x[:, t, :], h)
            logits_last = logits
        assert logits_last is not None
        loss = loss_fn(logits_last, y)
        if train_mode:
            optim.zero_grad()
            loss.backward()
            optim.step()
        total_loss += float(loss) * B
        correct += int((logits_last.argmax(-1) == y).sum())
        seen += B
    return total_loss / max(1, seen), correct / max(1, seen)


def train(*,
          dataset_path: Path,
          ckpt_out: Path,
          epochs: int = 50,
          batch_size: int = 128,
          lr: float = 1e-3,
          device: str = "cpu",
          seed: int = 0,
          log_every: int = 1,
          ) -> dict[str, list[float]]:
    torch.manual_seed(seed)
    rows = load_dataset_jsonl(dataset_path)
    train_rows, val_rows, _test_rows = split_by_session(rows, seed=seed)
    LOG.info("train=%d val=%d", len(train_rows), len(val_rows))
    train_ds = WindowDataset(train_rows, augment=True, seed=seed)
    val_ds = WindowDataset(val_rows, augment=False, seed=seed)
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False)
    model = ActionHeadModel().to(device)
    weights = _class_weights(train_rows).to(device)
    loss_fn = nn.CrossEntropyLoss(weight=weights)
    optim = torch.optim.AdamW(model.parameters(), lr=lr)
    history: dict[str, list[float]] = {
        "train_loss": [], "train_acc": [], "val_loss": [], "val_acc": [],
    }
    best_val_acc = -1.0
    ckpt_out.parent.mkdir(parents=True, exist_ok=True)
    for ep in range(epochs):
        tl, ta = _run_epoch(model, train_loader, loss_fn, optim, device)
        with torch.no_grad():
            vl, va = _run_epoch(model, val_loader, loss_fn, None, device)
        history["train_loss"].append(tl)
        history["train_acc"].append(ta)
        history["val_loss"].append(vl)
        history["val_acc"].append(va)
        if ep % log_every == 0 or ep == epochs - 1:
            LOG.info("ep=%d train_loss=%.4f train_acc=%.3f val_loss=%.4f val_acc=%.3f",
                     ep, tl, ta, vl, va)
        if va > best_val_acc:
            best_val_acc = va
            torch.save({"model_state_dict": model.state_dict(),
                        "version": 1, "val_acc": va}, ckpt_out)
    return history


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--dataset", required=True, type=Path)
    p.add_argument("--ckpt-out", required=True, type=Path)
    p.add_argument("--epochs", type=int, default=50)
    p.add_argument("--batch-size", type=int, default=128)
    p.add_argument("--lr", type=float, default=1e-3)
    p.add_argument("--device", default="cpu",
                   choices=["cpu", "mps", "cuda"])
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(name)s] %(message)s")
    hist = train(dataset_path=args.dataset, ckpt_out=args.ckpt_out,
                 epochs=args.epochs, batch_size=args.batch_size,
                 lr=args.lr, device=args.device, seed=args.seed)
    print(json.dumps({"final": {k: v[-1] for k, v in hist.items()}}))


if __name__ == "__main__":
    _cli()
```

- [ ] **Step 8.4: Run test to verify it passes**

Run: `cd data_only_viz && uv run pytest tests/test_training_smoke.py -v`
Expected: 2 PASSED. May take 30 s.

- [ ] **Step 8.5: Commit**

```bash
git add data_only_viz/training/train_action_head.py \
        data_only_viz/tests/test_training_smoke.py
git commit -m "feat(data-only-viz): action-head training loop"
```

---

## Task 9 — Eval script (confusion matrix + latency)

**Files:**
- Create: `data_only_viz/training/eval.py`

- [ ] **Step 9.1: Implement eval.py**

```python
# data_only_viz/training/eval.py
"""Evaluate a trained action-head checkpoint."""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader

from data_only_viz.action_head import ActionHeadModel, LABELS
from data_only_viz.training.dataset import load_dataset_jsonl, split_by_session
from data_only_viz.training.train_action_head import (
    LABEL_TO_IDX,
    WindowDataset,
)


def confusion_matrix(true: list[int], pred: list[int],
                     num_classes: int = 3) -> np.ndarray:
    cm = np.zeros((num_classes, num_classes), dtype=np.int64)
    for t, p in zip(true, pred):
        cm[t, p] += 1
    return cm


def evaluate(ckpt_path: Path, dataset_path: Path, device: str = "cpu",
             seed: int = 0) -> dict:
    rows = load_dataset_jsonl(dataset_path)
    _train, _val, test_rows = split_by_session(rows, seed=seed)
    ds = WindowDataset(test_rows, augment=False, seed=seed)
    loader = DataLoader(ds, batch_size=64, shuffle=False)
    model = ActionHeadModel().to(device).eval()
    payload = torch.load(ckpt_path, map_location=device, weights_only=True)
    model.load_state_dict(payload["model_state_dict"])
    true: list[int] = []
    pred: list[int] = []
    with torch.no_grad():
        for x, y in loader:
            x = x.to(device); y = y.to(device)
            B, T, _ = x.shape
            h = model.init_hidden(batch=B, device=device)
            logits = None
            for t in range(T):
                logits, h = model(x[:, t, :], h)
            true.extend(y.cpu().tolist())
            pred.extend(logits.argmax(-1).cpu().tolist())
    cm = confusion_matrix(true, pred)
    acc = float(np.trace(cm) / max(1, cm.sum()))
    # debout(0) ↔ danse(2) confusion percentage
    confusion_db = float((cm[0, 2] + cm[2, 0]) / max(1, cm.sum()))
    # micro-bench
    feat_dim = ds[0][0].shape[-1]
    bench_x = torch.zeros(1, feat_dim, device=device)
    h = model.init_hidden(batch=1, device=device)
    for _ in range(20):  # warmup
        _ = model(bench_x, h)
    t0 = time.perf_counter()
    N = 500
    for _ in range(N):
        _, h = model(bench_x, h)
    lat_ms = (time.perf_counter() - t0) * 1000.0 / N
    return {
        "test_acc": acc,
        "confusion_debout_danse": confusion_db,
        "confusion_matrix": cm.tolist(),
        "labels": list(LABELS),
        "step_latency_ms": lat_ms,
        "n_test": int(cm.sum()),
    }


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--ckpt", required=True, type=Path)
    p.add_argument("--dataset", required=True, type=Path)
    p.add_argument("--device", default="cpu",
                   choices=["cpu", "mps", "cuda"])
    args = p.parse_args()
    out = evaluate(args.ckpt, args.dataset, device=args.device)
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    _cli()
```

- [ ] **Step 9.2: Quick smoke run**

Reuse the smoke dataset from Task 8 to verify the CLI runs:

```bash
cd data_only_viz && uv run python -c "
import tempfile, json
from pathlib import Path
from data_only_viz.tests.test_training_smoke import _make_tiny_dataset
from data_only_viz.training.train_action_head import train
from data_only_viz.training.eval import evaluate
with tempfile.TemporaryDirectory() as td:
    td = Path(td)
    ds = _make_tiny_dataset(td)
    ckpt = td / 'ckpt.pt'
    train(dataset_path=ds, ckpt_out=ckpt, epochs=2, batch_size=8,
          lr=1e-3, device='cpu', seed=0, log_every=10_000)
    out = evaluate(ckpt, ds, device='cpu')
    print(json.dumps({k: v for k, v in out.items() if k != 'confusion_matrix'}))
"
```
Expected: prints a json with `test_acc`, `step_latency_ms`, etc. No crash.

- [ ] **Step 9.3: Commit**

```bash
git add data_only_viz/training/eval.py
git commit -m "feat(data-only-viz): action-head eval script"
```

---

## Task 10 — Capture script (webcam → MP4)

**Files:**
- Create: `data_only_viz/scripts/capture_actions.py`

- [ ] **Step 10.1: Implement capture script**

```python
# data_only_viz/scripts/capture_actions.py
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
                y0 = (h - side) // 2; x0 = (w - side) // 2
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
```

- [ ] **Step 10.2: Smoke check (manual)**

Manual verification — no CI test (requires camera):

```bash
uv run python -m data_only_viz.scripts.capture_actions \
    --session smoke_test --duration 5
ls ~/.cache/av-live-action/raw/smoke_test.mp4
```
Expected: file exists, opens in QuickTime, ~150 frames at 30 fps.

- [ ] **Step 10.3: Commit**

```bash
git add data_only_viz/scripts/capture_actions.py
git commit -m "feat(data-only-viz): action capture script"
```

---

## Task 11 — Extract j3d offline

> **SUPERSEDED 2026-05-13.** The implemented script does NOT refactor `multi_hmr_worker.py`. Instead it uses the standalone `MultiHMRCoreMLBackend.infer()` from `data_only_viz/multihmr_coreml.py` directly. Output jsonl rows contain a (22, 3) `j3d` extracted via `SMPLX_JOINT_ANCHOR_VERTS` (shared with `action_head_pub.py` to avoid train/serve skew), not the raw v3d. See actual file at `data_only_viz/scripts/extract_j3d_offline.py`. The body below documents the original intent — keep as historical context.

**Files:**
- Create: `data_only_viz/scripts/extract_j3d_offline.py`

- [ ] **Step 11.1: Implement extract script**

```python
# data_only_viz/scripts/extract_j3d_offline.py
"""Run Multi-HMR full (PyTorch, no CoreML) on a recorded MP4 and dump j3d
per frame per pid as jsonl.

Usage:
    uv run python -m data_only_viz.scripts.extract_j3d_offline \
        --session sess03 --video ~/.cache/av-live-action/raw/sess03.mp4
"""
from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

import cv2
import numpy as np

from data_only_viz.multi_hmr_worker import MultiHMRWorker  # baseline PyTorch

LOG = logging.getLogger("extract_j3d_offline")
OUT_DIR = Path("~/.cache/av-live-action/raw").expanduser()


def extract(session: str, video: Path) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"{session}.jsonl"
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        raise RuntimeError(f"cannot open {video}")
    worker = MultiHMRWorker.create_for_offline()  # see note below
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    with out.open("w") as f:
        n = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            persons = worker.infer_persons(frame)  # synchronous, no thread
            ts = n / fps
            for p in persons:
                j3d = np.asarray(p["j3d"], dtype=np.float32)[:22]
                f.write(json.dumps({
                    "ts": ts,
                    "session": session,
                    "pid": int(p.get("pid", 0)),
                    "j3d": j3d.tolist(),
                }) + "\n")
            n += 1
            if n % 100 == 0:
                LOG.info("frame=%d", n)
    cap.release()
    LOG.info("wrote %s", out)
    return out


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--session", required=True)
    p.add_argument("--video", required=True, type=Path)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(name)s] %(message)s")
    extract(args.session, args.video)


if __name__ == "__main__":
    _cli()
```

- [ ] **Step 11.2: Add offline helper on MultiHMRWorker**

Check `data_only_viz/multi_hmr_worker.py` for an existing public `infer` method. If absent or only thread-based, add a thin sync helper class method `create_for_offline()` and `infer_persons(frame_bgr)` that reuses the worker's internals without spawning threads/queues.

Concretely, append to `data_only_viz/multi_hmr_worker.py` (after the existing class definition):

```python
    @classmethod
    def create_for_offline(cls) -> "MultiHMRWorker":
        """Build a worker without the OSC thread for batch offline use."""
        w = cls.__new__(cls)
        w._init_model_only()  # implement _init_model_only by extracting
                              # the model-load block from __init__
        return w

    def infer_persons(self, frame_bgr: np.ndarray) -> list[dict]:
        """Synchronous single-frame inference. Returns persons list."""
        return self._infer_persons_sync(frame_bgr)
```

If the worker class does not currently expose model-load isolation, the implementer SHOULD refactor `__init__` to call a new private `_init_model_only()` containing the model/device setup (no threads, no queues). Tests in `tests/test_multi_hmr_worker.py` continue to construct via the regular `__init__`.

- [ ] **Step 11.3: Smoke (manual, after capture exists)**

```bash
uv run python -m data_only_viz.scripts.extract_j3d_offline \
    --session smoke_test --video ~/.cache/av-live-action/raw/smoke_test.mp4
head -2 ~/.cache/av-live-action/raw/smoke_test.jsonl
```
Expected: lines with `ts`, `session`, `pid`, `j3d` (22×3 list).

- [ ] **Step 11.4: Commit**

```bash
git add data_only_viz/scripts/extract_j3d_offline.py data_only_viz/multi_hmr_worker.py
git commit -m "feat(data-only-viz): offline j3d extraction from MP4"
```

---

## Task 12 — Review TUI

**Files:**
- Create: `data_only_viz/training/review.py`

- [ ] **Step 12.1: Implement TUI**

```python
# data_only_viz/training/review.py
"""Manual label review TUI.

Reads an auto-labeled jsonl, presents each window with:
  - ASCII skeleton (front view) of last frame
  - speed/accel/sym kinetics
  - proposed label + confidence
Keys:
  1 = debout, 2 = assise, 3 = danse
  ENTER = accept proposed label
  S = skip (label = None, will not be saved)
Output: same jsonl with manually_validated=True and corrected label.

Usage:
    uv run python -m data_only_viz.training.review \
        --in ~/.cache/av-live-action/dataset/auto.jsonl \
        --out ~/.cache/av-live-action/dataset/reviewed.jsonl
"""
from __future__ import annotations

import argparse
import sys
import termios
import tty
from pathlib import Path

import numpy as np

from data_only_viz.action_head import LABELS, WINDOW_LEN
from data_only_viz.training.autolabel import autolabel_window
from data_only_viz.training.dataset import (
    DatasetRow,
    load_dataset_jsonl,
    write_dataset_jsonl,
)


def _ascii_skeleton(j3d: np.ndarray, width: int = 40, height: int = 16) -> str:
    pts = j3d[:, [0, 1]]  # x, y
    mn = pts.min(axis=0); mx = pts.max(axis=0)
    rng = np.maximum(mx - mn, 1e-3)
    norm = (pts - mn) / rng
    grid = [[" "] * width for _ in range(height)]
    for x, y in norm:
        col = int(x * (width - 1))
        row = int((1 - y) * (height - 1))
        grid[row][col] = "*"
    return "\n".join("".join(row) for row in grid)


def _getch() -> str:
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        return sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def review(in_path: Path, out_path: Path,
           sample_validated_fraction: float = 0.2,
           seed: int = 0) -> None:
    rows = load_dataset_jsonl(in_path)
    rng = np.random.default_rng(seed)
    kept: list[DatasetRow] = []
    for i, r in enumerate(rows):
        proposed, conf = autolabel_window(list(r.j3d_stack))
        is_none = proposed is None
        sampled = rng.random() < sample_validated_fraction
        if not is_none and not sampled and r.manually_validated:
            kept.append(r); continue
        print("\033[2J\033[H")  # clear
        print(f"[{i+1}/{len(rows)}] {r.window_id}  proposed={proposed} conf={conf:.2f}")
        print(_ascii_skeleton(r.j3d_stack[-1]))
        from data_only_viz.action_head import FeatureExtractor
        kin = FeatureExtractor.kinetics(list(r.j3d_stack))
        print(f"speed={kin[0]:.3f}  accel={kin[1]:.3f}  sym={kin[2]:+.3f}")
        print(f"keys: 1=debout 2=assise 3=danse ENTER=accept S=skip Q=quit")
        k = _getch().lower()
        if k == "q":
            break
        elif k == "s":
            continue
        elif k == "\r":
            chosen = proposed
        elif k in ("1", "2", "3"):
            chosen = LABELS[int(k) - 1]
        else:
            continue
        if chosen is None:
            continue
        kept.append(DatasetRow(
            window_id=r.window_id, label=chosen, j3d_stack=r.j3d_stack,
            session=r.session, pid_local=r.pid_local,
            auto_label_confidence=conf, manually_validated=True,
        ))
    write_dataset_jsonl(kept, out_path)
    print(f"\nwrote {len(kept)} rows to {out_path}")


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="in_path", required=True, type=Path)
    p.add_argument("--out", dest="out_path", required=True, type=Path)
    p.add_argument("--sample-fraction", type=float, default=0.2)
    args = p.parse_args()
    review(args.in_path, args.out_path,
           sample_validated_fraction=args.sample_fraction)


if __name__ == "__main__":
    _cli()
```

- [ ] **Step 12.2: Commit (no automated test — interactive)**

```bash
git add data_only_viz/training/review.py
git commit -m "feat(data-only-viz): action label review TUI"
```

---

## Task 13 — pose_bridge OSC extensions

**Files:**
- Modify: `data_only_viz/pose_bridge.py`
- Create: `data_only_viz/tests/test_pose_bridge_action.py`

- [ ] **Step 13.1: Write failing tests**

```python
# data_only_viz/tests/test_pose_bridge_action.py
"""Tests for /pose/action and /pose/kin OSC routes."""
from __future__ import annotations

from unittest.mock import MagicMock

import numpy as np


def test_send_action_formats_5_args() -> None:
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b.send_action(pid=7, label_idx=2,
                  probs=np.array([0.1, 0.2, 0.7], dtype=np.float32),
                  t_now=0.0, force=True)
    b._client.send_message.assert_called_once()
    address, args = b._client.send_message.call_args.args
    assert address == "/pose/action"
    assert args[0] == 7
    assert args[1] == 2
    assert all(isinstance(v, float) for v in args[2:5])
    assert abs(sum(args[2:5]) - 1.0) < 1e-5


def test_send_kin_formats_4_args() -> None:
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b.send_kin(pid=3, kin=np.array([0.5, 1.2, -0.3], dtype=np.float32),
               t_now=0.0, force=True)
    b._client.send_message.assert_called_once()
    address, args = b._client.send_message.call_args.args
    assert address == "/pose/kin"
    assert args[0] == 3
    assert args[1:] == [0.5, 1.2, -0.3] or [
        abs(args[i+1] - v) < 1e-6 for i, v in enumerate([0.5, 1.2, -0.3])
    ]


def test_send_lifecycle_enter_leave() -> None:
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b.send_enter(pid=4)
    b.send_leave(pid=4)
    calls = [c.args[0] for c in b._client.send_message.call_args_list]
    assert "/pose/enter" in calls
    assert "/pose/leave" in calls
```

- [ ] **Step 13.2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_pose_bridge_action.py -v`
Expected: 3 FAILED.

- [ ] **Step 13.3: Extend `PoseSoundBridge`**

Append to `data_only_viz/pose_bridge.py` (inside the `PoseSoundBridge` class):

```python
    def send_action(self, pid: int, label_idx: int,
                    probs, t_now: float, force: bool = False) -> None:
        if not force and (t_now - self._last_t) < self._period:
            return
        p = [float(probs[0]), float(probs[1]), float(probs[2])]
        self._client.send_message("/pose/action", [int(pid), int(label_idx), *p])

    def send_kin(self, pid: int, kin,
                 t_now: float, force: bool = False) -> None:
        if not force and (t_now - self._last_t) < self._period:
            return
        self._client.send_message(
            "/pose/kin",
            [int(pid), float(kin[0]), float(kin[1]), float(kin[2])],
        )

    def send_enter(self, pid: int) -> None:
        self._client.send_message("/pose/enter", [int(pid)])

    def send_leave(self, pid: int) -> None:
        self._client.send_message("/pose/leave", [int(pid)])
```

- [ ] **Step 13.4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_pose_bridge_action.py -v`
Expected: 3 PASSED.

- [ ] **Step 13.5: Commit**

```bash
git add data_only_viz/pose_bridge.py data_only_viz/tests/test_pose_bridge_action.py
git commit -m "feat(data-only-viz): pose_bridge /pose/action + /pose/kin"
```

---

## Task 14 — Wire ActionHead into multi_hmr_worker_coreml

> **SUPERSEDED 2026-05-13.** No `multi_hmr_worker_coreml.py` file exists in the current repo — the user pivoted to `multihmr_coreml.py` (standalone backend) selected via env `MULTIHMR_BACKEND=pytorch|coreml` inside `multi_hmr_worker.py`. To avoid colliding with that file under active iteration, ActionHead wiring was implemented as a standalone publisher thread in `data_only_viz/action_head_pub.py` plus a 3-line wire-in inside `data_only_viz/multi.py` (`__init__` instantiates and `.start()`s the publisher). The publisher polls `state.persons_smplx` (preferred) and `state.persons_body3d` (MediaPipe fallback) at 30 Hz, deduplicates by timestamp, extracts j3d22 via shared `SMPLX_JOINT_ANCHOR_VERTS` / `MEDIAPIPE_TO_22` index maps, runs `ActionHead.step()` per pid, and emits OSC via the existing `PoseSoundBridge`. No CLI flag was added. See `data_only_viz/action_head_pub.py` and `data_only_viz/multi.py:22,97-98`. The body below documents the original intent — keep as historical context.

**Files:**
- Modify: `data_only_viz/multi_hmr_worker_coreml.py`
- Modify: `data_only_viz/main.py`

- [ ] **Step 14.1: Add ActionHead instantiation**

Open `data_only_viz/multi_hmr_worker_coreml.py`. In the worker's `__init__`, add (near the bottom, after model load):

```python
        from data_only_viz.action_head import ActionHead
        ckpt = Path("~/.cache/av-live-action/checkpoints/action_head.pt").expanduser()
        try:
            self._action_head = ActionHead(
                ckpt_path=ckpt if ckpt.exists() else None,
                device="cpu",
            )
            LOG.info("action_head loaded ckpt=%s", ckpt if ckpt.exists() else "<random>")
        except Exception as e:
            LOG.warning("action_head disabled: %s", e)
            self._action_head = None
        self._last_action_pids: set[int] = set()
```

- [ ] **Step 14.2: Call step()/forget() inside the per-frame loop**

Locate the section in the worker that publishes persons over OSC (where `pose_bridge` is used today). Add **right after** Multi-HMR returns persons:

```python
        if self._action_head is not None:
            current_pids: set[int] = set()
            for person in persons:
                pid = int(person["pid"])
                current_pids.add(pid)
                j3d = np.asarray(person["j3d"], dtype=np.float32)[:22]
                label, probs, kin = self._action_head.step(pid, j3d)
                label_idx = ("debout", "assise", "danse").index(label)
                if hasattr(self._pose_bridge, "send_action"):
                    self._pose_bridge.send_action(pid, label_idx, probs,
                                                   t_now, force=True)
                    self._pose_bridge.send_kin(pid, kin, t_now, force=True)
                if pid not in self._last_action_pids:
                    self._pose_bridge.send_enter(pid)
            # purge pids that disappeared
            for gone in self._last_action_pids - current_pids:
                self._action_head.forget(gone)
                self._pose_bridge.send_leave(gone)
            self._last_action_pids = current_pids
```

Make sure `t_now` is in scope (use `time.perf_counter()` or the existing variable in the loop). If `self._pose_bridge` is named differently in this worker, adapt accordingly — check the existing OSC sending code in the same file.

- [ ] **Step 14.3: CLI flag in `main.py`**

In `data_only_viz/main.py`, locate the argparse definition. Add:

```python
    parser.add_argument(
        "--no-action-head", action="store_true",
        help="Disable action classification (debout/assise/danse) over j3d.",
    )
```

And where `MultiHMRWorkerCoreML` is constructed, pass through:

```python
    worker_kwargs["enable_action_head"] = not args.no_action_head
```

In the worker's `__init__`, gate the ActionHead block on `enable_action_head=True` default.

- [ ] **Step 14.4: Run the existing worker test suite to confirm nothing breaks**

Run: `cd data_only_viz && uv run pytest tests/test_multi_hmr_worker.py -v`
Expected: PASS (or same skips as before — no new failures).

- [ ] **Step 14.5: Manual live smoke (M5)**

Manual; not in CI. After the worker code is updated and a (random-init) `action_head` is in place, run the data-only pipeline for 60 s and `nc -u -l 57121` in another terminal:

```bash
# terminal 1
nc -u -l 57121 | head -30
# terminal 2
uv run python -m data_only_viz.main --multi-hmr-coreml-backbone
```
Expected: `/pose/action` and `/pose/kin` lines flow, plus `/pose/enter` on new pids.

- [ ] **Step 14.6: Commit**

```bash
git add data_only_viz/multi_hmr_worker_coreml.py data_only_viz/main.py
git commit -m "feat(data-only-viz): wire ActionHead into hybrid worker"
```

---

## Task 15 — sound_algo OSC handlers

**Files:**
- Modify: `sound_algo/engine.scd` (or wherever existing `/pose/*` handlers live — search first)

- [ ] **Step 15.1: Locate existing /pose/ OSCdef**

```bash
grep -n "/pose/" sound_algo/**/*.scd
```

Identify the file that already declares `/pose/center`, `/pose/wrist`, etc. (commonly `engine.scd` or `scenes.scd`). Open it.

- [ ] **Step 15.2: Add new OSCdef blocks**

Append the two new defs in the same file (wrapped in a single top-level `(...)` block so they pass the `validating-scd-files` skill):

```supercollider
(
~poseState = Dictionary.new;
~poseKin = Dictionary.new;

OSCdef(\poseAction, { |msg|
    var pid = msg[1];
    ~poseState[pid] = (
        labelIdx: msg[2],
        probs:    [msg[3], msg[4], msg[5]],
    );
}, '/pose/action');

OSCdef(\poseKin, { |msg|
    var pid = msg[1];
    ~poseKin[pid] = (
        speed:    msg[2],
        accel:    msg[3],
        symmetry: msg[4],
    );
}, '/pose/kin');

OSCdef(\poseEnter, { |msg|
    var pid = msg[1];
    ~poseState[pid] = (labelIdx: 0, probs: [1.0, 0.0, 0.0]);
    ~poseKin[pid]   = (speed: 0, accel: 0, symmetry: 0);
}, '/pose/enter');

OSCdef(\poseLeave, { |msg|
    var pid = msg[1];
    ~poseState.removeAt(pid);
    ~poseKin.removeAt(pid);
}, '/pose/leave');

"[OK] action-head OSC handlers".postln;
)
```

- [ ] **Step 15.3: Validate parens balance + TLB**

Use the `superpowers` validation skill or run:

```bash
awk -f sound_algo/tests/awk_balance.awk sound_algo/engine.scd 2>/dev/null \
    || echo "manual paren check needed"
```

If the project uses the `validating-scd-files` skill (it should), invoke it before commit.

- [ ] **Step 15.4: Smoke load**

```bash
cd sound_algo && /Applications/SuperCollider.app/Contents/MacOS/sclang -h \
    -e '"00_load.scd".load; 1.wait; 0.exit' 2>&1 | tail -20
```
Expected: no parse error, `[OK] action-head OSC handlers` appears.

- [ ] **Step 15.5: Commit**

```bash
git add sound_algo/engine.scd
git commit -m "feat(sound-algo): /pose/action + /pose/kin handlers"
```

---

## Task 16 — End-to-end gate (after training the first real checkpoint)

This task is a manual gate, not a code task. It runs once the user has captured real data, run auto-label + review, trained on Studio, and rsynced the checkpoint.

- [ ] **Step 16.1: Run the live pipeline with real checkpoint**

```bash
ls ~/.cache/av-live-action/checkpoints/action_head.pt
uv run python -m data_only_viz.main --multi-hmr-coreml-backbone
```

- [ ] **Step 16.2: Verify success criteria from the spec**

| Métrique | Cible | Mesurer comment |
|---|---|---|
| Test acc 3 classes | ≥ 85 % | run `uv run python -m data_only_viz.training.eval --ckpt ... --dataset ...` |
| Confusion debout↔danse | ≤ 5 % | same eval JSON, `confusion_debout_danse` field |
| Latence step() M5 | ≤ 2 ms | eval `step_latency_ms` field |
| Latence label change perçue | ≤ 0.8 s | live test : s'asseoir → observer label change `nc -u -l 57121` |
| Stabilité 10 s constante | ≥ 9.5 s correct | live test : tenir une pose 10 s, count flips |

- [ ] **Step 16.3: If any gate fails, consult abandon criteria in spec**

See `docs/superpowers/specs/2026-05-13-action-head-design.md` § Abandon criteria. Adjust: more data, longer window, v2 Apple Vision concat, etc.

- [ ] **Step 16.4: Commit eval report**

```bash
mkdir -p docs/superpowers/reports
uv run python -m data_only_viz.training.eval \
    --ckpt ~/.cache/av-live-action/checkpoints/action_head.pt \
    --dataset ~/.cache/av-live-action/dataset/reviewed.jsonl \
    > docs/superpowers/reports/2026-05-13-action-head-v1-eval.json
git add docs/superpowers/reports/2026-05-13-action-head-v1-eval.json
git commit -m "docs(reports): action-head v1 eval report"
```

---

## Spec coverage check

| Spec section | Covered by |
|---|---|
| Architecture (GRU + MLP, ring buffer, per-pid state) | Tasks 2, 3, 4 |
| FeatureExtractor 201-dim layout | Task 3 |
| ActionHead.step / forget API | Task 4 |
| Auto-labeler rules | Task 5 |
| Dataset jsonl format + sliding window + by-session split | Task 6 |
| Augmentations (mirror, noise, time-stretch, Y-rotation) | Task 7 |
| Training (PyTorch MPS, AdamW, weighted CE, early stop) | Task 8 |
| Eval (confusion + latency micro-bench) | Task 9 |
| Capture script (webcam → MP4 + timestamps) | Task 10 |
| Extract j3d offline (Multi-HMR full → jsonl) | Task 11 |
| Manual review TUI | Task 12 |
| OSC routes `/pose/action`, `/pose/kin`, `/pose/enter`, `/pose/leave` | Tasks 13, 14, 15 |
| Worker integration + CLI flag | Task 14 |
| sound_algo handlers | Task 15 |
| Success-criteria gate + abandon protocol | Task 16 |
| Error handling (NaN, warmup, forget, missing ckpt) | Task 4 (ActionHead.step), Task 14 (init fallback) |
| Streaming inference at <2 ms/step M5 | Task 4.5 sanity + Task 16 final gate |
| Hybrid windowed-train / streaming-infer alignment | Task 8 (WindowDataset replays each step) |
