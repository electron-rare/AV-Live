# Pinch Open-Hand Gate + Debounce Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the finger pinch robust against relaxed-hand/fist false positives during full-body play so it can be re-enabled live.

**Architecture:** Two new gates inside `PinchDetector.step()` (`data_only_viz/finger_strike.py`): an open-hand extension gate (winner engages only if >=2 non-pinching fingers are extended) and an engage debounce (N consecutive qualifying frames). Release stays immediate. Strict defaults live in the env-var reads of `action_head_pub.py`; constructor defaults stay permissive so existing call sites and tests keep today's behavior.

**Tech Stack:** Python 3.11, uv, pytest. Spec: `docs/superpowers/specs/2026-07-02-pinch-open-hand-gate-design.md`.

## Global Constraints

- Python via `uv` only; test command: `cd data_only_viz && uv run pytest tests/... -v`
- Commit subjects <= 50 chars, body lines <= 72, no AI attribution, no underscore in scope.
- `ratio_on`/`ratio_off`/`margin` logic unchanged; FINGER_PIANO strike detector untouched.
- Env defaults (live behavior): `PINCH_EXT_RATIO=1.35`, `PINCH_EXT_MIN=2`, `PINCH_DEBOUNCE_FRAMES=3`.
- Constructor defaults (backward compat): `ext_ratio=1.35`, `ext_min=0`, `debounce_frames=1` — spec's "existing tests stay valid" requirement wins over its defaults table; the strict values are applied at the env layer.
- `PINCH_ENABLE` default stays `0` in `launcher/concert/launch_concert.sh` — flipping it back to `1` is gated on LIVE validation by the user (spec Rollout step 3), NOT part of this plan.

---

### Task 1: Open-hand extension gate in PinchDetector

**Files:**
- Modify: `data_only_viz/finger_strike.py` (class `_PinchState` ~line 135, class `PinchDetector` ~lines 143-207)
- Test: `data_only_viz/tests/test_finger_strike.py`

**Interfaces:**
- Consumes: existing `PinchDetector`, `PinchEvent`, test helpers `_pinch_hand`, `_OPEN`, `_PINCH` (already in the test file).
- Produces: `PinchDetector.__init__(..., ext_ratio: float = 1.35, ext_min: int = 0, debounce_frames: int = 1)` with public attrs `ext_ratio`, `ext_min`, `debounce_frames` (Task 3 asserts them). `debounce_frames` is accepted here but its logic lands in Task 2.

- [ ] **Step 1: Write the failing tests**

Append to `data_only_viz/tests/test_finger_strike.py`:

```python
def _relaxed_hand():
    """Relaxed/fist hand: thumb touches the index tip, but middle/ring/
    pinky are curled near the wrist (NOT extended). The runner-up tip is
    far from the thumb so the closest-wins margin passes -- only the
    extension gate can reject this hand."""
    lm = [[0.5, 0.5, 0.0] for _ in range(21)]
    lm[0] = [0.5, 0.8, 0.0]        # WRIST
    lm[9] = [0.5, 0.5, 0.0]        # MIDDLE_MCP -> hand size 0.3
    lm[4] = [0.45, 0.55, 0.0]      # THUMB_TIP
    lm[8] = [0.47, 0.55, 0.0]      # INDEX_TIP: ratio 0.067 (pinch-close)
    lm[12] = [0.60, 0.62, 0.0]     # MIDDLE_TIP curled (ext ~0.69)
    lm[16] = [0.62, 0.65, 0.0]     # RING_TIP curled (ext ~0.64)
    lm[20] = [0.64, 0.68, 0.0]     # LITTLE_TIP curled (ext ~0.62)
    return lm


def test_relaxed_hand_rejected_by_extension_gate():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        ext_min=2)
    out = []
    for i in range(10):
        out += det.step([_relaxed_hand()], i * 0.033)
    assert out == []


def test_open_hand_pinch_passes_extension_gate():
    # _pinch_hand parks middle/ring/little far from the wrist
    # (ext 1.67 / 1.49 / 1.37, all >= 1.35) -> 3 extended >= ext_min 2.
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        ext_min=2)
    det.step([_pinch_hand(*_OPEN)], 0.0)
    ev = det.step([_pinch_hand(*_PINCH)], 0.1)
    assert len(ev) == 1 and ev[0].state == 1 and ev[0].finger == 1


def test_extension_gate_defeat_reproduces_old_behavior():
    # ext_min=0 disables the gate: the relaxed hand fires like today.
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        ext_min=0)
    ev = det.step([_relaxed_hand()], 0.1)
    assert len(ev) == 1 and ev[0].state == 1
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `cd data_only_viz && uv run pytest tests/test_finger_strike.py -v`
Expected: `test_relaxed_hand_rejected_by_extension_gate` and `test_open_hand_pinch_passes_extension_gate` FAIL with `TypeError: PinchDetector.__init__() got an unexpected keyword argument 'ext_min'`; all pre-existing tests PASS.

- [ ] **Step 3: Implement the extension gate**

In `data_only_viz/finger_strike.py`, replace `PinchDetector.__init__` with:

```python
    def __init__(self, ratio_on: float = 0.45, ratio_off: float = 0.65,
                 refractory_ms: float = 250.0, history_slots: int = 2,
                 margin: float = 0.20, ext_ratio: float = 1.35,
                 ext_min: int = 0, debounce_frames: int = 1) -> None:
        self.ratio_on = ratio_on
        self.ratio_off = ratio_off
        self.refractory_s = refractory_ms / 1000.0
        # Only the single nearest fingertip may engage, and only if it is at
        # least `margin` (in size-normalized units) nearer than the runner-up.
        # Rejects the adjacent-finger ambiguity when fingers curl together.
        self.margin = margin
        # Open-hand gate: the winner may engage only when at least ext_min
        # of the 3 non-pinching fingers are extended (tip-to-wrist distance
        # above ext_ratio hand-sizes). Rejects relaxed-hand/fist false
        # pinches during full-body play. ext_min=0 disables the gate; the
        # live defaults come from the PINCH_EXT_* env vars (action_head_pub),
        # constructor defaults preserve legacy behavior.
        self.ext_ratio = ext_ratio
        self.ext_min = int(ext_min)
        # Engage fires only after debounce_frames consecutive qualifying
        # frames; release stays immediate. 1 = no debounce. (Enforced in
        # step(); wired fully by the debounce task.)
        self.debounce_frames = max(1, int(debounce_frames))
        self._state = [[_PinchState() for _ in range(4)]
                       for _ in range(history_slots)]
```

Then in `step()`, compute per-tip wrist extension next to the existing ratio loop and add the gate to the winner condition — replace the block from `ratios = []` down to the `winner = ...` assignment with:

```python
            ratios = []
            exts = []
            for tip_idx in PINCH_TIPS:
                fx = _finite(_coord(lm[tip_idx], "x", 0), 0.5)
                fy = _finite(_coord(lm[tip_idx], "y", 1), 0.5)
                ratios.append(math.hypot(fx - tx, fy - ty) / size)
                exts.append(math.hypot(fx - wx, fy - wy) / size)
            # closest-wins + margin: pick the single nearest fingertip, and treat
            # it as a pinch only if it is clearly nearer than the runner-up.
            order = sorted(range(4), key=lambda j: ratios[j])
            nearest, runner = order[0], order[1]
            # open-hand gate: a deliberate pinch keeps the other fingers
            # extended; a fist/relaxed hand has them curled at the wrist.
            open_ok = self.ext_min <= 0 or sum(
                1 for j in range(4)
                if j != nearest and exts[j] >= self.ext_ratio
            ) >= self.ext_min
            winner = nearest if (
                ratios[nearest] < self.ratio_on
                and (ratios[runner] - ratios[nearest]) >= self.margin
                and open_ok
            ) else -1
```

- [ ] **Step 4: Run the full test file to verify everything passes**

Run: `cd data_only_viz && uv run pytest tests/test_finger_strike.py -v`
Expected: ALL PASS (new gate tests + every pre-existing strike/pinch test).

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/finger_strike.py data_only_viz/tests/test_finger_strike.py
git commit -m "feat(pose): pinch open-hand extension gate"
```

---

### Task 2: Engage debounce in PinchDetector

**Files:**
- Modify: `data_only_viz/finger_strike.py` (class `_PinchState`, `PinchDetector.step()` engage branch + absent-slot loop)
- Test: `data_only_viz/tests/test_finger_strike.py`

**Interfaces:**
- Consumes: `PinchDetector(..., debounce_frames=N)` from Task 1 (constructor already accepts and stores it); test helpers `_pinch_hand`, `_OPEN`, `_PINCH`.
- Produces: engage emitted only on the `debounce_frames`-th consecutive qualifying frame; release edges unchanged (immediate).

- [ ] **Step 1: Write the failing tests**

Append to `data_only_viz/tests/test_finger_strike.py`:

```python
def test_debounce_delays_engage_to_nth_frame():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        debounce_frames=3)
    det.step([_pinch_hand(*_OPEN)], 0.00)
    a = det.step([_pinch_hand(*_PINCH)], 0.10)   # qualifying 1
    b = det.step([_pinch_hand(*_PINCH)], 0.13)   # qualifying 2
    c = det.step([_pinch_hand(*_PINCH)], 0.16)   # qualifying 3 -> engage
    assert a == [] and b == []
    assert len(c) == 1 and c[0].state == 1 and c[0].finger == 1


def test_debounce_jitter_resets_counter():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        debounce_frames=3)
    det.step([_pinch_hand(*_PINCH)], 0.00)       # qualifying 1
    det.step([_pinch_hand(*_PINCH)], 0.03)       # qualifying 2
    det.step([_pinch_hand(*_OPEN)], 0.06)        # jitter -> counter resets
    a = det.step([_pinch_hand(*_PINCH)], 0.09)   # qualifying 1 again
    b = det.step([_pinch_hand(*_PINCH)], 0.12)   # qualifying 2
    assert a == [] and b == []


def test_release_immediate_after_debounced_engage():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        debounce_frames=3)
    det.step([_pinch_hand(*_PINCH)], 0.00)
    det.step([_pinch_hand(*_PINCH)], 0.03)
    eng = det.step([_pinch_hand(*_PINCH)], 0.06)  # 3rd frame -> engage
    rel = det.step([_pinch_hand(*_OPEN)], 0.09)   # very next frame
    assert len(eng) == 1 and eng[0].state == 1
    assert len(rel) == 1 and rel[0].state == 0
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `cd data_only_viz && uv run pytest tests/test_finger_strike.py -v`
Expected: the 3 new debounce tests FAIL (engage fires on the first qualifying frame, so `a`/`eng` assertions break); everything else PASSES.

- [ ] **Step 3: Implement the debounce**

In `data_only_viz/finger_strike.py`, add the counter to `_PinchState`:

```python
class _PinchState:
    __slots__ = ("engaged", "last_t", "qual")

    def __init__(self) -> None:
        self.engaged: bool = False
        self.last_t: float = -1e9
        self.qual: int = 0        # consecutive qualifying frames (debounce)
```

Replace the per-finger edge loop in `step()` (the `for i in range(4):` block) with:

```python
            for i in range(4):
                st = self._state[slot][i]
                if st.engaged:
                    # release when this finger opens, or another finger took over.
                    if i != winner or ratios[i] > self.ratio_off:
                        st.engaged = False
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=0))
                elif i == winner and (t_now - st.last_t) >= self.refractory_s:
                    # engage only after debounce_frames consecutive qualifying
                    # frames; release below stays edge-immediate.
                    st.qual += 1
                    if st.qual >= self.debounce_frames:
                        st.engaged = True
                        st.last_t = t_now
                        st.qual = 0
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=1))
                else:
                    st.qual = 0
```

And reset the counter for absent slots — replace the trailing absent-slot loop with:

```python
        for slot in range(len(self._state)):
            if slot not in present:
                for i in range(4):
                    st = self._state[slot][i]
                    st.qual = 0
                    if st.engaged:
                        st.engaged = False
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=0))
        return events
```

- [ ] **Step 4: Run the full test file to verify everything passes**

Run: `cd data_only_viz && uv run pytest tests/test_finger_strike.py -v`
Expected: ALL PASS — new debounce tests AND the pre-existing pinch tests (they use the default `debounce_frames=1`, i.e. no debounce).

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/finger_strike.py data_only_viz/tests/test_finger_strike.py
git commit -m "feat(pose): pinch engage debounce"
```

---

### Task 3: Env plumbing + docs

**Files:**
- Modify: `data_only_viz/action_head_pub.py:185-190` (`_init_finger_piano`)
- Modify: `CLAUDE.md` (repo root, env table after the `PINCH_REFRACTORY_MS` row)
- Test: `data_only_viz/tests/test_action_head_finger_emit.py`

**Interfaces:**
- Consumes: `PinchDetector` attrs `ext_ratio`, `ext_min`, `debounce_frames` (Task 1); existing test helper `_pub_envs(monkeypatch, finger_piano, pinch_enable)`.
- Produces: env vars `PINCH_EXT_RATIO` (default 1.35), `PINCH_EXT_MIN` (default 2), `PINCH_DEBOUNCE_FRAMES` (default 3) wired to the live detector.

- [ ] **Step 1: Write the failing tests**

Append to `data_only_viz/tests/test_action_head_finger_emit.py`:

```python
def test_pinch_gate_env_plumbing(monkeypatch):
    monkeypatch.setenv("PINCH_EXT_RATIO", "1.5")
    monkeypatch.setenv("PINCH_EXT_MIN", "3")
    monkeypatch.setenv("PINCH_DEBOUNCE_FRAMES", "5")
    pub = _pub_envs(monkeypatch, finger_piano="0", pinch_enable="1")
    assert pub._pinch_det.ext_ratio == 1.5
    assert pub._pinch_det.ext_min == 3
    assert pub._pinch_det.debounce_frames == 5


def test_pinch_gate_env_defaults_are_strict(monkeypatch):
    # Live defaults: gate ON (2 extended fingers) + 3-frame debounce.
    for k in ("PINCH_EXT_RATIO", "PINCH_EXT_MIN", "PINCH_DEBOUNCE_FRAMES"):
        monkeypatch.delenv(k, raising=False)
    pub = _pub_envs(monkeypatch, finger_piano="0", pinch_enable="1")
    assert pub._pinch_det.ext_ratio == 1.35
    assert pub._pinch_det.ext_min == 2
    assert pub._pinch_det.debounce_frames == 3
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_finger_emit.py -v`
Expected: both new tests FAIL (`ext_min == 0`, `debounce_frames == 1` — constructor defaults); pre-existing tests PASS.

- [ ] **Step 3: Wire the env vars**

In `data_only_viz/action_head_pub.py`, replace the `self._pinch_det = PinchDetector(...)` call with:

```python
        self._pinch_det = PinchDetector(
            ratio_on=float(os.environ.get("PINCH_RATIO_ON", "0.45")),
            ratio_off=float(os.environ.get("PINCH_RATIO_OFF", "0.65")),
            refractory_ms=float(os.environ.get("PINCH_REFRACTORY_MS", "250")),
            margin=float(os.environ.get("PINCH_MARGIN", "0.20")),
            ext_ratio=float(os.environ.get("PINCH_EXT_RATIO", "1.35")),
            ext_min=int(os.environ.get("PINCH_EXT_MIN", "2")),
            debounce_frames=int(os.environ.get("PINCH_DEBOUNCE_FRAMES", "3")),
        )
```

- [ ] **Step 4: Run both test files to verify everything passes**

Run: `cd data_only_viz && uv run pytest tests/test_action_head_finger_emit.py tests/test_finger_strike.py -v`
Expected: ALL PASS.

- [ ] **Step 5: Document the env vars**

In the repo-root `CLAUDE.md` env table, insert after the `PINCH_REFRACTORY_MS` row:

```markdown
| `PINCH_EXT_RATIO` | `1.35` | tip-to-wrist distance / hand size above which a finger counts as extended (open-hand pinch gate) |
| `PINCH_EXT_MIN` | `2` | min extended non-pinching fingers required for a pinch to engage; `0` disables the open-hand gate |
| `PINCH_DEBOUNCE_FRAMES` | `3` | consecutive qualifying frames before a pinch engage fires (release stays immediate); `1` disables |
```

- [ ] **Step 6: Commit**

```bash
git add data_only_viz/action_head_pub.py data_only_viz/tests/test_action_head_finger_emit.py CLAUDE.md
git commit -m "feat(pose): pinch gate env vars + docs"
```

---

## After the plan (manual, NOT tasks)

1. Deploy to macm1 (pull) and run a live session with `PINCH_ENABLE=1`:
   full-body play must produce zero false engages; deliberate open-hand
   pinches must still fire.
2. Only after the user confirms live: flip `PINCH_ENABLE` default to `1`
   in `launcher/concert/launch_concert.sh` (separate commit).
