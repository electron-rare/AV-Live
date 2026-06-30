# Matrix fist-held gestures — pointG (reload current) / pointD (next)

**Date**: 2026-06-30
**Status**: design approved, pending spec review
**Scope**: `sound_algo/data_only/matrix.scd`, `sound_algo/data_only/matrix_presets/generate_presets.py`,
`web_realart/public/control/{js/matrix-state.js,js/morceau-panel.js,control.css}`. No `data_only_viz`
change (openness `lOpen`/`rOpen` already arrives via `/pose/hands`). No launcher change.

## Context

After the pinch refinements, the user wants two more gestures driven by a HELD
CLOSED FIST (one per hand): left fist held → **charger** (reload the current
matrix), right fist held → **suivant** (next preset). A fist = low hand
openness; the openness signal already flows into the engine, so detection +
timing live entirely in SC, reusing the pinch hold mechanic.

## Decisions (from brainstorming)

- **Gesture** = closed fist (low openness) HELD ≥ the hold duration.
- **pointG** (left fist held) → reload the current matrix from disk.
- **pointD** (right fist held) → `~matNextPreset` (next preset, sorted order).
- **Detection** = SC-side from `lOpen`/`rOpen` (in `~matModCache`, written by the
  `/pose/hands` OSCdef). Fist engage when openness ≤ `~matFistThresh`, release
  when ≥ `~matFistThresh + 0.15` (hysteresis). Presence-guarded (`x > 0.001`),
  so an absent hand (openness 0) does NOT read as a fist.
- **Hold** reuses `~matPinchHoldMs` (the existing "Maintien" slider) — one hold
  duration for pinch + fist.
- **Fist sensitivity** = `~matFistThresh`, a LIVE menu slider (default 0.15),
  saved per morceau.
- **Progress** = `/matrix/fistprogress [hand, 0..1]` → two menu indicators
  ("Poing G → charger", "Poing D → suivant") fill like the pinch cells.

## Design

### SC engine (matrix.scd)
- State: `~matFistThresh` (default 0.15), `~matFistState` (Array[2] of
  `\unknown`/`\fist`/`\open`), `~matFistHeld` (Array[2] engage-time or nil),
  `~matFistFired` (Array[2] bool).
- `~matFistEdge.(hand, x, openness)` (called from the `/pose/hands` OSCdef for
  L (hand 0: `x=msg[2]`, `openness=msg[4]`) and R (hand 1: `x=msg[6]`,
  `openness=msg[8]`)):
  - `present = x > 0.001`. If absent → state `\unknown`, clear `~matFistHeld[hand]`.
  - fist if `openness <= ~matFistThresh`; open if `openness >= ~matFistThresh + 0.15`;
    else keep previous.
  - on `\open`→`\fist` edge: `~matFistHeld[hand] = Main.elapsedTime`,
    `~matFistFired[hand] = false`.
  - on `\fist`→`\open` (or disappear): `~matFistHeld[hand] = nil`,
    `~matFistFired[hand] = false`, emit `/matrix/fistprogress [hand, 0]`.
- `~matFistTick` (called by the existing pinch poller alongside `~matPinchTick`,
  30 Hz): for each held hand, `prog = ((now - held)*1000 / ~matPinchHoldMs).clip(0,1)`,
  emit `/matrix/fistprogress [hand, prog]`; when `prog>=1` and not fired, set
  fired + fire: hand 0 → `~matFistReloadCurrent` (`~matCurrentName.notNil` →
  `~matLoad(~matCurrentName)` + `/matrix/loaded`); hand 1 → `~matNextPreset`.
- Routes: `/matrix/fisthresh [v]` set (clip 0.05..0.5) + echo, `/matrix/fisthresh/get`
  push. `fistThresh` saved per `.matrix` (top-level, default 0.15 on legacy).

### Generator
- `to_sc` emits `'fistThresh': 0.15` (top-level, after `pinchHoldMs`).

### Web
- `matrix-state.js`: `matFistThresh` (default 0.15) + setter + persistence (`fth`).
- `morceau-panel.js`: a "Sensibilité poing" slider (0.05..0.5 → `/matrix/fisthresh`,
  synced); two fist indicator rows ("Poing G → charger", "Poing D → suivant")
  with a progress fill driven by `on("/matrix/fistprogress")`.
- `control.css`: fist-indicator + fill styles.

## Testing

- **SC** (`test_global_actions.scd`, new group Q): fist engage records hold
  (no immediate fire); `~matFistTick` past hold fires the right action (hand 0
  reload-current via a stubbed `~matLoad` capturing the name = `~matCurrentName`;
  hand 1 → `~matNextPreset`); release before hold cancels; openness above the
  release threshold releases; `/matrix/fisthresh` clamps + sets; `fistThresh`
  save/load roundtrips; an ABSENT hand (x=0, openness 0) does NOT engage a fist.
- **Python** (`test_global_actions.py`): every `.matrix` carries `fistThresh: 0.15`.
- **Web** (`matrix-state.test.mjs`): `matFistThresh` default + persistence.
- **Live smoke**: hold a left fist → "Poing G" fills then reloads the current
  morceau; right fist → next preset; the sensitivity slider changes how easily a
  fist registers; an open/quick fist does nothing; absent hands never trigger.

## Out of scope

- A separate fist HOLD duration (reuses `~matPinchHoldMs`).
- Per-hand fist sensitivity (one global `~matFistThresh`).
- Making pointG/pointD remappable (fixed: G=reload-current, D=next).

## Decided defaults

- Fist threshold 0.15 (live slider, saved), hysteresis +0.15; hold reuses the
  pinch hold; G=reload-current, D=next; progress indicators in the menu.
