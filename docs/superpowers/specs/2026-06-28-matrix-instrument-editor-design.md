# Matrix complete per-instrument editor — design

Date: 2026-06-28
Status: approved (brainstorming), pending implementation plan
Scope: `sound_algo/data_only/matrix.scd` + `web_realart/public/control/`
Builds on: instrument selection, capture→effect, and the color editor
(`2026-06-28-matrix-instrument-selection.md`, `-capture-effect-design.md`,
`-color-editor-design.md`) — all already implemented on main.

## Goal

Clicking a matrix voice opens ONE complete editor modal for that instrument,
consolidating every per-instrument control (today scattered across the row) and
adding two new capabilities: a per-color 16-step note+velocity sequencer that
replaces the voice's base pattern, and a panel to bind recognized poses to
instrument actions.

## Decisions (from brainstorming)

- ONE modal per instrument (not three subsystems), opened by clicking the voice.
  It has tabs: **Instrument · Colors · Sequence · Assignments · Poses**.
- Consolidation: the per-row sticky instrument `<select>` and the sticky-right
  capture-mod controls move INTO the modal; the matrix row keeps only its voice
  label (now the click target) + the 32 cells. This declutters the row.
- **Sequence** (new engine): per voice, per color (1-6), a 16-step sequence; each
  step is `(degree, velocity)` or a rest. When a color's sequence is non-empty it
  REPLACES the voice's base Pdef for that color; an empty sequence falls back to the
  base Pdef (backward-compatible — existing presets keep playing).
- Step notes are scale degrees (relative to the live harmony via `~lpNote`), not
  absolute pitches — consistent with the existing voices. 16 steps = 16th notes
  over one matrix bar (bar = `~matBeatsPerBar` = 4 beats).
- **Poses** (new): the panel binds a pose to an instrument action. The pose INPUT
  is an OSC contract `/matrix/pose <poseId>`; the pose RECOGNITION engine (named-pose
  detection in the capture pipeline) is an external/future dependency that plugs
  into this contract — OUT OF SCOPE here.
- One unified spec/plan (no phasing), per the user's choice.

## Architecture & data flow

```
Click voice label  ──/matrix/colordefs/get vi──→ SC pushes full per-voice state
        ▼                                          ─/matrix/instedit vi {...}→ web
Unified modal (tabs)                                      (bulk per-voice editor state)
  Instrument tab → /matrix/instrument vi inst
  Colors tab     → /matrix/colordef vi color field value
  Sequence tab   → /matrix/step vi color stepIdx degree velocity
  Assignments    → /matrix/mod vi source target depth
  Poses tab      → /matrix/posebind vi poseId action color
        ▼
matrix.scd: ~matColorDefs[vi][color] gains `steps` (16 x (degree, vel) or rest);
            ~matPoseBindings[vi] = list of (poseId, action, color)
        ▼
~matVariation(name, color, vi): if steps non-empty -> build a 16-step Pbind
  (\degree from steps, \amp = colorAmp * stepVel * volOf, \dur = bar/16, \freq via
   ~lpNote + freqRatio, + inst/cutoff/pan timbre); else -> current base+overlay path.
        ▼
OSCdef /matrix/pose <poseId> -> run bound actions (trigger color / gate voice)
```

## Components

### SC (`sound_algo/data_only/matrix.scd`)

- **Sequence state:** extend each `~matColorDefs[vi][color]` Event with a `steps`
  field — an Array of 16, each entry `nil` (rest) or an Event `(degree: Int,
  vel: Float 0..1)`. Default: all-nil (empty → base fallback). A helper
  `~matStepsEmpty.(steps)` returns true when every entry is nil.
- **Sequence engine:** `~matColorPattern.(name, vi, color, spec, volOf)` returns a
  Pbind built from `spec[\steps]` when non-empty:
  `Pbind(\instrument, <resolved inst>, \stepIdx, Pseq((0..15), inf),
   \degree, Pfunc { |e| steps[e[\stepIdx]] !? {_[\degree]} }, \type, Pfunc (rest when
   step nil), \amp, Pfunc { spec[\amp] * stepVel * volOf.value },
   \freq, Pfunc { ~lpNote.(degree, 0).midicps * (2**octave) }, \cutoff/\pan from spec,
   \dur, ~matBeatsPerBar/16)`. `~matVariation`/`~matVariationOverlay` call this when
  `spec[\steps]` is non-empty; otherwise the existing base-Pdef overlay path runs
  unchanged. `\matGlow` (per-note trigger) and the capture `modPairs` still apply.
- **Step set:** `~matSetStep.(vi, color, stepIdx, degree, vel)` validates ranges
  (vi/color/stepIdx; degree any Int or nil; vel 0..1), writes the step, re-sources,
  and echoes the voice's steps. `degree == \rest` / nil clears a step.
- **Pose bindings:** `~matPoseBindings = Array.fill(16, { [] })`; each entry a list
  of `(poseId: Sym, action: \trigger|\gate, color: Int)`.
  `~matSetPoseBind.(vi, poseId, action, color)` adds/replaces; an empty poseId clears.
  `OSCdef(\mat_pose)` on `/matrix/pose <poseId>` runs every matching binding:
  `\trigger` re-sources the voice to `color` for one bar; `\gate` toggles the voice.
- **Bulk editor push:** `~matInstEditPush.(vi)` sends `/matrix/instedit vi {...}` —
  one message carrying the voice's full editable state (instrument, 6 color defs +
  steps, mod binding, pose bindings) so the modal populates in one round-trip.
- **OSCdefs:** `/matrix/step`, `/matrix/posebind`, `/matrix/pose`,
  `/matrix/instedit/get`. Existing `/matrix/instrument`, `/matrix/colordef`,
  `/matrix/mod`, `/matrix/audition` stay (now driven from the modal).

### Bridge (`web_realart/server.js`)
- No change (`/matrix/*` already relayed).

### Web (`web_realart/public/control/`)
- **Row simplification:** remove the per-row `.minst` select, the `.mmod` controls,
  and the `.minst-edit` button (and their header spacers). The `.mvoice-label`
  becomes the click target that opens the unified modal; the row is label + 32 cells.
- **Unified modal** (replaces the color-editor modal): a tabbed panel for one voice
  with tabs Instrument / Colors / Sequence / Assignments / Poses:
  - *Instrument*: the curated `<select>` (+ a small "default" + the kit context).
  - *Colors*: the existing 6-color variation/sound editor (port from the color modal).
  - *Sequence*: a 6 x 16 grid (rows = colors 1-6, columns = 16 steps); each cell
    toggles a step and exposes degree (a small numeric/stepper) + velocity (a slider
    or click-height). Empty row = "base pattern" indicator.
  - *Assignments*: the source/target/depth mod controls (port from the row).
  - *Poses*: a small list — bind a poseId (text/select) to an action
    (trigger color N / gate) — "plug a pose in".
  - An AUDITION toggle (existing) cycles the 6 colors.
- **State:** the modal reads a single `matInstEdit[vi]` object hydrated from
  `/matrix/instedit`; control changes send the granular OSC messages above and update
  local state. Persisted in the matrix localStorage.

## Persistence

The `.matrix` Event already carries `grid, instruments, mods, colorDefs`. Extend:
- `colorDefs[vi][color]` gains `steps` (16 x (degree,vel)|rest) — already nested in
  the colorDef Event, so it round-trips via the existing colorDefs serialization.
- add `poseBindings` (16 x list of (poseId, action, color)).
Backward-compat: files without `steps`/`poseBindings` load with empty sequences
(→ base fallback) and no pose bindings. Web localStorage gains the same under `cdef`
+ a new `pose` key, tolerant of prior shapes.

## Error handling / robustness

- `~matSetStep`/`~matSetPoseBind`/`~matSetColorDef` validate ranges and ignore bad
  input (consistent with the existing setters).
- Empty sequence → base Pdef (never silent unless the base is). A sequence with all
  rests is treated as empty (base fallback) to avoid an accidentally-muted voice.
- `/matrix/pose` with an unknown poseId → no binding matches → no-op.
- nil-guarded, idempotent reload; defaults reproduce current behavior.

## Testing

- **SC** (`data_only/test/test_matrix.scd`, headless, P:0 B:0):
  - `steps` defaults empty; `~matStepsEmpty` true; `~matVariation` with empty steps
    still yields the base-equivalent event (parity).
  - `~matSetStep.(5, 2, 3, 7, 0.8)` writes the step; consuming the color's pattern
    yields the degree/vel at that step; a non-empty sequence produces a Pbind whose
    first non-rest event carries the expected `\degree`.
  - all-rest sequence → treated as empty (base fallback).
  - `~matSetPoseBind` + `/matrix/pose` runs the bound action; unknown poseId no-ops.
  - `~matInstEditPush` emits `/matrix/instedit` with the voice's full state.
  - persistence round-trip of steps + poseBindings; legacy files default cleanly.
- **Web**: `node --check`; manual — open the modal from a voice; each tab edits and
  round-trips; a sequence replaces the base on the next bar; audition cycles colors;
  a pose bind fires on `/matrix/pose`.

## Out of scope

- Pose RECOGNITION / named-pose detection in the capture pipeline (this spec only
  consumes `/matrix/pose <poseId>` — the detector plugs in later).
- Per-step micro-timing/ratchets/probability; variable step counts (fixed 16);
  cross-instrument sequence linking; MIDI export.
