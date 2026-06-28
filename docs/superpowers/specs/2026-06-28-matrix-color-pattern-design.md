# Matrix per-color pattern restructure — design

Date: 2026-06-28
Status: approved (brainstorming), pending implementation plan
Scope: `sound_algo/data_only/matrix.scd` + `web_realart/public/control/`
Builds on / restructures: the complete per-instrument editor
(`2026-06-28-matrix-instrument-editor-design.md`), already on main.

## Goal

Make each matrix color (1-6) a fully autonomous pattern bundling its own
instrument, 16-step note+velocity sequence, capture effect, and pose binding. The
matrix grid cell selects which color/pattern plays for a voice at each bar. The
per-voice effect (mod) and pose bindings — just built — move to per-color. The
editor modal is reorganized around a color selector + a single per-color pattern
editor.

## Decisions (from brainstorming)

- 1 color = 1 pattern = { instrument, sequence, effect, pose }, independent per
  color. The grid cell's color is the live selection.
- `effect` (capture mod) and `pose` bindings move from per-voice
  (`~matMod[vi]`/`~matPoseBindings[vi]`) to per-color (fields of
  `~matColorDefs[vi][color]`).
- Modal is **color-centric**: a color selector (1-6) at the top, then one pattern
  editor for the selected color (instrument · variation · this color's 16-step
  sequence · effect · pose).
- Backward-compat: legacy `.matrix` files with top-level per-voice `mods`/
  `poseBindings` migrate on load (a voice's mod copied to all 6 colors; each pose
  binding routed into its color's pose list). New saves nest mod+pose in colorDefs.

## Data model

`~matColorDefs[vi][color]` (an Event) gains two fields beyond the existing
`inst, stretch, octave, amp, cutoff, pan, steps`:
- `mod`: `(source: Sym, target: Sym, depth: Float)` or `nil` (no effect).
- `pose`: an Array of `(poseId: Sym, action: Sym)` (the color is implicit).

`~matMod` and `~matPoseBindings` (per-voice) are REMOVED. The instrument remains
`spec[\inst] ? ~matInstruments[vi]` (per-color override, else the voice default).

## Engine (matrix.scd)

- `~matVariationOverlay` and `~matColorStepPattern` read the mod from `spec[\mod]`
  (the color def) instead of `~matMod[vi]`. The mod→key logic (cutoff/pan/amp via
  `~matModSourceVal`, neutral cutoff, depth) is unchanged except its source.
  Factor the mod-key builder into a helper `~matModPairs.(name, spec, volOf)` so
  both the overlay and the stepped pattern share it (DRY — today it is duplicated).
- `~matPoseFire.(poseId)` iterates voices × colors × that color's `pose` list:
  on a match, `\trigger` re-sources the voice to that color now; `\gate` toggles
  the voice's Pdef. (The binding's color is the color it lives under.)
- `~matSetColorMod.(vi, color, source, target, depth)` sets/clears
  `~matColorDefs[vi][color][\mod]` (validate target ∈ `~matModTargets[name]`,
  source ∈ `~matModSources`; `\none` clears), re-source, echo.
- `~matSetColorPose.(vi, color, poseId, action)` adds/replaces a pose binding in
  that color (dedup by poseId; empty poseId clears), echo.
- Pushes: extend the per-voice editor push so the modal gets each color's mod +
  pose. Add `~matColorModPush.(vi, color)` → `/matrix/colormod vi color source
  target depth`; `~matColorPosePush.(vi, color)` → `/matrix/colorpose vi color n
  <poseId,action>*`. `/matrix/colordefs/get vi` triggers colordefs + steps + mod +
  pose for all 6 colors.

## OSC contract

| address | dir | payload | meaning |
|---|---|---|---|
| `/matrix/colormod` | in/out | vi color source target depth | set/echo a color's effect |
| `/matrix/colorpose` | in | vi color poseId action | set a color's pose binding |
| `/matrix/colorpose` | out | vi color n (poseId,action)* | echo a color's pose list |
| `/matrix/pose` | in | poseId | fire (unchanged) |

The old `/matrix/mod`, `/matrix/posebind`, `/matrix/mods`, `/matrix/poses` (per-voice)
are removed. `/matrix/instrument`, `/matrix/colordef`, `/matrix/step`,
`/matrix/audition`, `/matrix/colordefs|steps/get` stay.

## Web (color-centric modal)

Replace the tabbed modal with a color-selector + per-color pattern editor:
- A row of 6 color buttons (tinted m1-m6); selecting one sets `cdColor`.
- The pattern editor for `cdColor` shows, stacked:
  - Instrument `<select>` (curated; sets that color's `inst`).
  - Variation: stretch / octave / amp / cutoff / pan (filter/pan voices only).
  - Sequence: a single 16-step row (this color's steps; click toggle, wheel degree,
    shift+wheel velocity — same interactions as the current grid, one row).
  - Effect: source / target / depth selects → `/matrix/colormod vi cdColor ...`.
  - Pose: poseId input + action + add; list of this color's bindings →
    `/matrix/colorpose vi cdColor ...`.
- State: `matColorDefs[vi][color]` (JS mirror) gains `mod` + `pose`. WS handlers for
  `/matrix/colormod`, `/matrix/colorpose` update state + re-render if open on that
  voice/color. AUDITION toggle (cycle 6 colors) stays.
- The `matSteps`/`matMod`/`matPoses` JS arrays are folded into `matColorDefs`'
  per-color `mod`/`pose`/`steps` (single source), persisted under `cdef`.

## Persistence

`.matrix` colorDefs Events now carry `mod` + `pose` (round-trip via
`asCompileString`). Extend `~matLoadFile`'s colorDefs allow-list to copy `mod`
(Event) and `pose` (Array). Migration: when a legacy Event has top-level `mods`
(16 per-voice) → copy each voice's mod into all 6 of its colors' `mod`; top-level
`poseBindings` (16 lists of (poseId,action,color)) → route each into
`colorDefs[vi][color][\pose]`. localStorage `cdef` carries mod+pose per color;
drop the separate `steps`/`pose`/`mod` localStorage keys (folded into `cdef`).

## Error handling / robustness

- Setters validate ranges and membership (target ∈ voice's `~matModTargets`,
  source ∈ `~matModSources`); invalid → ignored.
- Empty `mod`/`pose` (nil / empty list) = no effect / no binding — default state.
- `/matrix/pose` unknown id → no match → no-op.
- nil-guarded, idempotent reload; defaults reproduce current behavior (empty
  mod/pose ⇒ same as today's no-mod path).

## Testing

- **SC** (`test_matrix.scd`, headless, P:0 B:0):
  - colorDefs default `mod` nil + `pose` empty; `~matSetColorMod`/`~matSetColorPose`
    set + validate + echo; a stepped/overlay pattern reads the color's mod (cutoff
    target → `\cutoff` key present when set, absent when nil).
  - `~matPoseFire` fires a per-color binding (trigger re-sources the right color);
    unknown id no-op.
  - persistence round-trip of per-color mod+pose; legacy per-voice `mods`/
    `poseBindings` migrate into colorDefs on load.
- **Web**: `node --check`; manual — color selector switches the pattern editor;
  editing a color's instrument/variation/sequence/effect/pose round-trips and only
  affects that color; audition cycles colors.

## Out of scope

- Pose recognition (still consumes `/matrix/pose <poseId>`).
- Per-step effect/pose (effect+pose are per-color, not per-step); variable step
  counts; cross-color linking.
