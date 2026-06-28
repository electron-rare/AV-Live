# Air-Piano (iPhone fingers into SuperCollider) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the performer play notes "like a piano" in the air — each finger
strikes a scale degree, hand position shifts octave, hand spacing modulates
global params — by bringing per-finger iPhone hand data into SuperCollider.

**Architecture:** Hybrid. Python (`data_only_viz`) detects finger strikes from
the raw 21-joint hand data it already holds and emits a discrete OSC
`/pose/finger` event per strike on the existing `:57121` channel. SuperCollider
(`sound_algo`) owns all musicality (scale, finger→degree, octave, instrument,
velocity) and continuous modulation read from the `/pose/hands` data already in
`~handFeat`.

**Tech Stack:** Python 3.11+ via `uv`, `python-osc` (`SimpleUDPClient`), numpy,
pytest. SuperCollider (sclang) `OSCdef`, `Synth`, `Bus.control`.

## Global Constraints

- Python: use `uv` for everything (never pip/poetry/conda directly).
- Python tests live in `data_only_viz/tests/`, run with
  `cd data_only_viz && uv run pytest tests/ -v`.
- Mutate `state.*` only under `with state.lock():`.
- Guard every optional ML/import with `try/except ImportError` (n/a here, no new
  heavy deps).
- SC env vars are lowercase `~xxx` (uppercase parses as CLASSNAME).
- `.load`-compatible `.scd` files MUST have exactly ONE top-level `(...)` block
  and pass the parens/brackets balance check (P:0 B:0). Use the
  `validating-scd-files` skill after each `.scd` edit.
- Commits: subject ≤ 50 chars, body ≤ 72 chars/line, no AI attribution, no
  `--no-verify`, no underscore in the commit scope.
- No emojis in code/docs/commits.
- Comments: French in `sound_algo/*.scd` (project convention), English
  elsewhere.

---

### Task 1: Python — `FingerStrikeDetector`

Pure signal logic: detect per-finger downward strikes from raw hand joints,
isolating finger flexion from whole-hand motion by measuring the fingertip
relative to its base knuckle. No I/O, fully unit-testable.

**Files:**
- Create: `data_only_viz/finger_strike.py`
- Test: `data_only_viz/tests/test_finger_strike.py`

**Interfaces:**
- Consumes: a `hands` list shaped like `state.persons_hands` — a list of hands,
  each hand a sequence of ≥21 landmarks where each landmark is indexable
  (`lm[0]=x, lm[1]=y, lm[2]=z`) or has `.x/.y/.z`. Reuses `_coord`, `_finite`,
  `_clamp` from `data_only_viz/hand_features.py`.
- Produces:
  - `class StrikeEvent` (dataclass) with fields
    `hand:int, finger:int, strike_speed:float, z:float, tipx:float, tipy:float`.
  - `class FingerStrikeDetector` with
    `__init__(self, vel_thresh=0.02, refractory_ms=120.0, speed_scale=0.10, history_slots=2)`
    and `step(self, hands:list, t_now:float) -> list[StrikeEvent]`.
  - Module constants `FINGERTIPS=(4,8,12,16,20)` and `FINGER_BASES=(2,5,9,13,17)`.

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_finger_strike.py`:

```python
"""Tests for FingerStrikeDetector (air-piano strike detection)."""
from __future__ import annotations

from data_only_viz.finger_strike import (
    FingerStrikeDetector,
    StrikeEvent,
    FINGERTIPS,
    FINGER_BASES,
)


def _hand(tip_y_by_finger: dict[int, float], base_y: float = 0.4,
          cx: float = 0.3) -> list[list[float]]:
    """Build a 21-landmark hand. Every base knuckle sits at base_y; each
    fingertip sits at base_y unless overridden in tip_y_by_finger (keyed by
    finger 0..4). x is set near cx so L/R slotting is deterministic."""
    lm = [[cx, base_y, 0.0] for _ in range(21)]
    for f, base_idx in enumerate(FINGER_BASES):
        lm[base_idx] = [cx, base_y, 0.0]
    for f, tip_idx in enumerate(FINGERTIPS):
        ty = tip_y_by_finger.get(f, base_y)
        lm[tip_idx] = [cx, ty, 0.0]
    return lm


def test_downward_spike_fires_exactly_one_strike():
    det = FingerStrikeDetector(vel_thresh=0.02, refractory_ms=120.0)
    # frame 0: neutral (primes prev), index tip level with base
    det.step([_hand({1: 0.40})], t_now=0.00)
    # frame 1: index tip drops 0.06 below -> downward velocity 0.06 > thresh
    e1 = det.step([_hand({1: 0.46})], t_now=0.04)
    # frame 2: tip stays down -> velocity ~0, must NOT refire
    e2 = det.step([_hand({1: 0.46})], t_now=0.08)
    strikes = e1 + e2
    assert len(strikes) == 1
    assert strikes[0].finger == 1
    assert strikes[0].hand == 0
    assert strikes[0].strike_speed > 0.0


def test_whole_hand_translation_does_not_fire():
    det = FingerStrikeDetector(vel_thresh=0.02)
    out = []
    # tip and base move down together each frame -> relative y constant
    for i, by in enumerate((0.40, 0.50, 0.60, 0.70)):
        out += det.step([_hand({1: by}, base_y=by)], t_now=i * 0.04)
    assert out == []


def test_refractory_blocks_second_strike():
    det = FingerStrikeDetector(vel_thresh=0.02, refractory_ms=120.0)
    det.step([_hand({1: 0.40})], t_now=0.00)          # prime
    a = det.step([_hand({1: 0.46})], t_now=0.02)      # strike 1
    det.step([_hand({1: 0.40})], t_now=0.04)          # lift -> rearm
    b = det.step([_hand({1: 0.46})], t_now=0.06)      # within 120 ms -> blocked
    assert len(a) == 1
    assert b == []


def test_strike_speed_scales_with_velocity():
    soft = FingerStrikeDetector(vel_thresh=0.02, speed_scale=0.10)
    hard = FingerStrikeDetector(vel_thresh=0.02, speed_scale=0.10)
    soft.step([_hand({1: 0.40})], t_now=0.0)
    hard.step([_hand({1: 0.40})], t_now=0.0)
    s = soft.step([_hand({1: 0.44})], t_now=0.04)   # delta 0.04
    h = hard.step([_hand({1: 0.50})], t_now=0.04)   # delta 0.10
    assert h[0].strike_speed > s[0].strike_speed
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_finger_strike.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'data_only_viz.finger_strike'`

- [ ] **Step 3: Write minimal implementation**

Create `data_only_viz/finger_strike.py`:

```python
"""Air-piano finger strike detection from raw MediaPipe hand joints.

Mirrors hand_features.py conventions (L/R slotting by cx, finite-guarded
coordinate extraction). A "strike" is a fast downward motion of a fingertip
RELATIVE to its base knuckle, so translating the whole hand does not fire all
fingers. Output feeds the OSC /pose/finger route consumed by SuperCollider.
"""
from __future__ import annotations

from dataclasses import dataclass

from data_only_viz.hand_features import _clamp, _coord, _finite

# MediaPipe 21-kp hand: fingertip and base-knuckle indices per finger
# (thumb, index, middle, ring, pinky). Thumb base = ThumbMP (2).
FINGERTIPS: tuple[int, ...] = (4, 8, 12, 16, 20)
FINGER_BASES: tuple[int, ...] = (2, 5, 9, 13, 17)


@dataclass
class StrikeEvent:
    hand: int          # 0 = left slot (leftmost cx), 1 = right slot
    finger: int        # 0..4 = thumb, index, middle, ring, pinky
    strike_speed: float
    z: float
    tipx: float
    tipy: float


class _FingerState:
    __slots__ = ("prev_rel", "armed", "last_t")

    def __init__(self) -> None:
        self.prev_rel: float | None = None
        self.armed: bool = True
        self.last_t: float = -1e9


class FingerStrikeDetector:
    def __init__(self, vel_thresh: float = 0.02, refractory_ms: float = 120.0,
                 speed_scale: float = 0.10, history_slots: int = 2) -> None:
        self.vel_thresh = vel_thresh
        self.refractory_s = refractory_ms / 1000.0
        self.speed_scale = max(1e-6, speed_scale)
        # state[slot][finger]
        self._state = [[_FingerState() for _ in range(5)]
                       for _ in range(history_slots)]

    def _slot_hands(self, hands: list) -> list:
        """Validate and order hands leftmost-first (slot 0 = L), like
        HandFeatureExtractor. Returns up to 2 (cx, landmarks) ordered."""
        cand = []
        for lm in hands:
            try:
                if lm is None or len(lm) < 21:
                    continue
            except TypeError:
                continue
            xs = [_finite(_coord(p, "x", 0), 0.5) for p in lm[:21]]
            cx = _clamp(sum(xs) / len(xs), 0.0, 1.0)
            cand.append((cx, lm))
        cand.sort(key=lambda c: c[0])
        return cand[:len(self._state)]

    def step(self, hands: list, t_now: float) -> list[StrikeEvent]:
        ordered = self._slot_hands(hands)
        present = set(range(len(ordered)))
        events: list[StrikeEvent] = []
        for slot, (_cx, lm) in enumerate(ordered):
            for f in range(5):
                tip = lm[FINGERTIPS[f]]
                base = lm[FINGER_BASES[f]]
                tip_y = _finite(_coord(tip, "y", 1), 0.5)
                base_y = _finite(_coord(base, "y", 1), 0.5)
                rel = tip_y - base_y          # +down (image y grows downward)
                st = self._state[slot][f]
                if st.prev_rel is None:
                    st.prev_rel = rel
                    continue
                vel = rel - st.prev_rel       # +down velocity per frame
                st.prev_rel = rel
                if vel < 0.0:                 # lifting -> rearm
                    st.armed = True
                if (vel > self.vel_thresh and st.armed
                        and (t_now - st.last_t) >= self.refractory_s):
                    st.armed = False
                    st.last_t = t_now
                    events.append(StrikeEvent(
                        hand=slot, finger=f,
                        strike_speed=_clamp(vel / self.speed_scale, 0.0, 1.0),
                        z=_finite(_coord(tip, "z", 2, 0.0), 0.0),
                        tipx=_finite(_coord(tip, "x", 0), 0.5),
                        tipy=tip_y,
                    ))
        # reset slots not present this tick so re-entry does not spike
        for slot in range(len(self._state)):
            if slot not in present:
                for f in range(5):
                    self._state[slot][f].prev_rel = None
                    self._state[slot][f].armed = True
        return events
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd data_only_viz && uv run pytest tests/test_finger_strike.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/finger_strike.py data_only_viz/tests/test_finger_strike.py
git commit -m "feat: add finger strike detector"
```

---

### Task 2: Python — `PoseSoundBridge.send_finger()`

Add the OSC emitter for the new `/pose/finger` event, mirroring `send_hands`.

**Files:**
- Modify: `data_only_viz/pose_bridge.py` (class `PoseSoundBridge`, after
  `send_hands`)
- Test: `data_only_viz/tests/test_pose_bridge_finger.py`

**Interfaces:**
- Consumes: nothing new (uses the existing `self._client` SimpleUDPClient bound
  to `127.0.0.1:57121` from `PoseSoundBridge.__init__`).
- Produces: `PoseSoundBridge.send_finger(self, ev) -> None` where `ev` is a
  `StrikeEvent` (duck-typed: needs `.hand .finger .strike_speed .z .tipx
  .tipy`). Emits OSC `/pose/finger` with args
  `[pid=0, hand, finger, strike_speed, z, tipx, tipy]` (ints for pid/hand/finger,
  floats for the rest). Strike events are NOT throttled (they are already
  rate-limited by the detector's refractory window).

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_pose_bridge_finger.py`:

```python
"""Tests for PoseSoundBridge.send_finger."""
from __future__ import annotations

from unittest.mock import MagicMock

from data_only_viz.finger_strike import StrikeEvent
from data_only_viz.pose_bridge import PoseSoundBridge


def _bridge() -> PoseSoundBridge:
    b = PoseSoundBridge()
    b._client = MagicMock()      # stub the UDP client
    return b


def test_send_finger_emits_expected_osc():
    b = _bridge()
    ev = StrikeEvent(hand=1, finger=2, strike_speed=0.5, z=0.1,
                     tipx=0.7, tipy=0.6)
    b.send_finger(ev)
    b._client.send_message.assert_called_once()
    addr, args = b._client.send_message.call_args[0]
    assert addr == "/pose/finger"
    assert args[0] == 0           # pid
    assert args[1] == 1           # hand
    assert args[2] == 2           # finger
    assert abs(args[3] - 0.5) < 1e-6
    assert len(args) == 7
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_pose_bridge_finger.py -v`
Expected: FAIL with `AttributeError: 'PoseSoundBridge' object has no attribute 'send_finger'`

- [ ] **Step 3: Write minimal implementation**

In `data_only_viz/pose_bridge.py`, add this method to `PoseSoundBridge`
immediately after the `send_hands` method (search for `def send_hands`):

```python
    def send_finger(self, ev) -> None:
        """Emit one air-piano strike event. Not throttled: the detector's
        refractory window already rate-limits these."""
        args = [
            0,                          # pid (single performer)
            int(ev.hand),
            int(ev.finger),
            float(ev.strike_speed),
            float(ev.z),
            float(ev.tipx),
            float(ev.tipy),
        ]
        try:
            self._client.send_message("/pose/finger", args)
        except OSError:
            pass
        self._vj("/pose/finger", args)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd data_only_viz && uv run pytest tests/test_pose_bridge_finger.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/pose_bridge.py data_only_viz/tests/test_pose_bridge_finger.py
git commit -m "feat: emit /pose/finger over osc bridge"
```

---

### Task 3: Python — wire strike emission into `ActionHeadPublisher`

Run the detector each tick on `state.persons_hands` (under lock), gated by
`FINGER_PIANO`, and emit each strike. Thresholds come from env vars.

**Files:**
- Modify: `data_only_viz/action_head_pub.py`
  (`ActionHeadPublisher.__init__` and `_tick`; add `_emit_fingers`)
- Test: `data_only_viz/tests/test_action_head_finger_emit.py`

**Interfaces:**
- Consumes: `FingerStrikeDetector.step` (Task 1), `PoseSoundBridge.send_finger`
  (Task 2), `state.persons_hands` (existing), `state.lock()` (existing).
- Produces: `ActionHeadPublisher._emit_fingers(self, t_now: float) -> None`,
  called from `_tick` after `_emit_hands`. No-op when `FINGER_PIANO` env is unset
  or `"0"`. Reads env once in `__init__`:
  `FINGER_PIANO` (enable), `FINGER_STRIKE_VEL` (float, default 0.02),
  `FINGER_STRIKE_REFRACTORY_MS` (float, default 120).

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_action_head_finger_emit.py`:

```python
"""ActionHeadPublisher emits /pose/finger when FINGER_PIANO is enabled."""
from __future__ import annotations

import threading
from unittest.mock import MagicMock

from data_only_viz.finger_strike import FINGERTIPS, FINGER_BASES


class _FakeState:
    def __init__(self) -> None:
        self.persons_hands = []
        self._lock = threading.RLock()

    def lock(self):
        return self._lock


def _hand(index_tip_y: float, base_y: float = 0.4):
    lm = [[0.3, base_y, 0.0] for _ in range(21)]
    lm[FINGERTIPS[1]] = [0.3, index_tip_y, 0.0]
    lm[FINGER_BASES[1]] = [0.3, base_y, 0.0]
    return lm


def _pub(monkeypatch, enabled: bool):
    monkeypatch.setenv("FINGER_PIANO", "1" if enabled else "0")
    monkeypatch.setenv("FINGER_STRIKE_VEL", "0.02")
    monkeypatch.setenv("FINGER_STRIKE_REFRACTORY_MS", "120")
    from data_only_viz.action_head_pub import ActionHeadPublisher
    # bypass __init__ heavy ckpt load: construct then set only what we touch
    pub = ActionHeadPublisher.__new__(ActionHeadPublisher)
    pub.state = _FakeState()
    pub.bridge = MagicMock()
    pub._init_finger_piano()       # helper that reads env + builds detector
    return pub


def test_emit_fingers_fires_when_enabled(monkeypatch):
    pub = _pub(monkeypatch, enabled=True)
    pub.state.persons_hands = [_hand(0.40)]
    pub._emit_fingers(0.00)                 # prime
    pub.state.persons_hands = [_hand(0.46)] # downward strike
    pub._emit_fingers(0.04)
    assert pub.bridge.send_finger.called


def test_emit_fingers_noop_when_disabled(monkeypatch):
    pub = _pub(monkeypatch, enabled=False)
    pub.state.persons_hands = [_hand(0.40)]
    pub._emit_fingers(0.00)
    pub.state.persons_hands = [_hand(0.46)]
    pub._emit_fingers(0.04)
    assert not pub.bridge.send_finger.called
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_finger_emit.py -v`
Expected: FAIL with `AttributeError: ... has no attribute '_init_finger_piano'`

- [ ] **Step 3: Write minimal implementation**

In `data_only_viz/action_head_pub.py`:

(3a) Add the import near the top of `__init__`'s body sibling imports — at the
end of `__init__` (after `self._hand_ext = HandFeatureExtractor()`, line ~102),
add:

```python
        self._init_finger_piano()
```

(3b) Add these two methods to `ActionHeadPublisher` (place after `_emit_hands`):

```python
    def _init_finger_piano(self) -> None:
        """Read FINGER_PIANO env config and build the strike detector."""
        import os
        from data_only_viz.finger_strike import FingerStrikeDetector
        self._finger_enabled = os.environ.get("FINGER_PIANO", "0") not in (
            "0", "", "false", "False",
        )
        vel = float(os.environ.get("FINGER_STRIKE_VEL", "0.02"))
        refr = float(os.environ.get("FINGER_STRIKE_REFRACTORY_MS", "120"))
        self._finger_det = FingerStrikeDetector(
            vel_thresh=vel, refractory_ms=refr,
        )

    def _emit_fingers(self, t_now: float) -> None:
        """Detect finger strikes on persons_hands and emit /pose/finger."""
        if not getattr(self, "_finger_enabled", False):
            return
        with self.state.lock():
            hands = list(getattr(self.state, "persons_hands", None) or [])
        for ev in self._finger_det.step(hands, t_now):
            self.bridge.send_finger(ev)
```

(3c) In `_tick`, after the existing `self._emit_hands(t_now)` line (line ~147),
add:

```python
        self._emit_fingers(t_now)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_finger_emit.py tests/test_action_head_pub.py -v`
Expected: PASS (existing action-head pub tests stay green; 2 new tests pass)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/action_head_pub.py data_only_viz/tests/test_action_head_finger_emit.py
git commit -m "feat: wire finger strikes into pose publisher"
```

---

### Task 4: SC — `finger_piano.scd` (resolve + OSCdef + `~fp` API + modulation)

The air-piano brain in SuperCollider. A single top-level `(...)` block,
`.load`-compatible. Note resolution is factored into the pure function
`~fpResolve` so it can be unit-tested without a running server.

**Files:**
- Create: `sound_algo/control/finger_piano.scd`
- Test: `sound_algo/tests/test_finger_piano.scd`

**Interfaces:**
- Consumes: `~handFeat` dict (from `data_feeds.scd`: `\lx \ly \rx \ry \dist`),
  `~melodyInst` (current live instrument symbol), `palette/scales.scd` scale
  arrays (`~scaleMinorPent`, `~scaleDorian`, ...). MIDI→Hz via `.midicps`.
- Produces (env vars / functions):
  - `~fpEnabled` (Boolean), `~fpInst` (Symbol or `\live`), `~fpScaleArr`
    (Array of MIDI notes), `~fpMap` (`[[5 L degrees],[5 R degrees]]`),
    `~fpHandOct` (`[Lsemi, Rsemi]`), `~fpBaseOct` (Integer octaves),
    `~fpOctSpan` (Float octaves of hand-x transpose), `~fpSens` (Float),
    `~fpVelSource` (`\strike`|`\z`), `~fpHold` (Float seconds), `~fpAmp` (Float).
  - `~fpResolve.(hand, finger, strikeSpeed, z, tipx, tipy)` →
    `Event` with `\note` (Integer MIDI), `\freq` (Float Hz), `\amp` (Float),
    `\inst` (Symbol). Pure; reads `~handFeat`/state but triggers nothing.
  - `~fpResolveInst.()` → Symbol (the `\live` sentinel resolves to
    `~melodyInst ? \pluck`).
  - `~fpModTick.()` → updates `~fpCut` and `~fpFx` (Floats, one-pole smoothed)
    from `~handFeat[\dist]` and mean hand Y; writes to control buses
    `~fpCutBus`/`~fpFxBus` when the server is running.
  - Live wrappers: `~fpOn`, `~fpOff`, `~fpInst_`, `~fpScale_`, `~fpSens_`,
    `~fpOctave_`, `~fpVelSource_`.
  - `OSCdef(\poseFinger)` on `/pose/finger` calling `~fpResolve` then triggering
    `Synth`.

- [ ] **Step 1: Write the failing test**

Create `sound_algo/tests/test_finger_piano.scd`:

```supercollider
// Headless unit test for finger_piano note resolution.
// Run: sclang sound_algo/tests/test_finger_piano.scd
(
var base, ok = true, ev;
base = thisProcess.nowExecutingPath.dirname.dirname ++ "/";
// minimal deps: scales + a fake handFeat + load finger_piano
(base ++ "palette/scales.scd").load;
~handFeat = Dictionary.new;
~handFeat[\lx] = 0.5; ~handFeat[\rx] = 0.5;
~handFeat[\ly] = 0.5; ~handFeat[\ry] = 0.5;
~melodyInst = \pluck;
(base ++ "control/finger_piano.scd").load;

// default scale is minor pentatonic; left thumb (hand 0, finger 0) -> degree 0
ev = ~fpResolve.(0, 0, 1.0, 0.0, 0.5, 0.5);
("note L thumb = " ++ ev[\note]).postln;
if(ev[\note] != ~fpScaleArr.wrapAt(0)) {
    ok = false; "FAIL: L thumb note wrong".postln;
};

// right hand defaults one octave up (~fpHandOct[1] = 12)
ev = ~fpResolve.(1, 0, 1.0, 0.0, 0.5, 0.5);
if(ev[\note] != (~fpScaleArr.wrapAt(0) + 12)) {
    ok = false; "FAIL: R thumb octave wrong".postln;
};

// instrument follows live via \live sentinel
~fpInst = \live;
if(~fpResolveInst.() != \pluck) { ok = false; "FAIL: live inst".postln; };
~fpInst = \fm_bell;
if(~fpResolveInst.() != \fm_bell) { ok = false; "FAIL: pinned inst".postln; };

// modulation tick updates ~fpCut from dist
~handFeat[\dist] = 1.0;
~fpModTick.();
if(~fpCut.isNil) { ok = false; "FAIL: fpCut nil".postln; };

if(ok) { "PASS test_finger_piano".postln } { "TESTS FAILED".postln };
0.exit;
)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sclang sound_algo/tests/test_finger_piano.scd`
Expected: FAIL — sclang error that `control/finger_piano.scd` does not exist
(open failed / `~fpResolve` is nil).

- [ ] **Step 3: Write minimal implementation**

Create `sound_algo/control/finger_piano.scd`:

```supercollider
// =====================================================================
//  control/finger_piano.scd  --  Air-piano : doigts iPhone -> notes SC
//
//  Recoit /pose/finger (emis par data_only_viz quand FINGER_PIANO=1) :
//    /pose/finger <pid> <hand> <finger> <strikeSpeed> <z> <tipx> <tipy>
//  Chaque doigt = un degre de gamme. La position de main decale l'octave,
//  la vitesse de frappe donne la velocite. Module aussi des params globaux
//  depuis l'ecart des mains (~handFeat[\dist]).
//
//  Charge par data_only/boot.scd et boot.data-only.scd apres data_feeds.scd.
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
// ---------- ETAT / CONFIG (idempotent : ne reset pas si deja defini) ----
~fpEnabled   = ~fpEnabled   ? false;
~fpInst      = ~fpInst      ? \live;      // \live = suit ~melodyInst
~fpScaleArr  = ~fpScaleArr  ? ~scaleMinorPent;
~fpMap       = ~fpMap       ? [[0,1,2,3,4], [0,1,2,3,4]];  // [L, R] degres
~fpHandOct   = ~fpHandOct   ? [0, 12];    // L octave basse, R +1 octave
~fpBaseOct   = ~fpBaseOct   ? 0;          // octaves globales en plus
~fpOctSpan   = ~fpOctSpan   ? 1;          // +/- octaves selon x de la main
~fpSens      = ~fpSens      ? 1.0;
~fpVelSource = ~fpVelSource ? \strike;    // \strike ou \z
~fpHold      = ~fpHold      ? 0.35;       // duree avant gate=0 (sec)
~fpAmp       = ~fpAmp       ? 0.3;
~fpCut       = ~fpCut       ? 0.0;
~fpFx        = ~fpFx        ? 0.0;

// Bus de modulation continue (sorties a mapper sur un synth/param).
if(~fpCutBus.isNil and: { s.serverRunning }) {
    ~fpCutBus = Bus.control(s, 1);
    ~fpFxBus  = Bus.control(s, 1);
};

// Gammes nommees accessibles via ~fpScale_
~fpScales = (
    minorPent: ~scaleMinorPent, minor: ~scaleMinor, dorian: ~scaleDorian,
    phrygian: ~scalePhrygian, blues: ~scaleBlues, japanese: ~scaleJapanese,
    hijaz: ~scaleHijaz, hirajoshi: ~scaleHirajoshi
);

// ---------- RESOLUTION (pure, testable) ---------------------------------
~fpResolveInst = {
    if(~fpInst == \live or: { ~fpInst.isNil }) { ~melodyInst ? \pluck }
    { ~fpInst };
};

~fpResolve = { |hand, finger, strikeSpeed = 1.0, z = 0.0, tipx = 0.5, tipy = 0.5|
    var deg, handX, octFromX, transpose, note, vel, amp;
    deg = ~fpMap[hand][finger] ? 0;
    handX = if(hand == 0) { ~handFeat[\lx] ? 0.5 } { ~handFeat[\rx] ? 0.5 };
    // x autour de 0.5 -> +/- ~fpOctSpan octaves
    octFromX = ((handX - 0.5) * 2 * ~fpOctSpan).round(1.0).asInteger;
    transpose = (~fpHandOct[hand] ? 0) + (~fpBaseOct * 12) + (octFromX * 12);
    note = (~fpScaleArr.wrapAt(deg) + transpose).asInteger;
    vel = if(~fpVelSource == \z) { z } { strikeSpeed };
    amp = (~fpAmp * (0.25 + (0.75 * vel)) * ~fpSens).clip(0.0, 1.0);
    (note: note, freq: note.midicps, amp: amp, inst: ~fpResolveInst.());
};

// ---------- MODULATION CONTINUE -----------------------------------------
// dist (0..1) -> cutoff exp 200..6000 Hz ; mean Y (0..1) -> fx 0..1
~fpModTick = {
    var dist, meanY, cutHz, fx;
    dist  = (~handFeat[\dist] ? 0.0).clip(0.0, 1.0);
    meanY = (((~handFeat[\ly] ? 0.5) + (~handFeat[\ry] ? 0.5)) * 0.5)
              .clip(0.0, 1.0);
    // lissage one-pole
    ~fpCut = ~fpCut + (0.2 * (dist - ~fpCut));
    ~fpFx  = ~fpFx  + (0.2 * (meanY - ~fpFx));
    cutHz = (200 * (30 ** ~fpCut));     // 200 -> 6000 Hz
    fx = ~fpFx;
    if(~fpCutBus.notNil) { ~fpCutBus.set(cutHz) };
    if(~fpFxBus.notNil)  { ~fpFxBus.set(fx) };
};

// ---------- OSC : declenchement note ------------------------------------
OSCdef(\poseFinger, { |msg|
    var ev, syn;
    if(~fpEnabled == true) {
        // msg = [/pose/finger, pid, hand, finger, strikeSpeed, z, tipx, tipy]
        ev = ~fpResolve.(msg[2].asInteger, msg[3].asInteger,
                         msg[4], msg[5], msg[6], msg[7]);
        if(s.serverRunning) {
            syn = Synth(ev[\inst], [\freq, ev[\freq], \amp, ev[\amp], \gate, 1]);
            SystemClock.sched(~fpHold, { syn.set(\gate, 0); nil });
        };
    };
}, '/pose/finger');

// ---------- API LIVE (env-direct wrappers) ------------------------------
~fpOn        = { ~fpEnabled = true;  "[fp] air-piano ON".postln; };
~fpOff       = { ~fpEnabled = false; "[fp] air-piano OFF".postln; };
~fpInst_     = { |sym| ~fpInst = sym; ("[fp] inst = " ++ sym).postln; };
~fpScale_    = { |name|
    ~fpScaleArr = ~fpScales[name] ? ~fpScaleArr;
    ("[fp] scale = " ++ name).postln;
};
~fpSens_     = { |v| ~fpSens = v; };
~fpOctave_   = { |n| ~fpBaseOct = n; };
~fpVelSource_ = { |sym| ~fpVelSource = sym; };

"[OK] finger_piano : ~fpOn / ~fpScale_(\\dorian) / ~fpInst_(\\fm_bell)".postln;
)
```

- [ ] **Step 4: Run test + balance check to verify they pass**

Run: `sclang sound_algo/tests/test_finger_piano.scd`
Expected: `PASS test_finger_piano`

Then run the parens/brackets balance check (must be P:0 B:0):

Run:
```bash
awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/control/finger_piano.scd
```
Expected: `P:0 B:0`

- [ ] **Step 5: Commit**

```bash
git add sound_algo/control/finger_piano.scd sound_algo/tests/test_finger_piano.scd
git commit -m "feat: air-piano finger note engine in sc"
```

---

### Task 5: SC — hook modulation into `data_feeds.scd`, wire loading + docs

Make `~fpModTick` run on every `/pose/hands` frame, load `finger_piano.scd` in
both data-only boot paths, and document the env vars.

**Files:**
- Modify: `sound_algo/control/data_feeds.scd:502-512` (`\poseHands` OSCdef)
- Modify: `sound_algo/data_only/boot.scd` (after the `data_feeds.scd` load,
  line ~151)
- Modify: `sound_algo/boot.data-only.scd` (after the `data_feeds.scd` load,
  line ~40)
- Modify: `CLAUDE.md` (Environment variables table)

**Interfaces:**
- Consumes: `~fpModTick` (Task 4), loaded `finger_piano.scd`.
- Produces: continuous calls to `~fpModTick` at the `/pose/hands` rate (~30 Hz);
  `finger_piano.scd` present in the data-only runtime so `/pose/finger` is
  handled and `~fp*` API is available.

- [ ] **Step 1: Add the modulation hook in `data_feeds.scd`**

In `sound_algo/control/data_feeds.scd`, change the `\poseHands` OSCdef
(line 511 `~handFeat[\dist] = msg[10];`) so the closing of the function calls
the modulation tick. Replace:

```supercollider
    ~handFeat[\dist]   = msg[10];
}, '/pose/hands');
```

with:

```supercollider
    ~handFeat[\dist]   = msg[10];
    ~fpModTick !? { ~fpModTick.value };   // air-piano modulation continue
}, '/pose/hands');
```

- [ ] **Step 2: Load `finger_piano.scd` in `data_only/boot.scd`**

In `sound_algo/data_only/boot.scd`, find the data_feeds load (line ~151,
`(~repoRoot ++ "control/data_feeds.scd").load;`) and add immediately after it:

```supercollider
    (~repoRoot ++ "control/finger_piano.scd").load;
```

- [ ] **Step 3: Load `finger_piano.scd` in `boot.data-only.scd`**

In `sound_algo/boot.data-only.scd`, find the data_feeds load (line ~40,
`(~base ++ "control/data_feeds.scd").load;`) and add immediately after it:

```supercollider
    (~base ++ "control/finger_piano.scd").load;
```

- [ ] **Step 4: Document env vars in root `CLAUDE.md`**

In `/Users/electron/Documents/Projets/AV-Live/CLAUDE.md`, in the second
`## Environment variables` table (the one starting with `POSE_FILTER`), add
these rows at the end of the table body:

```markdown
| `FINGER_PIANO` | `0` | `1` enables air-piano finger strike emission from data_only_viz |
| `FINGER_STRIKE_VEL` | `0.02` | downward relative-velocity threshold for a strike (normalized image units/frame) |
| `FINGER_STRIKE_REFRACTORY_MS` | `120` | min ms between strikes per finger |
```

- [ ] **Step 5: Verify balance of the edited `.scd` and re-run the SC test**

Run (both must report `P:0 B:0`):
```bash
awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/control/data_feeds.scd
sclang sound_algo/tests/test_finger_piano.scd
```
Expected: `P:0 B:0` and `PASS test_finger_piano`

- [ ] **Step 6: Commit**

```bash
git add sound_algo/control/data_feeds.scd sound_algo/data_only/boot.scd sound_algo/boot.data-only.scd CLAUDE.md
git commit -m "feat: load air-piano and hook hand modulation"
```

---

### Task 6: End-to-end manual smoke (no code) + Python suite green

Final verification gate. No new code; confirm the whole chain and the full
Python suite.

**Files:** none (verification only).

- [ ] **Step 1: Full Python suite stays green**

Run: `cd data_only_viz && uv run pytest tests/ -v`
Expected: all pass (new finger tests + existing action-head/pose-bridge tests).

- [ ] **Step 2: Live smoke with iPhone (manual)**

With the iPhone ARBodyTracker streaming and data_only_viz running:

```bash
FINGER_PIANO=1 uv run python -m data_only_viz.main
```

In the SC data-only session, enable and play:

```supercollider
~fpOn.();
~fpScale_.(\dorian);
~fpInst_.(\live);     // suit l'instrument melodique courant
```

Expected: striking a finger downward triggers a note; right hand sounds one
octave above the left; moving a hand left/right shifts the octave; spreading the
hands raises `~fpCut` (check `~fpCut.postln` rises toward 1.0). Tune
`FINGER_STRIKE_VEL` if strikes are too eager / too stiff.

- [ ] **Step 3: Commit (only if smoke required a threshold tweak in docs)**

If you changed a default threshold based on the smoke test, update the
`CLAUDE.md` default and the `FingerStrikeDetector` default to match, then:

```bash
git add -A
git commit -m "tune: finger strike default threshold"
```

---

## Self-Review

**Spec coverage:**
- `/pose/finger` message → Task 2 (emit), Task 3 (wire), Task 4 (receive). OK.
- Python strike detector with relative-to-MCP flexion → Task 1. OK.
- Env vars `FINGER_PIANO` / `FINGER_STRIKE_VEL` / `FINGER_STRIKE_REFRACTORY_MS`
  → Task 3 (read), Task 5 step 4 (doc). OK.
- SC air-piano: finger→degree, octave from hand x, velocity from strike/z,
  scale resolution, configurable instrument following `~melodyInst` → Task 4
  (`~fpResolve`, `~fpResolveInst`). OK.
- Continuous modulation from `~handFeat[\dist]` + mean position → Task 4
  (`~fpModTick`), Task 5 step 1 (hook). OK.
- `~fp` live API → Task 4. OK.
- Runtime loading in data-only paths → Task 5 steps 2-3. OK.
- Tests: Python pytest (Tasks 1-3) + SC headless test + balance check
  (Task 4-5) + manual smoke (Task 6). OK.
- Single-performer assumption (pid=0) → Task 2 emits pid=0. OK.

**Placeholder scan:** every code step contains full code; no TBD/TODO. OK.

**Type consistency:** `StrikeEvent` fields (`hand, finger, strike_speed, z,
tipx, tipy`) identical across Tasks 1-3. `send_finger(ev)` arg order matches the
`/pose/finger` arg order consumed by `~fpResolve` (hand=msg[2], finger=msg[3],
strikeSpeed=msg[4], z=msg[5], tipx=msg[6], tipy=msg[7]). `~fpResolve` /
`~fpResolveInst` / `~fpModTick` / `~fpCut` names match between Task 4 impl and
the Task 4 test and the Task 5 hook. OK.
