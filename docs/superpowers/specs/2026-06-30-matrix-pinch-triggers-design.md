# Matrix global actions — pinch triggers (replace open/close hand)

**Date**: 2026-06-30
**Status**: design approved (decisions made), pending spec review
**Scope**: `sound_algo/data_only/matrix.scd`, `sound_algo/data_only/matrix_presets/generate_presets.py`,
`web_realart/public/control/` (panel), `launcher/concert/launch_concert.sh`. No `data_only_viz` code change.

## Context

Phases 1-2 (shipped) trigger global matrix actions from **open/closed hand**
(`~matHandFlip`, openness hysteresis) over 4 slots (LH/RH × open/closed), with
per-morceau editable mapping + a transient engine + an action vocabulary +
threshold/duration/kept-voices settings. The user wants the trigger to be
**finger pinches** instead — 8 triggers (4 per hand) — replacing open/close.

## Decisions (from brainstorming)

- **Trigger** = finger pinch (thumb↔finger), via the existing `PinchDetector`
  in `data_only_viz` (`/pose/pinch [pid, hand, finger]`, hand 0/1 = screen
  L/R, finger 1-4 = index/middle/ring/pinky). **8 slots** = MG/MD × 4 fingers.
- **Replace** open/close entirely: remove `~matHandFlip` global triggering +
  the open/close threshold settings.
- **Pinch sensitivity** = env `PINCH_RATIO_ON` / `PINCH_RATIO_OFF` (set at
  launch; no runtime slider, no `data_only_viz` code change).
- **Activation**: `FINGER_PIANO=1` in `launch_concert.sh` (enables the pinch
  detector; also enables the air-piano finger-strike detector, inert because
  no voice has a finger binding by default).
- Everything else kept: transient engine, action vocabulary, transient
  duration + breakdown kept-voices settings, per-morceau mapping, save/load.
- The Phase-3 matrix tempo slider rides along (one panel update, one deploy).

## Design

### Slot model
8 slots, index = `hand * 4 + (finger - 1)`:
`0..3` = MG index/majeur/annulaire/auriculaire, `4..7` = MD index/.../auriculaire.
`~matGlobalActions` grows from 4 to 8 elements.

**Default mapping** (a spread of the vocabulary; user-adjustable):
MG = `fill, drop, breakdown, evolve` ; MD = `muteDrums, muteMelo, washReverb, next`
→ `[\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next]`.

### SC engine (`matrix.scd`)
- **Pinch → global fire**: extend the existing `/pose/pinch` OSCdef
  (`\mat_ev_pinch`, which already fires per-voice `~matPoseFire`) to ALSO map
  `(hand, finger)` → slot `0..7` and call `~matFireGlobal.(slot)`. Per-voice
  pinch bindings keep working (unchanged); the global fire is additive.
- **Remove open/close global triggering**: drop the two `~matHandFlip` calls
  from the `/pose/hands` OSCdef. Remove `~matHandFlip` + `~matHandState`
  (now dead). `/pose/hands` still writes the modulation cache (`lOpen`/`rOpen`
  etc. stay available as MOD sources in the per-voice editor — untouched).
- **Settings trim**: `~matGlobalSettings` keeps `transientBars` +
  `breakdownKeep`; drop `openThresh`/`closeThresh`. Update
  `~matGlobalSettingsPush`, the `/matrix/globalsettings` set OSCdef, save/load,
  and the generator literal accordingly (arg layout becomes
  `[transientBars, keepN, keep0..]`).
- **`/matrix/globalaction` slot range** 0-3 → 0-7. `~matGlobalActionsPush`
  pushes 8.
- Save/load: `globalActions` is now 8 symbols; default 8-element on legacy.

### Generator (`generate_presets.py`)
- `globalActions` literal → 8 symbols (the default above).
- `globalSettings` literal → `( 'transientBars': 1, 'breakdownKeep': [ \kick, \sub ] )`
  (drop the two thresholds).

### Web (`matrix-state.js` + `morceau-panel.js`)
- `GLOBAL_SLOTS` → 8 entries: `Pince MG index / majeur / annulaire / auriculaire`,
  then `Pince MD …`. `matGlobalActions` default → 8 elements.
- `matGlobalSettings` → `{ transientBars, breakdownKeep }` (drop thresholds);
  `parseGlobalSettings`/`sendSettings` follow the new arg layout.
- Réglages group: remove the two threshold sliders; keep the transient-duration
  slider + the kept-voices grid.
- Add the **matrix tempo slider** (`#matrix-bpm` → `/matrix/bpm`, from Phase 3).

### Launcher (`launch_concert.sh`)
- `export FINGER_PIANO=1` (and optionally `PINCH_RATIO_ON`/`PINCH_RATIO_OFF`
  defaults) so the pose pipeline emits `/pose/pinch`.

## Testing

- **SC** (`test_global_actions.scd`): replace the open/close harness groups
  (G, J open/close part) with a pinch-fire group — feed a synthetic
  `/pose/pinch [pid, hand, finger]` (via the OSCdef func) and assert the
  mapped slot's action fired (transient kind / loaded name); assert slot index
  math `hand*4+(finger-1)`; settings save/load now round-trips
  `transientBars`/`breakdownKeep` only.
- **Python** (`test_global_actions.py`): `globalActions` = 8 symbols literal;
  `globalSettings` literal without thresholds; 84/84.
- **Web** (`matrix-state.test.mjs`): `GLOBAL_SLOTS` length 8 + labels;
  default 8-element mapping; `parseGlobalSettings` new layout.
- **Live smoke**: `FINGER_PIANO=1`, pinch each finger L/R → the mapped global
  action fires; re-map a slot + save/reload; tempo slider works; open/close no
  longer triggers anything.

## Out of scope

- Runtime pinch-sensitivity control (env only).
- Per-voice pinch bindings (unchanged; still available in the voice editor).
- Removing `lOpen`/`rOpen` as per-voice MOD sources (kept).

## Decided defaults

- 8 slots, replace open/close, env sensitivity, FINGER_PIANO=1, default mapping
  fill/drop/breakdown/evolve · muteDrums/muteMelo/washReverb/next.
