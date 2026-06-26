# Hand-driven `data_only` Modulation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn MediaPipe hand landmarks into a compact expressive feature vector that modulates the `data_only` SuperCollider FX rack and visibly drives the Metal scene, via one shared signal.

**Architecture:** A new Python `HandFeatureExtractor` reads the already-captured hand landmarks from `state`, computes per-hand position/openness/speed plus two-hand distance, and emits them (a) over OSC `/pose/hands` to SuperCollider and (b) into the Metal renderer uniforms. SuperCollider stores them in `~handFeat` and maps them to a new global filter / reverb / width / drive. The Metal shader reacts to the same features. Modulation only — no note generation, no dense hand mesh.

**Tech Stack:** Python 3.11+ (uv), MediaPipe, python-osc (`SimpleUDPClient`), pyobjc + Metal (`scene.metal`), SuperCollider (sclang/scsynth).

## Global Constraints

- Python: use **uv** for all runs (`uv run ...`); never pip/poetry/conda directly.
- No emojis in code/docs/commits.
- Commits: subject ≤ 50 chars, body ≤ 72 chars/line, no AI attribution, no `--no-verify`, no underscore in the commit scope (use hyphens, e.g. `data-only`).
- `.scd` files: parentheses/brackets must balance (P:0 B:0); files loaded via `.load` need exactly one top-level block. Run the `validating-scd-files` skill after every `.scd` edit.
- SuperCollider SynthDefs in `sound_algo`: lagged controls, `EnvGen.kr(..., doneAction: 2)` for any voiced synth, `Pan2.ar`/`ReplaceOut.ar` on the master path, no zombie synths. Use the `adding-synthdef` skill for new SynthDefs.
- Stay inside the `data_only` subsystem; do not touch the main live engine (tracks A–W, `01_live.scd`).

### v1 contract decision (refines the spec)

The OSC route is a **single global message** `pid=0` carrying the two most
prominent hands, labelled **L = leftmost on screen, R = rightmost** (by centroid
x). This avoids the fragile pid-parity handedness proxy in the existing
`_send_hand`. Multi-person hand modulation is a deliberate later widening.

```
/pose/hands  [0, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]
```
- `lx,ly,rx,ry` ∈ [0,1] (normalized; y down, MediaPipe convention)
- `lopen,ropen` ∈ [0,1] (0 = fist, 1 = open hand)
- `lspeed,rspeed` ≥ 0 (centroid speed, normalized units/frame)
- `dist` ∈ [0,1] (0 = one/zero hands or hands together, 1 = arms wide)
- A hand absent → its 4 floats are 0.0.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `data_only_viz/hand_features.py` | Create | `HandFeatureExtractor`: landmarks → feature dict |
| `data_only_viz/tests/test_hand_features.py` | Create | Unit tests for the extractor |
| `data_only_viz/pose_bridge.py` | Modify | `send_hands(feats, t)` OSC emitter |
| `data_only_viz/tests/test_pose_bridge_hands.py` | Create | Unit test for message construction |
| `data_only_viz/action_head_pub.py` | Modify | Per-tick: extract + send hand features |
| `data_only_viz/renderer.py` | Modify | Pack hand features into Metal uniforms |
| `data_only_viz/shaders/scene.metal` | Modify | Expressive hand uniforms + scene reaction |
| `sound_algo/control/data_feeds.scd` | Modify | OSCdef `/pose/hands` → `~handFeat` |
| `sound_algo/data_only/engine.scd` | Modify | `\do_master_filter` (cutoff/width/drive) |
| `sound_algo/data_only/scene_pose_action.scd` | Modify | `~mapHandsToFx` + wire FX stubs |
| `sound_algo/data_only/boot.scd` | Modify | Load `scene_pose_action.scd` |
| `data_only_viz/README.md` / `sound_algo/data_only/` notes | Modify | Document `/pose/hands` contract |

---

## Task 1: HandFeatureExtractor (Python, pure)

**Files:**
- Create: `data_only_viz/hand_features.py`
- Test: `data_only_viz/tests/test_hand_features.py`

**Interfaces:**
- Consumes: a list of hands, each a list of ≥21 objects with float attributes `.x`, `.y` (MediaPipe `PoseKp` shape; `state.persons_hands` items).
- Produces:
  - `HandFeatureExtractor(history: int = 5)`
  - `.step(hands: list[list]) -> dict` returning
    `{"L": {"cx","cy","openness","speed"} | None, "R": {...} | None, "dist": float}`
  - module constant `NEUTRAL_HAND = {"cx":0.5,"cy":0.5,"openness":0.0,"speed":0.0}`

Landmark index constants (MediaPipe hand): `WRIST=0`, `THUMB_TIP=4`, `MIDDLE_MCP=9`, `PINKY_TIP=20`.

- [ ] **Step 1: Write the failing tests**

```python
# data_only_viz/tests/test_hand_features.py
import math
import pytest
from data_only_viz.hand_features import HandFeatureExtractor, NEUTRAL_HAND


class LM:
    """Minimal landmark stub (PoseKp-shaped)."""
    def __init__(self, x, y, z=0.0, c=1.0):
        self.x, self.y, self.z, self.c = x, y, z, c


def _hand(cx, cy, span):
    """21 landmarks centered at (cx,cy); thumb/pinky separated by `span`.

    Index 0 wrist, 4 thumb_tip, 9 middle_mcp, 20 pinky_tip.
    hand_size (wrist->middle_mcp) fixed at 0.10 so openness ~ span/size.
    """
    pts = [LM(cx, cy) for _ in range(21)]
    pts[0] = LM(cx, cy + 0.05)          # wrist below center
    pts[9] = LM(cx, cy - 0.05)          # middle_mcp above -> size 0.10
    pts[4] = LM(cx - span / 2, cy)      # thumb_tip
    pts[20] = LM(cx + span / 2, cy)     # pinky_tip
    return pts


def test_open_hand_high_openness():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.5, 0.5, span=0.20)])  # span/size = 2.0
    hand = out["L"] or out["R"]
    assert hand["openness"] > 0.8


def test_fist_low_openness():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.5, 0.5, span=0.03)])  # span/size = 0.3
    hand = out["L"] or out["R"]
    assert hand["openness"] < 0.2


def test_static_hand_zero_speed():
    ext = HandFeatureExtractor()
    h = _hand(0.5, 0.5, span=0.1)
    ext.step([h])
    out = ext.step([h])
    hand = out["L"] or out["R"]
    assert hand["speed"] == pytest.approx(0.0, abs=1e-6)


def test_moving_hand_positive_speed():
    ext = HandFeatureExtractor()
    ext.step([_hand(0.2, 0.5, span=0.1)])
    out = ext.step([_hand(0.6, 0.5, span=0.1)])
    hand = out["L"] or out["R"]
    assert hand["speed"] > 0.0


def test_left_right_by_screen_x():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.8, 0.5, span=0.1), _hand(0.2, 0.5, span=0.1)])
    assert out["L"]["cx"] < out["R"]["cx"]      # L is leftmost on screen
    assert out["dist"] > 0.0


def test_single_hand_zero_dist():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.5, 0.5, span=0.1)])
    assert out["dist"] == 0.0


def test_no_hands_returns_none():
    ext = HandFeatureExtractor()
    out = ext.step([])
    assert out["L"] is None and out["R"] is None and out["dist"] == 0.0


def test_nan_landmark_falls_back_no_exception():
    ext = HandFeatureExtractor()
    h = _hand(0.5, 0.5, span=0.1)
    h[0] = LM(float("nan"), float("nan"))
    out = ext.step([h])           # must not raise
    hand = out["L"] or out["R"]
    assert math.isfinite(hand["cx"]) and math.isfinite(hand["openness"])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "/Users/electron/Documents/Projets/AV-Live" && uv run python -m pytest data_only_viz/tests/test_hand_features.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'data_only_viz.hand_features'`

- [ ] **Step 3: Write the implementation**

```python
# data_only_viz/hand_features.py
"""Turn MediaPipe hand landmarks into a compact expressive feature vector.

Mirrors the kinematics pattern of action_head.FeatureExtractor: a small ring
buffer per hand slot, finite-guarded, clamped to declared ranges. Output feeds
both the OSC /pose/hands route (audio) and the Metal renderer uniforms (visual).
"""
from __future__ import annotations
import math
from collections import deque

WRIST, THUMB_TIP, MIDDLE_MCP, PINKY_TIP = 0, 4, 9, 20

NEUTRAL_HAND = {"cx": 0.5, "cy": 0.5, "openness": 0.0, "speed": 0.0}

# openness calibration: (span/size) maps fist~0.3 -> 0, open~2.0 -> 1
_OPEN_LO, _OPEN_HI = 0.5, 2.0


def _finite(v: float, fallback: float) -> float:
    return v if isinstance(v, float) and math.isfinite(v) else fallback


def _clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else hi if v > hi else v


class HandFeatureExtractor:
    def __init__(self, history: int = 5):
        self._history = max(2, history)
        # two screen slots: 0 = leftmost (L), 1 = rightmost (R)
        self._buf = [deque(maxlen=self._history), deque(maxlen=self._history)]

    def _features(self, lm: list) -> dict:
        xs = [_finite(float(p.x), 0.5) for p in lm[:21]]
        ys = [_finite(float(p.y), 0.5) for p in lm[:21]]
        cx = _clamp(sum(xs) / len(xs), 0.0, 1.0)
        cy = _clamp(sum(ys) / len(ys), 0.0, 1.0)
        size = math.hypot(xs[MIDDLE_MCP] - xs[WRIST], ys[MIDDLE_MCP] - ys[WRIST])
        size = size if size > 1e-4 else 1e-4
        span = math.hypot(xs[THUMB_TIP] - xs[PINKY_TIP],
                          ys[THUMB_TIP] - ys[PINKY_TIP])
        openness = _clamp((span / size - _OPEN_LO) / (_OPEN_HI - _OPEN_LO),
                          0.0, 1.0)
        return {"cx": cx, "cy": cy, "openness": openness}

    def _speed(self, slot: int, cx: float, cy: float) -> float:
        buf = self._buf[slot]
        spd = 0.0
        if buf:
            px, py = buf[-1]
            spd = math.hypot(cx - px, cy - py)
        buf.append((cx, cy))
        return _clamp(spd, 0.0, 1.0)

    def step(self, hands: list) -> dict:
        feats = []
        for lm in hands:
            if lm and len(lm) >= 21:
                feats.append(self._features(lm))
        if not feats:
            self._buf[0].clear()
            self._buf[1].clear()
            return {"L": None, "R": None, "dist": 0.0}
        feats.sort(key=lambda f: f["cx"])           # leftmost first
        left = feats[0]
        right = feats[-1] if len(feats) > 1 else None
        left["speed"] = self._speed(0, left["cx"], left["cy"])
        out_l = left
        out_r = None
        dist = 0.0
        if right is not None:
            right["speed"] = self._speed(1, right["cx"], right["cy"])
            out_r = right
            dist = _clamp(math.hypot(right["cx"] - left["cx"],
                                     right["cy"] - left["cy"]), 0.0, 1.0)
        else:
            self._buf[1].clear()
        return {"L": out_l, "R": out_r, "dist": dist}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "/Users/electron/Documents/Projets/AV-Live" && uv run python -m pytest data_only_viz/tests/test_hand_features.py -v`
Expected: PASS (8 passed)

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add data_only_viz/hand_features.py data_only_viz/tests/test_hand_features.py
git commit -m "feat(viz): hand feature extractor"
```

---

## Task 2: OSC sender `send_hands`

**Files:**
- Modify: `data_only_viz/pose_bridge.py` (class `PoseSoundBridge`, near `send_kin` ~line 311)
- Test: `data_only_viz/tests/test_pose_bridge_hands.py`

**Interfaces:**
- Consumes: the dict from `HandFeatureExtractor.step()` (`{"L","R","dist"}`).
- Produces: `PoseSoundBridge.send_hands(self, feats: dict, t: float) -> None` sending OSC `"/pose/hands"` with `[0, lx,ly,lopen,lspeed, rx,ry,ropen,rspeed, dist]` (1 int + 9 floats) via `self._client`. Absent hand → its 4 floats are 0.0. Silent on send failure.

- [ ] **Step 1: Write the failing test**

```python
# data_only_viz/tests/test_pose_bridge_hands.py
from data_only_viz.pose_bridge import PoseSoundBridge


class FakeClient:
    def __init__(self):
        self.sent = []

    def send_message(self, addr, args):
        self.sent.append((addr, args))


def _bridge():
    b = PoseSoundBridge.__new__(PoseSoundBridge)   # bypass __init__/sockets
    b._client = FakeClient()
    return b


def test_send_hands_both_present():
    b = _bridge()
    feats = {
        "L": {"cx": 0.2, "cy": 0.4, "openness": 0.9, "speed": 0.1},
        "R": {"cx": 0.8, "cy": 0.3, "openness": 0.5, "speed": 0.0},
        "dist": 0.6,
    }
    b.send_hands(feats, t=1.0)
    addr, args = b._client.sent[-1]
    assert addr == "/pose/hands"
    assert args[0] == 0
    assert args[1:5] == [0.2, 0.4, 0.9, 0.1]
    assert args[5:9] == [0.8, 0.3, 0.5, 0.0]
    assert args[9] == 0.6
    assert len(args) == 10


def test_send_hands_left_only_zero_pads_right():
    b = _bridge()
    feats = {"L": {"cx": 0.5, "cy": 0.5, "openness": 0.7, "speed": 0.2},
             "R": None, "dist": 0.0}
    b.send_hands(feats, t=1.0)
    _, args = b._client.sent[-1]
    assert args[5:9] == [0.0, 0.0, 0.0, 0.0]


def test_send_hands_none_emits_all_zero():
    b = _bridge()
    b.send_hands({"L": None, "R": None, "dist": 0.0}, t=1.0)
    _, args = b._client.sent[-1]
    assert args == [0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "/Users/electron/Documents/Projets/AV-Live" && uv run python -m pytest data_only_viz/tests/test_pose_bridge_hands.py -v`
Expected: FAIL — `AttributeError: 'PoseSoundBridge' object has no attribute 'send_hands'`

- [ ] **Step 3: Add the method**

Add to `PoseSoundBridge` in `data_only_viz/pose_bridge.py` (next to `send_kin`):

```python
    @staticmethod
    def _hand_slot(h):
        if not h:
            return [0.0, 0.0, 0.0, 0.0]
        return [float(h["cx"]), float(h["cy"]),
                float(h["openness"]), float(h["speed"])]

    def send_hands(self, feats, t):
        """Emit /pose/hands [0, lx,ly,lopen,lspeed, rx,ry,ropen,rspeed, dist]."""
        args = [0]
        args += self._hand_slot(feats.get("L"))
        args += self._hand_slot(feats.get("R"))
        args.append(float(feats.get("dist", 0.0)))
        try:
            self._client.send_message("/pose/hands", args)
        except OSError:
            pass
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "/Users/electron/Documents/Projets/AV-Live" && uv run python -m pytest data_only_viz/tests/test_pose_bridge_hands.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add data_only_viz/pose_bridge.py data_only_viz/tests/test_pose_bridge_hands.py
git commit -m "feat(viz): /pose/hands OSC sender"
```

---

## Task 3: Wire extraction + send into the per-tick loop

**Files:**
- Modify: `data_only_viz/action_head_pub.py` (around the `send_kin` call, ~line 138)

**Interfaces:**
- Consumes: `HandFeatureExtractor` (Task 1), `PoseSoundBridge.send_hands` (Task 2), and the live `state` object exposing `persons_hands` (and `left_hand_kp`/`right_hand_kp` as single-person fallback).
- Produces: a `/pose/hands` message emitted once per tick alongside `/pose/kin`.

- [ ] **Step 1: Locate the tick and the state handle**

Read `data_only_viz/action_head_pub.py` around the publisher `__init__` and the
`_tick`/`step` method that calls `self.bridge.send_kin(...)` (~line 138).
Confirm how the shared `state` snapshot is obtained there (the same object whose
`persons_hands` field Task 1 consumes).

- [ ] **Step 2: Instantiate the extractor in `__init__`**

Add to the publisher constructor (after `self.bridge = ...`):

```python
        from data_only_viz.hand_features import HandFeatureExtractor
        self._hand_ext = HandFeatureExtractor()
```

- [ ] **Step 3: Extract + send each tick**

Immediately after the existing `self.bridge.send_kin(pid, kin, t_now, force=True)`
call, add (using the same state snapshot variable already in scope — replace
`state` below with the local name found in Step 1):

```python
        hands = list(getattr(state, "persons_hands", None) or [])
        if not hands and getattr(state, "hands_present", False):
            hands = [state.left_hand_kp, state.right_hand_kp]
            hands = [h for h in hands if h]
        hand_feats = self._hand_ext.step(hands)
        self.bridge.send_hands(hand_feats, t_now)
```

- [ ] **Step 4: Smoke test the wire**

In one terminal, listen for the route:

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
uv run python - <<'PY'
from pythonosc import dispatcher, osc_server
d = dispatcher.Dispatcher()
d.map("/pose/hands", lambda a, *args: print("HANDS", args))
osc_server.BlockingOSCUDPServer(("127.0.0.1", 57121), d).serve_forever()
PY
```

In another, run the pose pipeline as usual (the data_only_viz entry that drives
`action_head_pub`) with a hand in frame.
Expected: `HANDS (0, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist)` lines
streaming; values change when the hand moves/opens. Stop the listener (Ctrl-C)
before booting SuperCollider on 57121.

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add data_only_viz/action_head_pub.py
git commit -m "feat(viz): emit hand features each tick"
```

---

## Task 4: SuperCollider ingestion `~handFeat` + boot fix + docs

**Files:**
- Modify: `sound_algo/control/data_feeds.scd` (next to pose OSCdefs, ~line 464-496)
- Modify: `sound_algo/data_only/boot.scd` (load sequence, ~line 133)
- Modify: `data_only_viz/README.md` (document the route)

**Interfaces:**
- Consumes: OSC `/pose/hands` from Task 2.
- Produces: global `~handFeat` Dictionary with keys
  `lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist` (Floats), refreshed each
  message. Read by Task 6.

- [ ] **Step 1: Add the OSCdef**

In `sound_algo/control/data_feeds.scd`, after the `\poseLeave` OSCdef block, add:

```supercollider
~handFeat = ~handFeat ? Dictionary.new;

OSCdef(\poseHands, { |msg|
    ~handFeat[\lx]     = msg[2];
    ~handFeat[\ly]     = msg[3];
    ~handFeat[\lopen]  = msg[4];
    ~handFeat[\lspeed] = msg[5];
    ~handFeat[\rx]     = msg[6];
    ~handFeat[\ry]     = msg[7];
    ~handFeat[\ropen]  = msg[8];
    ~handFeat[\rspeed] = msg[9];
    ~handFeat[\dist]   = msg[10];
}, '/pose/hands');
```

- [ ] **Step 2: Load `scene_pose_action.scd` at boot**

In `sound_algo/data_only/boot.scd`, in the load sequence (after the line that
loads `scenes.scd`, ~line 133), add a load of the pose/hand mapping file. Match
the existing load idiom used a few lines above (same `(thisProcess... .resolveRelative)`
or `.loadRelative` form already used for `scenes.scd`); for example:

```supercollider
(thisProcess.nowExecutingPath.dirname +/+ "scene_pose_action.scd").load;
```

- [ ] **Step 3: Validate the `.scd` files**

Invoke the `validating-scd-files` skill on `sound_algo/control/data_feeds.scd`
and `sound_algo/data_only/boot.scd`.
Expected: P:0 B:0 for both; boot.scd keeps exactly one top-level block (it is
`.load`-ed). Fix any imbalance before continuing.

- [ ] **Step 4: Document the contract**

In `data_only_viz/README.md`, add a short "Hand features OSC" subsection:

```markdown
### Hand features OSC

`/pose/hands [pid=0, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]`

- Emitted once per pipeline tick by `pose_bridge.send_hands` to sclang `:57121`.
- L = leftmost hand on screen, R = rightmost; absent hand -> its 4 floats are 0.
- Ranges: positions/openness/dist in [0,1]; speed >= 0 (normalized units/frame).
- Consumed by SuperCollider `~handFeat` (data_only) and the Metal renderer uniforms.
- Multi-person is not yet carried (pid is always 0).
```

- [ ] **Step 5: Smoke test ingestion**

Boot the data_only subsystem (`sclang sound_algo/data_only/boot.scd`), then from
a separate shell inject one message and confirm storage:

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
uv run python -c "from pythonosc.udp_client import SimpleUDPClient; \
SimpleUDPClient('127.0.0.1',57121).send_message('/pose/hands',[0,0.2,0.4,0.9,0.1,0.8,0.3,0.5,0.0,0.6])"
```

In the sclang console run: `~handFeat[\dist].postln;`
Expected: `0.6` printed.

- [ ] **Step 6: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add sound_algo/control/data_feeds.scd sound_algo/data_only/boot.scd data_only_viz/README.md
git commit -m "feat(data-only): ingest /pose/hands into handFeat"
```

---

## Task 5: FX rack global filter (cutoff / width / drive)

**Files:**
- Modify: `sound_algo/data_only/engine.scd` (FX rack, ~line 34-59)

**Interfaces:**
- Consumes: the master audio path (bus 0) and the existing FX group `~doMasterGroup`.
- Produces: a Synth `~doFilter` placed before `~doMaster` on bus 0 with set-able
  args `cutoff` (Hz, default 20000 = open), `width` (0..1, default 1 = full
  stereo), `drive` (1..4, default 1 = unity). All lagged.

- [ ] **Step 1: Add the SynthDef (use the adding-synthdef skill)**

Invoke the `adding-synthdef` skill, then add to `sound_algo/data_only/engine.scd`
near the other rack SynthDefs:

```supercollider
SynthDef(\do_master_filter, { |out=0, cutoff=20000, width=1.0, drive=1.0|
    var sig, mid, side;                      // all vars first (sclang rule)
    sig = In.ar(out, 2);
    sig = RLPF.ar(sig, cutoff.clip(80, 20000).lag(0.08), 0.7);
    sig = (sig * drive.clip(1, 4).lag(0.05)).tanh;
    // stereo width via mid/side
    mid = (sig[0] + sig[1]) * 0.5;
    side = (sig[0] - sig[1]) * 0.5 * width.clip(0, 1).lag(0.08);
    sig = [mid + side, mid - side];
    sig = LeakDC.ar(sig);
    ReplaceOut.ar(out, sig);
}).add;
```

- [ ] **Step 2: Instantiate before the master**

In the rack boot section (where `~doRev` and `~doMaster` are created via
`Synth.tail(~doMasterGroup, ...)`, ~line 56-59), add `~doFilter` so its node
sits *before* `~doMaster` on bus 0. Insert it immediately ahead of the
`~doMaster` creation:

```supercollider
~doFilter = Synth.before(~doMaster, \do_master_filter, [\out, 0]);
```

If `~doMaster` is created after this line, instead create `~doFilter` with
`Synth.tail(~doMasterGroup, \do_master_filter, [\out, 0])` *before* the
`~doMaster` `Synth.tail` call so node order is filter → master.

- [ ] **Step 3: Validate the `.scd`**

Invoke the `validating-scd-files` skill on `sound_algo/data_only/engine.scd`.
Expected: P:0 B:0.

- [ ] **Step 4: Smoke test audibly**

Boot data_only with a scene playing sound (`~doScene.(\all)`), then in sclang:

```supercollider
~doFilter.set(\cutoff, 400);   // should audibly darken
~doFilter.set(\cutoff, 20000); // back to open
~doFilter.set(\drive, 3);      // should audibly saturate
~doFilter.set(\drive, 1);
~doFilter.set(\width, 0);      // should collapse to mono
~doFilter.set(\width, 1);
```

Expected: each change is audible; no errors; no runaway level (limiter in
`~doMaster` still after the filter).

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add sound_algo/data_only/engine.scd
git commit -m "feat(data-only): global filter cutoff width drive"
```

---

## Task 6: Map `~handFeat` to the FX rack

**Files:**
- Modify: `sound_algo/data_only/scene_pose_action.scd` (~line 26-83)

**Interfaces:**
- Consumes: `~handFeat` (Task 4), `~doFilter`/`~doRev` (Task 5 / engine).
- Produces: `~mapHandsToFx` (a function) and a clock Routine that calls it at
  `~paConfig[\rate]` Hz, driving cutoff/reverb/width/drive from hand features.

Mapping (approved): height `1-cy` → cutoff 200..8000 Hz; `openness` → reverb mix
0..0.8; `speed` → drive 1..3; `dist` → width 0..1. Use the higher hand's height
and the max openness/speed across the two hands.

- [ ] **Step 1: Implement the FX stubs against real targets**

At the top of `sound_algo/data_only/scene_pose_action.scd` (before
`~mapPoseToFx`), wire the stubs the existing pose mapping also calls:

```supercollider
~fxCut   = ~fxCut   ? { |hz|  if(~doFilter.notNil) { ~doFilter.set(\cutoff, hz) } };
~fxRev   = ~fxRev   ? { |mix| if(~doRev.notNil)    { ~doRev.set(\mix, mix) } };
~fxSt    = ~fxSt    ? { |w|   if(~doFilter.notNil) { ~doFilter.set(\width, w) } };
~fxDrive = ~fxDrive ? { |amt| if(~doFilter.notNil) { ~doFilter.set(\drive, amt.linlin(0,1,1,3)) } };
```

- [ ] **Step 2: Add `~mapHandsToFx`**

Add after `~mapPoseToFx`:

```supercollider
~mapHandsToFx = {
    var hf = ~handFeat;
    var hasL, hasR, ys, height, openMax, spdMax;   // all vars first (sclang rule)
    if (hf.notNil and: { hf[\ly].notNil }) {
        hasL = (hf[\lx] + hf[\ly]) > 0.001;
        hasR = (hf[\rx] + hf[\ry]) > 0.001;
        if (hasL or: { hasR }) {
            // higher hand = smaller y; height = 1 - min(y)
            ys = [];
            if (hasL) { ys = ys.add(hf[\ly]) };
            if (hasR) { ys = ys.add(hf[\ry]) };
            height  = 1 - ys.minItem;
            openMax = max(hf[\lopen] ? 0, hf[\ropen] ? 0);
            spdMax  = max(hf[\lspeed] ? 0, hf[\rspeed] ? 0);
            ~fxCut.(height.linexp(0, 1, 200, 8000));
            ~fxRev.(openMax.linlin(0, 1, 0.1, 0.8));
            ~fxDrive.(spdMax.linlin(0, 0.3, 0, 1));
            ~fxSt.((hf[\dist] ? 0).linlin(0, 1, 0.2, 1.0));
        };
    };
};
```

> Note: `~mapPoseToFx` (accel→cutoff) and `~mapHandsToFx` (height→cutoff) both
> drive `~fxCut` on the same clock; hands run second so they take precedence —
> intended for this slice (hands are the new expressive control).

- [ ] **Step 3: Drive it on the config clock**

Find where `~mapPoseToFx` is scheduled (a Routine/clock at `~paConfig[\rate]`).
If a scheduling Routine already exists, add `~mapHandsToFx.value;` next to the
`~mapPoseToFx.value;` call. If none exists in this file, add one at the end:

```supercollider
~paHandRoutine.notNil.if { ~paHandRoutine.stop };
~paHandRoutine = Routine({
    inf.do {
        ~mapPoseToFx.value;
        ~mapHandsToFx.value;
        (1 / (~paConfig[\rate] ? 10)).wait;
    };
}).play(AppClock);
```

- [ ] **Step 4: Validate the `.scd`**

Invoke the `validating-scd-files` skill on
`sound_algo/data_only/scene_pose_action.scd`.
Expected: P:0 B:0.

- [ ] **Step 5: Smoke test end-to-end (audio)**

Boot data_only with sound playing. Inject a high open hand then a low fist:

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
uv run python -c "from pythonosc.udp_client import SimpleUDPClient as C; \
C('127.0.0.1',57121).send_message('/pose/hands',[0,0.5,0.1,0.9,0.0,0.0,0.0,0.0,0.0,0.0])"
# high + open -> bright + reverby
uv run python -c "from pythonosc.udp_client import SimpleUDPClient as C; \
C('127.0.0.1',57121).send_message('/pose/hands',[0,0.5,0.9,0.05,0.0,0.0,0.0,0.0,0.0,0.0])"
# low + fist -> dark + dry
```

Expected: first message brightens + adds reverb; second darkens + dries. No
errors in the sclang console.

- [ ] **Step 6: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add sound_algo/data_only/scene_pose_action.scd
git commit -m "feat(data-only): map hand features to FX"
```

---

## Task 7: Metal uniforms — expressive hand features

**Files:**
- Modify: `data_only_viz/renderer.py` (`UNIFORM_FLOATS` ~line 118; `_update_uniforms` ~line 251-299)

**Interfaces:**
- Consumes: the `HandFeatureExtractor.step()` output for the current frame
  (obtain from the shared state the renderer already locks, or store the latest
  feature dict on `state`).
- Produces: 4 extra uniform floats appended after the existing pad slots:
  `hand_height`, `hand_openness`, `hand_speed`, `hand_dist`. `UNIFORM_FLOATS`
  becomes 24 (still 16-byte aligned: 24*4 = 96 bytes).

- [ ] **Step 1: Make the latest hand features available to the renderer**

In `action_head_pub.py` (Task 3), after computing `hand_feats`, also publish them
onto the shared state so the renderer can read them under its lock:

```python
        state.hand_feats = hand_feats
```

And ensure `state.py` has a default. Add to the state dataclass/fields:

```python
    hand_feats: dict | None = None
```

- [ ] **Step 2: Bump the uniform count**

In `data_only_viz/renderer.py`, change the uniform size constants:

```python
UNIFORM_FLOATS = 24   # 20 + hand_height, hand_openness, hand_speed, hand_dist
UNIFORM_SIZE = UNIFORM_FLOATS * 4   # 96 bytes, 16-byte aligned
```

- [ ] **Step 3: Compute and pack the features**

In `_update_uniforms`, after the existing wrist extraction (~line 259-264), derive
the four expressive scalars from `state.hand_feats` (guard for None), and append
them to the `struct.pack` call (replace the two trailing pad floats with the four
new values; keep total = `UNIFORM_FLOATS`):

```python
        hf = getattr(s, "hand_feats", None) or {}
        hl, hr = hf.get("L"), hf.get("R")
        ys = [h["cy"] for h in (hl, hr) if h]
        hand_height = (1.0 - min(ys)) if ys else 0.0
        hand_open = max([h["openness"] for h in (hl, hr) if h] or [0.0])
        hand_speed = max([h["speed"] for h in (hl, hr) if h] or [0.0])
        hand_dist = float(hf.get("dist", 0.0))
```

Update the `struct.pack(...)` (currently ending `hlx, hly, hrx, hry, 0.0, 0.0`)
to end with:

```python
            hlx, hly, hrx, hry,                 # 15-18 wrist xy (kept)
            hand_height, hand_open,             # 19-20
            hand_speed, hand_dist,              # 21-22
            0.0, 0.0,                           # 23-24 pad (16-byte align)
```

(Confirm the final argument count to `struct.pack(f"{UNIFORM_FLOATS}f", ...)`
equals 24.)

- [ ] **Step 4: Verify packing length**

Run: `cd "/Users/electron/Documents/Projets/AV-Live" && uv run python -c "import struct; print(len(struct.pack('24f', *([0.0]*24))))"`
Expected: `96`

Then launch the renderer briefly with a hand in frame and confirm no crash and
no buffer-size assertion (the Metal buffer is allocated from `UNIFORM_SIZE`).
Expected: window renders; no `as_buffer` size error.

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add data_only_viz/renderer.py data_only_viz/state.py data_only_viz/action_head_pub.py
git commit -m "feat(viz): pack hand features into uniforms"
```

---

## Task 8: Metal shader reaction across scene modes

**Files:**
- Modify: `data_only_viz/shaders/scene.metal` (`SceneUniforms` ~line 18-39; mode dispatch ~line 465-476)

**Interfaces:**
- Consumes: the 4 new uniform floats from Task 7.
- Produces: a subtle, shared reaction in scene modes 0-7 (brightness/scale ←
  height, bloom ← openness, turbulence ← speed, zoom ← dist), without adding a
  new mode.

- [ ] **Step 1: Extend the uniform struct**

In `scene.metal`, add the four fields to `SceneUniforms` (after `hand_r_y`,
replacing/augmenting the two `_pad` floats so the struct matches the 24-float
Python layout — order must match Task 7's pack order: indices 19-22):

```metal
    float hand_l_x;     // 14 (0-based 14 in struct; matches pack idx 15)
    float hand_l_y;     // 15
    float hand_r_x;     // 16
    float hand_r_y;     // 17
    float hand_height;  // 18
    float hand_openness;// 19
    float hand_speed;   // 20
    float hand_dist;    // 21
    float _pad0;        // 22
    float _pad1;        // 23
};
```

(The struct field order must equal the `struct.pack` argument order. Verify
against Task 7 Step 3.)

- [ ] **Step 2: Apply a shared, subtle reaction**

In the fragment dispatcher where modes 0-7 produce `color` (near line 465-476,
where `alpha = mix(0.55, 0.25, U.pose_alive)` is applied), fold in the hand
features multiplicatively so the active scene visibly reacts:

```metal
    // hand-driven expressive modulation (subtle, all modes)
    float hb = 1.0 + U.hand_height * 0.6;          // brightness/scale
    float bloom = U.hand_openness * 0.5;           // dispersion
    float turb = U.hand_speed * 2.0;               // motion energy
    color.rgb *= hb;
    color.rgb += bloom * color.rgb;                 // simple bloom lift
    color.rgb += turb * 0.05 * sin(U.time * 8.0 + p.x * 10.0);
```

(Use the existing fragment-local variable names for `color` and the normalized
coordinate; adjust `p.x` to whatever the file names the uv/coordinate var. Keep
`hand_dist` available for a zoom term in modes that compute a camera/uv scale —
apply `uv *= 1.0 - U.hand_dist * 0.2;` where the mode samples space, if trivial;
otherwise leave `hand_dist` consumed only by the audio side for now.)

- [ ] **Step 3: Visual smoke test**

Run the renderer with the data_only pipeline. Inject hand messages (as in Task 6
Step 5) or move a real hand:
- raise hand → scene brightens;
- open hand → scene blooms/disperses;
- move hand fast → visible turbulence.

Expected: the active mode (not just mode 8) reacts; no shader compile error in
the console.

- [ ] **Step 4: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add data_only_viz/shaders/scene.metal
git commit -m "feat(viz): scene reacts to hand features"
```

---

## Task 9: Full-loop verification

**Files:** none (verification only)

- [ ] **Step 1: Run the Python test suite**

Run: `cd "/Users/electron/Documents/Projets/AV-Live" && uv run python -m pytest data_only_viz/tests/test_hand_features.py data_only_viz/tests/test_pose_bridge_hands.py -v`
Expected: all PASS.

- [ ] **Step 2: Boot the full chain**

Boot data_only SuperCollider (`sclang sound_algo/data_only/boot.scd`) and the
data_only_viz pipeline + renderer. Perform with both hands in frame.
Expected: audio (cutoff/reverb/width/drive) and the Metal scene both react to the
same gestures, frame-aligned; raising/opening/spreading hands reads in sound and
image together.

- [ ] **Step 3: Graceful degradation check**

Kill SuperCollider while the pipeline runs.
Expected: the Python pipeline keeps running, the renderer still reacts to hands,
no traceback from `send_hands` (silent on `OSError`).

- [ ] **Step 4: Final commit (if any cleanup)**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git status   # expect clean; commit only if verification surfaced a fix
```

---

## Self-Review notes

- **Spec coverage:** §3 architecture → Tasks 1/3/7; §4.1 extractor → Task 1;
  §4.2 OSC contract → Tasks 2/4; §4.3 mapping + stubs → Task 6; §4.4 FX rack →
  Task 5; §4.5 Metal → Tasks 7/8; §5 reliability (boot fix, finite guards, OSC
  robustness, docs) → Tasks 1/2/4; §7 testing → Tasks 1/2 + smokes + Task 9.
- **Deferred (spec §8):** extractor home = new file `hand_features.py` (chosen);
  `~mapHandsToFx` = new closure (chosen); filter = `RLPF` + mid/side width
  (chosen); ring buffer = 5 frames (chosen).
- **v1 simplification vs spec:** single global `pid=0` message, L/R by screen x
  (documented in Global Constraints and Task 4 docs); multi-person deferred.
