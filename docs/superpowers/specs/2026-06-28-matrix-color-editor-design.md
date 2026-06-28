# Matrix per-instrument color editor — design

Date: 2026-06-28
Status: approved (brainstorming), pending implementation plan
Scope: `sound_algo/data_only/matrix.scd` + `web_realart/public/control/`
Sequencing: implement AFTER the instrument-selection and capture-effect plans
(`2026-06-28-matrix-instrument-selection.md`, `2026-06-28-matrix-capture-effect.md`),
because this generalizes the `~matVariation` engine those plans extend. See
Reconciliation.

## Goal

Open an editor for an instrument (a matrix voice) that exposes its 6 colors as 6
editable, auditionable "steps". For each color (1-6), the performer edits what that
color does for that voice — its variation (stretch/octave/amp) and its sound
(instrument + cutoff + pan, within what the synth exposes). The 32-bar grid stays
the sequencer; the editor only defines what the colors mean per voice.

## Decisions (from brainstorming)

- Unifies three asks: (1) edit the 6 colors' variation per voice, (2) lay the 6
  colors out as 6 "steps" with an audition loop, (3) edit the sound per color.
- The "6-step sequencer" = the 6 colors edited/auditioned in the popup, NOT an
  independent live loop and NOT nested sub-steps. The grid remains the sequencer.
- Color defs are **per voice**; defaults reproduce the current global
  `~matVariation` table, so behavior is unchanged until edited.
- Editable sound knobs are bounded to synth-exposed args: instrument, stretch,
  octave, amp, cutoff (filter voices), pan (pan voices). No envelope/drive editing
  (the `lp_*`/`do_*` synths do not expose those).

## Approach

**Per-voice color-def table replacing the global spec** — `~matColorDefs[vi]` holds
6 definitions (colors 1-6); `~matVariation` reads it instead of the hardcoded spec.
Defaults equal the current table → behavior-preserving. Single source of truth.

Rejected: global table + per-voice override merge (two-source complexity); full
synth-preset per color (synths expose too few args).

## Reconciliation with instrument-selection & capture-effect

This feature changes `~matVariation` from a global hardcoded spec to a per-voice
table. The instrument-selection plan (`~matInstruments[vi]`, `\instrument` overlay
key) and capture-effect plan (`~matMod[vi]`, mod target key) also extend
`~matVariation`. Implement this AFTER both; the unified `~matVariation.(name,
color, vi)` overlay then resolves, in order:

1. `\matGlow` (FIRST key — reads base velocity).
2. variation keys `\stretch`/`\octave`/`\amp` from `~matColorDefs[vi][color]`.
3. `\instrument` = `~matColorDefs[vi][color].inst ?? ~matInstruments[vi]`
   (per-color override wins; else the voice default from instrument-selection; else
   nil → base synth).
4. optional `\cutoff`/`\pan` from the color def (only for voices whose synth has
   the arg).
5. mod target key from `~matMod[vi]` (capture-effect), appended last; a mod `\amp`
   overrides the color-def `\amp`.

The instrument-selection plan's per-voice `<select>` stays as the voice default;
this editor adds per-color overrides + variation + audition.

## Data model

```
~matColorDefs[vi]  // Array of 7; index 0 unused; 1..6 = an Event:
  ( inst: nil|Symbol,   // nil = use ~matInstruments[vi] default
    stretch: Float, octave: Integer, amp: Float,
    cutoff: nil|Float,  // nil = synth default; only applied for filter voices
    pan: nil|Float )    // nil = synth default; only applied for pan voices
```

Default `~matColorDefs[vi]` for every voice (reproduces the current global table):

| color | stretch | octave | amp  |
|-------|---------|--------|------|
| 1 | 1.0 | 0 | 1.0 |
| 2 | 0.5 | 0 | 1.0 |
| 3 | 1.0 | 1 | 1.0 |
| 4 | 2.0 | 0 | 1.0 |
| 5 | 1.0 | -1 | 1.05 |
| 6 | 0.5 | 0 | 1.2 |

`inst`/`cutoff`/`pan` default nil. Filter voices (acid/arp/lead/stab/pad) accept
`cutoff`; pan voices (acid/arp/lead/stab) accept `pan` — reuse the capture-effect
`~matModTargets` membership to decide applicability.

## Components

### SC (`sound_algo/data_only/matrix.scd`)

- `~matColorDefs` — `Array.fill(~matVoices.size, { defaultColorDefs.copy })`,
  nil-guarded/idempotent; `defaultColorDefs` = the table above.
- `~matVariation` — read `~matColorDefs[vi][color]` for the variation/sound keys
  (replacing the hardcoded `spec`), preserving the overlay key order in
  Reconciliation. `color == 0` → nil (off) unchanged.
- `~matSetColorDef.(vi, color, field, value)` — validate (`field` in
  `[\inst,\stretch,\octave,\amp,\cutoff,\pan]`; `inst` in the voice's
  `~matInstChoices` or nil; `cutoff`/`pan` ignored for unsupported voices); set the
  field; force re-source; echo `/matrix/colordef`.
- `~matColorDefPush.(vi)` — send a voice's 6 color defs to surfaces
  (`/matrix/colordefs vi <flattened fields>`).
- `~matAudition.(vi, on)` — when on, a Routine on the shared clock cycles
  `color = 1..6` calling `~matApplyBar`-style application for that one voice (~1
  beat/step), so all 6 defs are heard in a loop; when off, stop the routine and the
  voice's Pdef. Preview only (does not touch the grid playhead).
- OSCdefs: `/matrix/colordef <vi> <color> <field> <value>`,
  `/matrix/colordefs/get <vi>` (→ `~matColorDefPush`), `/matrix/audition <vi> <on>`.

### Bridge (`web_realart/server.js`)
- No change (`/matrix/*` already relayed).

### Web (`web_realart/public/control/`)
- An "edit" button (⋯) next to each voice's instrument `<select>` (from the
  instrument-selection plan) opens a modal for that voice.
- Modal: voice name + 6 rows (colors 1-6, tinted with the `m1`-`m6` hue). Each row:
  instrument `<select>` (voice's curated choices), `stretch` (0.5/1/2 select),
  `octave` (-1/0/+1 select), `amp` range, and — for supported voices — `cutoff`
  range, `pan` range. A `colorDef` change sends `/matrix/colordef vi color field
  value` and updates local persisted state.
- Audition Play/Stop toggle → `/matrix/audition vi on`.
- WS handlers: `/matrix/colordef` (single field echo) and `/matrix/colordefs`
  (bulk, for preset load) update the modal + state.
- Modal opens populated from local state; `/matrix/colordefs/get` requested on open
  to sync from SC.

## Persistence

`~matColorDefs` is stored in the `.matrix` Event (the format established by the
instrument-selection plan) as a `colorDefs` field (16 voices × 6 colors × fields).
Load defaults missing/invalid defs to the default table → backward-compatible with
grid-only and instrument-only `.matrix` files. Web mirrors color defs in the matrix
localStorage object alongside grid/inst/mod.

## Error handling / robustness

- `/matrix/colordef` with bad `vi`/`color`/`field`, an `inst` not in the voice's
  choices, or `cutoff`/`pan` on an unsupported voice → ignored.
- Audition while the grid is playing: audition drives only the one voice's Pdef for
  preview; stopping audition restores normal grid-driven behavior on the next bar
  (force re-source). Document that audition is a preview tool, best used while the
  grid for that voice is not actively playing.
- nil-guarded, idempotent reload; defaults reproduce current behavior exactly.

## Testing

- **SC** (`data_only/test/test_matrix.scd`, headless, P:0 B:0):
  - `~matColorDefs` initialized; the DEFAULT defs reproduce the current variation —
    assert a consumed `~matVariation.(\acid, 2, vi)` event has `\stretch == 0.5`,
    `\octave == 0`, `\amp == 1.0` (color 2 default), proving parity.
  - `~matSetColorDef.(vi, 3, \octave, -2)` changes the def; consuming the stream
    reflects it; an invalid field/inst is rejected.
  - `~matAudition` defined and `~matAudition.(0, false)` does not raise.
  - Persistence round-trip: set a color def, save, clear, load → restored;
    grid-only legacy file → defaults.
- **Web**: manual — open the modal from a voice, edit a color's stretch/amp and
  hear it on the next bar; audition cycles the 6 colors; save/reload a preset and
  confirm color defs restore.

## Out of scope

- Envelope/drive/deep synth-param editing; the 6-step as an independent live loop
  or nested sub-steps; editing colors globally (this is per-voice); adding new
  colors beyond 1-6.
