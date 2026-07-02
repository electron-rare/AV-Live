# Hand Display Cleanup + Side Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove ghost/erratic/mesh artifacts from the hand overlay and add left/right front-view hand panels, so the operator sees exactly what the pinch detector sees.

**Architecture:** Fix the decode layer to stop discarding the Vision per-landmark confidence and per-hand chirality already on the wire; add pure geometry helpers in a new `hand_display.py` (plausibility gate, segment filter, panel mapping) consumed by `renderer.py`. Spec: `docs/superpowers/specs/2026-07-02-hand-display-cleanup-design.md`.

**Tech Stack:** Python 3.11, uv, pytest, Metal renderer (pyobjc) — helpers stay Metal-free.

## Global Constraints

- Python via `uv`; test command: `cd data_only_viz && uv run pytest tests/<file> -v`
- Commit subjects <= 50 chars, body <= 72, no AI attribution, no underscore in scope.
- `PoseKp.z` of iPhone hands keeps the raw wire value (finger-strike OSC reads z); confidence goes to `.c` clamped [0,1].
- Body and face rendering (skeleton + mesh) unchanged; only hands are touched.
- Defaults: conf_min=0.3, size_min=0.02, size_max=0.5, max_bone_ratio=1.2, panel side=30% of height, edge margin 2%, inner bbox margin 10%, left panel pid 5, right panel pid 6.
- MediaPipe hands (c==1.0 landmarks) must still draw exactly as before through the new gates (confidence filter neutral for them).

---

### Task A: Decode confidence + chirality

**Files:**
- Modify: `data_only_viz/iphone_usb_source.py` (`_make_point` ~line 36, `_decode_hands` ~line 41, TAG_HANDS handler ~line 176)
- Modify: `data_only_viz/state.py` (add field near `persons_hands_iphone` ~line 108)
- Test: `data_only_viz/tests/test_iphone_usb_source.py`

**Interfaces:**
- Produces: `_decode_hands(payload) -> tuple[list[list[PoseKp]], list[int]] | None` — returns `(hands, chirality)`; chirality[i] is 0=left, 1=right (wire byte 1=right, anything else left). Landmark `.c` = clamp(wire_z, 0, 1); `.z` = raw wire_z unchanged.
- Produces: `State.persons_hands_chirality: list[int]` (default empty list), written in the TAG_HANDS handler under `state.lock()` together with `persons_hands_iphone` (and `persons_hands` when `_write_hands`).

**Steps (TDD):**
- [ ] Write failing tests in `test_iphone_usb_source.py` (follow the file's existing payload-building style): (1) a 2-hand payload with chirality bytes 0 and 1 and distinct z values round-trips: `.c` clamped from z, `.z` raw, chirality `[0, 1]`; (2) z values outside [0,1] (e.g. -0.2, 1.7) clamp to 0.0/1.0 in `.c` but stay raw in `.z`; (3) count=0 payload returns `([], [])`; (4) empty payload returns `None`.
- [ ] Run: `cd data_only_viz && uv run pytest tests/test_iphone_usb_source.py -v` — new tests FAIL (current return is a bare list).
- [ ] Implement: `_decode_hands` reads the chirality byte instead of skipping it, builds the chirality list, returns the tuple; `_make_point` gains the conf argument or is inlined — landmarks get `c=clamp(z,0,1)`, `z=raw`. Update the TAG_HANDS handler for the new return shape and store `persons_hands_chirality` under the lock. Add the `State` field with a short comment (0=left, 1=right, aligned with persons_hands_iphone).
- [ ] Run the whole file: all PASS. Also run `uv run pytest tests/test_iphone_usb_reconnect.py -v` (imports the same module).
- [ ] Commit: `feat(pose): decode hand confidence + chirality`

---

### Task B: hand_display helpers + overlay cleanup

**Files:**
- Create: `data_only_viz/hand_display.py`
- Create: `data_only_viz/tests/test_hand_display.py`
- Modify: `data_only_viz/renderer.py` (`_update_skeleton` hands loops ~lines 397-402 and 415-421, `_update_mesh` hands block ~lines 510-517)

**Interfaces:**
- Produces in `hand_display.py` (pure functions over `list[PoseKp]`-like points with .x/.y/.c; no Metal, no numpy required):
  - `hand_size(kp) -> float` — hypot(wrist(0) ↔ middle-MCP(9)).
  - `hand_plausible(kp, conf_min=0.3, size_min=0.02, size_max=0.5) -> bool` — False if len(kp) < 21, size outside [size_min, size_max], or mean(.c) < conf_min.
  - `segment_ok(A, B, size, conf_min=0.3, max_bone_ratio=1.2) -> bool` — False if min(A.c, B.c) < conf_min or hypot(A↔B) > max_bone_ratio * size.
- Consumes: real `.c` values from Task A (MediaPipe hands keep c=1.0 → gates neutral).

**Steps (TDD):**
- [ ] Write failing tests in `test_hand_display.py` with tiny synthetic hands (21 PoseKp): plausible open hand accepted; tiny hand (size 0.005) rejected; huge hand (size 0.8) rejected; low-conf hand (all c=0.1) rejected; spike segment (bone 2× hand size) rejected by `segment_ok` while a normal bone passes; low-conf endpoint rejected.
- [ ] Run: FAIL (module missing). Implement `hand_display.py`. Run: PASS.
- [ ] Renderer: in the two hands loops of `_update_skeleton` (multi-person ~397 and single-person fallback ~415), skip the hand when `not hand_plausible(...)`, skip segments when `not segment_ok(A, B, size, ...)` (compute size once per hand), and push with `min(A.c, B.c)` instead of 1.0. In `_update_mesh`, delete the hands HAND_TRIANGLES block (and drop the now-unused HAND_TRIANGLES import if nothing else uses it).
- [ ] Run: `uv run pytest tests/test_hand_display.py tests/test_iphone_usb_source.py -v` — PASS. Renderer has no unit tests (Metal); it is validated live.
- [ ] Commit: `feat(viz): filter hand overlay artifacts`

---

### Task C: side panels front view

**Files:**
- Modify: `data_only_viz/hand_display.py` (add panel helpers)
- Modify: `data_only_viz/tests/test_hand_display.py`
- Modify: `data_only_viz/renderer.py` (`_update_skeleton`, after the existing overlay pushes)

**Interfaces:**
- Produces in `hand_display.py`:
  - `PANEL_SIDE = 0.30`, `PANEL_MARGIN = 0.02`, `PANEL_INNER = 0.10` (module constants).
  - `panel_rect(side: str, aspect: float) -> tuple[x0, y0, x1, y1]` — normalized [0,1] screen rect of the square panel ("left"/"right"); square in PIXELS: width = PANEL_SIDE / aspect where aspect = view width/height, height = PANEL_SIDE; vertically centered; anchored at PANEL_MARGIN from the edge.
  - `panel_segments(kp, side, bones, aspect, mirror=True) -> list[tuple[ax, ay, bx, by]]` — landmarks bbox-normalized (aspect preserved: uniform scale on the larger bbox dimension, centered), mapped into `panel_rect` shrunk by PANEL_INNER, X flipped when mirror; returns [] if `hand_plausible` fails.
  - `panel_frame(side, aspect) -> list[tuple[ax, ay, bx, by]]` — the rect's 4 border segments.
- Consumes: `state.persons_hands_chirality` (Task A) to route hands to panels; `push_seg`-style coordinates (normalized [0,1], y down) — the renderer converts to clip space WITHOUT applying the video mirror (panel coords are final screen coords).

**Steps (TDD):**
- [ ] Write failing tests: (1) `panel_rect("left", aspect=1.0)` anchors at x0=0.02 and is vertically centered; `"right"` at x1=0.98; (2) with aspect=16/9 the rect is square in pixels (width*aspect == height); (3) `panel_segments` output stays inside the inner rect and preserves aspect (a hand twice as tall as wide maps to segments twice as tall as wide, in pixel space); (4) mirror=True flips X within the panel; (5) implausible hand -> []; (6) `panel_frame` returns 4 segments tracing the rect.
- [ ] Run: FAIL. Implement. Run: PASS.
- [ ] Renderer: in `_update_skeleton`, after the overlay section, add a panels section: read `persons_hands` + `persons_hands_chirality` (fallback: if chirality missing/misaligned, order plausible hands by screen cx — mirror-aware — first→left panel, second→right); for each side draw `panel_frame` (conf 1.0, pid 7) then `panel_segments` (conf 1.0, pid 5 left / 6 right) via a local `push_panel(ax, ay, bx, by, conf, pid)` that converts [0,1]→clip like `push_seg` but NEVER applies `mirror`. Compute `aspect` from `s.width / s.height` (guard height 0 → 1.0).
- [ ] Run: `uv run pytest tests/test_hand_display.py -v` — PASS.
- [ ] Commit: `feat(viz): left/right hand front-view panels`

---

## After the plan (manual)

Deploy to macm1 (pull + restart stack with PINCH_ENABLE=1 FINGER_DEBUG=1) and validate visually: skeleton still on video, no ghost hands / spikes / hand mesh, panels track each hand and go empty when the hand leaves.
