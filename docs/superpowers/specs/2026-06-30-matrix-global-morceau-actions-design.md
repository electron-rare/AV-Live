# Matrix global morceau actions — hand-gesture global actions + "Morceau" panel

**Date**: 2026-06-30
**Status**: design approved, pending plan
**Scope**: `sound_algo/data_only/matrix.scd` (engine + detection + storage + OSC),
`sound_algo/data_only/matrix_presets/generate_presets.py` (emit defaults + test),
`web_realart/public/control/` (bottom "Morceau" panel + persistence). No
`data_only_viz` changes.

## Context

The matrix has per-voice modulation (continuous, `default_mods`) and per-voice
pose bindings (`~matVoicePoses`, actions `\trigger`/`\gate`). The user wants a
distinct, **morceau-level** layer: opening/closing a hand fires a **global
action on the whole matrix** (not per-voice), with the gesture→action mapping
**editable and saved per morceau** via a new menu at the bottom of the matrix
editor.

This is NOT a removal from the instrument editor (the per-voice editor and its
`lOpen`/`rOpen` mod sources + `pinch*` pose choices stay). It is a new global
layer added "into the matrix patterns".

## Decisions (from brainstorming)

- **Effect scope**: whole morceau (global), not per-voice.
- **Gestures**: 4 slots = screen-left/right hand × open/closed.
- **Default semantics**: LH open=fill, LH closed=drop, RH open=relance+evolve,
  RH closed=breakdown.
- **Timing**: immediate (fire on the open/closed flip, no bar quantization).
- **Duration**: momentary — transient effects auto-revert after N bars
  (default 1 measure); one-shots act once.
- **Detection**: SC-side, derived from the `lOpen`/`rOpen` openness already in
  `/pose/hands` (no `data_only_viz` change, no new OSC route inbound).
- **Mapping + settings**: editable, saved per `.matrix`, surfaced in a new
  bottom "Morceau" panel. Menu content = global controls + gesture mappings +
  tuning settings (panel option 2+3+4).
- **Delivery**: 3 phases, each testable/deployable.

## `/pose/hands` payload (already received by matrix.scd)

`/pose/hands [0, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]`
→ `lx=msg[2]`, `lopen=msg[4]`, `rx=msg[6]`, `ropen=msg[8]`.
An absent hand emits `[0,0,0,0]` for its slot (`_hand_slot(None)` in
`pose_bridge.py`), so **`x == 0.0` ⟺ hand absent**; a present hand always has
`x > 0`. `openness` is normalised 0..1 (0 = fist, 1 = open).

## Design

### 1. Hand open/closed detection (matrix.scd, in the `/pose/hands` OSCdef)

Per hand slot (L: `lx`,`lopen`; R: `rx`,`ropen`):

- `present = x > 0.001`.
- Hysteresis on openness → state:
  - `\open`  if `openness >= openThresh` (default 0.65)
  - `\closed` if `openness <= closeThresh` (default 0.30)
  - deadband (between thresholds) → keep previous state.
- **Flip = fire**: when a present hand transitions between two *established*
  present states (`\open`↔`\closed`), fire the slot's action immediately.
  - First established state on (re)appearance sets the baseline only — no fire.
  - Hand disappearing (`present` false) resets that hand's state to `\unknown`
    (no fire on disappear; next appearance re-baselines).

Per-hand state kept in `~matHandState[\L]`/`~matHandState[\R]` (`\unknown` /
`\open` / `\closed`). Slot index: `0=LH open, 1=LH closed, 2=RH open, 3=RH closed`.

### 2. `~matTransient` — the momentary-override primitive

A single global override active for `transientBars` bars after a gesture, then
auto-expires. Held as an Event:
`~matTransient = (kind: \fill, voices: [...], untilBeat: <clock beats>)` or
`nil` when inactive.

The per-bar voice sourcing in `~matPlay` (and `~matVariation`) consults
`~matTransient` when building each voice's pattern for the current bar:

- expired (`clock.beats >= untilBeat`) → clear to `nil`, source normally.
- `\fill` → source every active voice from colour 6.
- `\drop` → all voices silent.
- `\breakdown` → all voices silent except `voices` (kept set).
- `\muteDrums` / `\muteMelo` → voices in that `VOICE_CLASS` group silent.
- `\doubleTime` → multiply each voice's `stretch` by 0.5 in `~matVariation`.
- `\halfTime` → multiply `stretch` by 2.0.
- `\washReverb` → boost every voice's `rev` send (additive, clamped).

Setting a transient: `~matSetTransient.(kind, voices)` stamps
`untilBeat = clock.beats + (transientBars * beatsPerBar)` and re-sources playing
voices immediately (immediate effect, the chosen timing).

### 3. Action vocabulary (assignable to the 4 slots)

| symbol | label (fr) | effect | type |
|--------|-----------|--------|------|
| `none` | aucune | — | — |
| `fill` | fill | all voices → colour 6 | transient |
| `drop` | drop | all voices silent | transient |
| `breakdown` | breakdown | all silent except kept voices | transient |
| `evolve` | relance + evolve | re-source all + 1 evolve mutation | one-shot |
| `muteDrums` | mute drums | drum-class voices silent | transient |
| `muteMelo` | mute mélo | melodic-class voices silent | transient |
| `doubleTime` | double-time | global stretch ×0.5 | transient |
| `halfTime` | half-time | global stretch ×2 | transient |
| `washReverb` | wash reverb | boost rev on all voices | transient |
| `next` | suivant | load next preset (list order) now | one-shot |

One-shots (`evolve`, `next`) do not use `~matTransient`; they call the existing
`~matEvolveOnce`/load path immediately.

### 4. Settings (per morceau)

`~matGlobalSettings` Event:
- `openThresh` (default 0.65), `closeThresh` (default 0.30) — detection hysteresis.
- `transientBars` (default 1) — transient duration.
- `breakdownKeep` (default `[\kick, \sub]`) — voices kept during `breakdown`.

### 5. Mapping storage + persistence

- `~matGlobalActions` = 4-element Array of action symbols (slot order above).
  Default: `[\fill, \drop, \evolve, \breakdown]`.
- OSC:
  - `/matrix/globalaction [slot, actionSym]` → set one slot; echo same address.
  - `/matrix/globalaction/get` → push all 4 (`/matrix/globalaction slot sym` ×4).
  - `/matrix/globalsettings [openThresh, closeThresh, transientBars, keepN, keep0..]`
    → set; echo same address. `/matrix/globalsettings/get` → push.
- **Saved per `.matrix`**: new fields `globalActions: [ \fill, \drop, \evolve,
  \breakdown ]` and `globalSettings: (openThresh: 0.65, closeThresh: 0.30,
  transientBars: 1, breakdownKeep: [\kick, \sub])`. `~matLoadFile` parses them
  with the listed defaults when absent (back-compat with old presets);
  `~matSave` writes them; on load, SC pushes both to the UI.
- `generate_presets.py` emits both fields (defaults) into every `.matrix`.
- Web: `matrix-state.js` holds `matGlobalActions` + `matGlobalSettings`,
  persisted in the existing localStorage blob.

### 6. Web "Morceau" panel (bottom of the matrix editor, collapsible)

New module `web_realart/public/control/js/morceau-panel.js` + a container in
`index.html` + `control.css` styles. Three groups:

1. **Global** — evolve on/off + rate, full-loop, tempo, charger-suivant.
   Consolidates the existing matrix buttons (`#matrix-evolve`,
   `#matrix-evolve-rate`, `#matrix-loop-full`, `#matrix-loadnext`) and the
   tempo control into the panel. (Phase 3.)
2. **Gestes mains** — 4 dropdowns (MG ouverte / MG fermée / MD ouverte / MD
   fermée) → action from the vocabulary. `GLOBAL_ACTION_CHOICES` in
   `matrix-state.js`. Change → `/matrix/globalaction slot sym`; `on()` handler
   keeps dropdowns synced + persists.
3. **Réglages** — open/closed threshold sliders, transient-duration field,
   breakdown kept-voices multi-select. Change → `/matrix/globalsettings ...`.

Behaviour note surfaced in UI help text: `lOpen`/`rOpen` are screen-left /
screen-right hands (matching existing "Main G/D" labels). RH actions
(relance+evolve, breakdown) require **both hands visible** (a single hand is
always classified screen-left).

## Phasing

- **Phase 1 (core)** — detection (§1) + `~matTransient` (§2) + 4 core actions
  (fill, drop, breakdown, evolve) + `~matGlobalActions` storage + OSC
  get/set + save/load + `generate_presets.py` emit + the 4 gesture dropdowns in
  a minimal bottom panel. Default mapping live.
- **Phase 2 (vocabulary + settings)** — extended actions (muteDrums, muteMelo,
  doubleTime, halfTime, washReverb, next) + `~matGlobalSettings` (§4) + the
  Réglages group + settings persistence.
- **Phase 3 (full panel)** — consolidate existing global controls
  (evolve/rate, full-loop, charger-suivant) into the panel + add a matrix
  tempo route `/matrix/bpm` (none exists today) + tempo control in the panel.

Each phase ends green (tests + validate) and is deployed to macm1.

## Testing

- **Python** (`generate_presets.py`): assert every emitted `.matrix` contains
  `globalActions` (4 syms) and `globalSettings` with the documented defaults
  (extend `test_sections.py` or a new `test_global_actions.py`); deterministic
  regen; `validate_presets.scd` parses the new fields on 84/84.
- **SC** (`test_global_actions.scd`): feed synthetic `/pose/hands` sequences →
  assert flip detection (no fire on appear/disappear, fire on open↔closed),
  `~matSetTransient` apply + auto-expire, breakdown keeps only kept voices,
  mute-group counts, mapping + settings save/load roundtrip.
- **Web** (`web_realart/test/*.test.mjs`, pure logic): action-choice list,
  slot serialize/parse, settings parse/serialize, localStorage roundtrip.
- **Live smoke** (macm1): open/close each hand → hear fill/drop/breakdown/evolve
  (and Phase-2 actions); edit a slot in the panel → re-map takes effect; save a
  matrix, reload → mapping + settings preserved; old presets load with defaults.

## Out of scope

- Per-voice pose/mod editor changes (untouched).
- New gesture detection in `data_only_viz` (openness from `/pose/hands` suffices).
- Body-pose or finger global actions (only hand open/closed in this feature).
- Quantized/held-state variants (decided: immediate + momentary).
