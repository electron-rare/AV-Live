# Matrix pinch refinements — decouple piano, 2-col menu, hold-to-fire + progress

**Date**: 2026-06-30
**Status**: design approved, pending spec review
**Scope**: `data_only_viz/{finger_strike.py,pose_bridge.py,action_head_pub.py}`,
`launcher/concert/launch_concert.sh`, `sound_algo/data_only/matrix.scd`,
`sound_algo/data_only/matrix_presets/generate_presets.py`,
`web_realart/public/control/{js/matrix-state.js,js/morceau-panel.js,index.html,control.css}`.

## Context

The pinch-triggered global actions shipped, but live use revealed four needs:
the air-piano finger-strike rides along with the pinch detector; the 8 slots
should read as two hand columns; a quick accidental pinch fires immediately;
and there is no detection feedback in the menu.

## Decisions (from brainstorming)

- **Decouple**: a new `PINCH_ENABLE` env gates ONLY pinch; the air-piano
  finger-strike stays on `FINGER_PIANO` (off by default). (Already coded.)
- **2-column menu**: gesture slots laid out as a left column (MG, slots 0-3) and
  a right column (MD, slots 4-7).
- **Hold-to-fire, timed in SC**: a pinch must be HELD ≥ `~matPinchHoldMs` to
  fire its global action; released sooner → nothing. `data_only_viz` emits pinch
  ENGAGE/RELEASE edges; the SC engine does the timing (web↔SC channel already
  exists, plus a clock). Hold duration is a LIVE menu slider.
- **Progress indicator**: while a pinch is held, the slot's menu cell fills
  0→1; full → fires (then clears on release).

## Design

### data_only_viz — emit pinch edges (not just engage)
- `PinchEvent` gains `state: int` (1 = engage, 0 = release).
- `PinchDetector.step`: emit `PinchEvent(hand, finger, state=1)` on the engage
  edge (existing) AND `PinchEvent(hand, finger, state=0)` on the release edge
  (the `ratio > ratio_off` branch). One event per transition.
- `pose_bridge.send_pinch`: `/pose/pinch [0, hand, finger, state]`.
- `action_head_pub._emit_pinch`: gated by `_pinch_enabled` (PINCH_ENABLE) —
  already done; it forwards every event (engage + release) unchanged.

### launcher
- `export PINCH_ENABLE="${PINCH_ENABLE:-1}"` (replacing `FINGER_PIANO=1`; the
  air-piano stays off).

### SC engine (matrix.scd)
- Slot = `hand*4 + (finger-1)` (0..7), as today.
- `~matPinchHoldMs` (default 300), `~matPinchHeld` (Array[8] of engage-time or
  nil), `~matPinchFired` (Array[8] bool).
- `\mat_ev_pinch` reworked: read `state = msg[4]`.
  - `state == 1` (engage): `~matPinchHeld[slot] = Main.elapsedTime`,
    `~matPinchFired[slot] = false`; fire the per-voice binding immediately
    (`~matPoseFire(~matEventPinch(hand,finger))`, unchanged).
  - `state == 0` (release): clear `~matPinchHeld[slot] = nil`,
    `~matPinchFired[slot] = false`, emit `/matrix/pinchprogress [slot, 0]`.
- `~matPinchTick` (called ~30 Hz by a free-running `AppClock` routine started
  once at load): for each held slot, `prog = ((now - held)*1000 / holdMs).clip(0,1)`,
  emit `/matrix/pinchprogress [slot, prog]`; when `prog >= 1` and not yet fired,
  set fired + `~matFireGlobal(slot)`.
- Hold-duration route: `/matrix/pinchhold [ms]` (set, clip 50..2000, echo) +
  `/matrix/pinchhold/get`. `~matPinchHoldMs` saved per `.matrix` (top-level
  field `pinchHoldMs`, default 300 on legacy) — generator emits it.

### Generator
- `to_sc` emits `'pinchHoldMs': 300` (a top-level field; separate from
  `globalSettings` to avoid re-churning that arg layout).

### Web
- `matrix-state.js`: `matPinchHoldMs` (default 300) + setter + persistence
  (`phms`); the 8 `GLOBAL_SLOTS` already exist.
- `index.html` + `control.css`: render the 8 gesture slots in TWO columns
  (left = slots 0-3, right = 4-7). Add a **hold-duration slider** (→
  `/matrix/pinchhold`). Each gesture cell carries a progress fill element.
- `morceau-panel.js`: lay the slots out as MG-column / MD-column; wire the hold
  slider; on `/matrix/pinchprogress [slot, prog]`, set that slot cell's fill
  width to `prog*100%` (and a brief "fired" flash at 1).

## Testing

- **data_only_viz** (`tests/test_action_head_finger_emit.py` + a pinch-edge
  test): `PINCH_ENABLE` gates pinch independent of `FINGER_PIANO` (done);
  `PinchDetector` emits a state=1 then a state=0 across an engage→release.
- **SC** (`test_global_actions.scd`): rework group P — engage (state 1) does
  NOT fire immediately; after the held time crosses `~matPinchHoldMs`,
  `~matPinchTick` fires the mapped action; release (state 0) before the hold
  fires nothing; `/matrix/pinchhold` updates `~matPinchHoldMs`; `pinchHoldMs`
  save/load roundtrips.
- **Python** (`test_global_actions.py`): every `.matrix` carries `pinchHoldMs: 300`.
- **Web** (`matrix-state.test.mjs`): `matPinchHoldMs` default + persistence.
- **Live smoke**: pinch-and-hold a finger → the cell fills, fires at the
  threshold; a quick pinch does nothing; the hold slider changes the required
  time live; air-piano silent; 2 columns MG/MD.

## Out of scope

- Live pinch SENSITIVITY (still env `PINCH_RATIO_ON/OFF`).
- Per-voice pinch bindings keep firing on engage (no hold) — the hold is for
  the global actions only.

## Decided defaults

- `PINCH_ENABLE=1` (air-piano off); hold 300 ms (live slider, saved per
  morceau); 2 columns MG/MD; progress fill per cell.
