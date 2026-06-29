# Matrix pitch + res modulation targets (refactor cycle 1)

**Date**: 2026-06-29
**Status**: design approved, pending implementation plan
**Scope**: SuperCollider matrix engine (`sound_algo/data_only/matrix.scd`) + web
display layer (`web_realart/public/control/js/matrix-state.js`). Cycle 1 of a
two-cycle matrix refactor.

## Context

The per-voice additive modulation system (shipped 2026-06-29, commits
`6964831..8daad40`) lets each matrix voice bind modulation sources (19 pose-
derived scalars, 0..1) to targets via `~matVoiceMods[voice]` — a free list of
`(source, target, depth)` applied in `~matModPairs`. Current targets:
`amp`, `cutoff`, `pan`, `rev`.

The user wants logical pose→instrument mappings such as "right-hand y → pitch,
left-hand x → resonance". Two of those targets don't exist yet. This cycle adds
them. The richer default-mapping work + preset variety is **cycle 2** (separate
spec); this cycle is the engine prerequisite only.

### How frequency is computed today (the constraint that shapes pitch)

Melodic voices (`sub, acid, arp, lead, stab, pad, reese, bells, perc, tom`)
emit a custom `\freq` Pfunc (`matrix.scd:~225`):

```supercollider
[\freq, Pfunc { |e| (~lpNote.notNil).if({ ~lpNote.(e[\degree], 0).midicps * freqRatio }, { 440 }) }]
```

`~lpNote(degree, octave)` maps a scale degree to a note (stays in the current
scale); `freqRatio = 2.pow(octave)`. There is no `\degree→\note→\freq` standard
chain and no `\ctranspose`/`\detune` key, so the SynthDefs receive `freq`
directly. Consequence: **pitch modulation cannot be an independent `[\key,
Pfunc]` pair** — it must fold into this freq computation. `res` has no such
constraint: it is already an independent `\res` Pbind key, gated by
`~matResVoices`, and the SynthDefs accept `res` (0..1).

## Decisions (from brainstorming)

- **Two cycles.** This is cycle 1 (engine targets only). Cycle 2 = logical
  default mappings + preset variety.
- **Pitch semantics: scale-quantized, bipolar transpose.** A pitch binding
  shifts the played note by an integer number of **scale degrees** (stays in
  key), **centered** on the note: source `0.5` = no shift, `<0.5` = down,
  `>0.5` = up. Per-note (computed at onset) → no glissando.
- **Res semantics: like cutoff/rev**, an independent `\res` Pbind key.

## Architecture

### 1. `res` target (independent Pbind key, like cutoff)

- `~matModPairs` gains a `\res` branch: additive `Σ (src · depth)`, clipped
  `0..1`, emitted as `[\res, Pfunc {...}]`. (Res is naturally 0..1, so a direct
  scaled sum is the right analogue — simpler than cutoff's log curve; no neutral
  table needed.)
- A `\res` mod binding overrides the colorDef's static `res` for that voice
  while present (same precedence as cutoff: the mod pair is spliced after the
  colorDef `res` pair, so it wins).
- `~matModTargets[voice]` gains `\res` **only for `~matResVoices`** (`sub,
  acid, arp, lead, stab, pad, reese, bells, melody, chord`).

### 2. `pitch` target (scale-degree offset folded into the freq Pfunc)

- New helper:
  ```supercollider
  ~matPitchOffset = { |name|
      var off = 0;
      ((~matVoiceMods[name] ? []).select { |b| b[\target] == \pitch }).do { |b|
          off = off + ((~matModSourceVal.(b[\source]) * 2 - 1) * b[\depth] * ~matPitchRange).round.asInteger
      };
      off
  };
  ~matPitchRange = ~matPitchRange ? 7;   // ± scale degrees at full deflection (env-tunable; 7 ≈ 1 octave)
  ```
  Bipolar (source 0.5 → 0), additive across pitch bindings, rounded to an
  integer scale-degree offset.
- The melodic freq Pfunc (`matrix.scd:~225`) changes to add the offset to the
  degree **at note onset**:
  ```supercollider
  [\freq, Pfunc { |e| (~lpNote.notNil).if(
      { ~lpNote.(e[\degree] + ~matPitchOffset.(name), 0).midicps * freqRatio }, { 440 }) }]
  ```
  Because `~lpNote` maps degree→scale note, an integer offset stays in key.
- `pitch` is **NOT** produced by `~matModPairs` (freq is already handled);
  `~matModPairs` simply never emits it (it is filtered as a non-`amp/cutoff/
  pan/rev/res` target). The freq Pfunc is the sole consumer, via the helper.
- **Apply the offset to every freq Pfunc for pitch-capable voices.** A melodic
  voice may render via the step-pattern path (`~matColorStepPattern`) when it
  has steps, or via the overlay path (`~matVariationOverlay`) when it does not.
  The implementation must add `+ ~matPitchOffset.(name)` to the degree in
  **each** place a melodic `\freq` Pfunc is built (grep `\freq, Pfunc` in
  matrix.scd), so pitch modulation works regardless of which path a voice
  takes. If only the step-pattern path computes freq from degree and the
  overlay path inherits the base pattern's freq, document that and patch the
  one true site.
- `~matModTargets[voice]` gains `\pitch` **only for the freq-Pfunc voices**
  (`sub, acid, arp, lead, stab, pad, reese, bells, perc, tom`).

### 3. Target gating (already enforced — no new gate)

`~matSetVoiceMod` already drops bindings whose target ∉ `~matModTargets[voice]`.
Extending `~matModTargets` is therefore sufficient: `pitch` bindings on a
non-melodic voice (e.g. `kick`) and `res` bindings on a non-res voice
(e.g. `hats`) are rejected at set time, by both the OSC route and the web UI.

### 4. Web display layer

- `matrix-state.js`: `MOD_TARGET_LABELS` gains `pitch: "pitch"`, `res:
  "résonance"`. `MATRIX_MOD_TARGETS` (the per-voice target lists, mirrors SC)
  gains `pitch` on the 10 melodic voices and `res` on the 10 res-voices.
- No other UI change: the target dropdown is already filtered by
  `MATRIX_MOD_TARGETS[voice]` and labelled via `MOD_TARGET_LABELS`.

## Testing

- **SC** (`test/test_matrix.scd`, existing harness — no server, `pass`/`try`,
  `TEST PASS`):
  - `res` additive: two res bindings sum and clip 0..1; `~matModPairs` emits a
    `\res` pair for a res-voice with the summed value.
  - `~matPitchOffset`: bipolar (source 0.5 → 0), additive, rounded; e.g.
    source 1.0, depth 1.0, range 7 → +7; source 0.0 → −7; two bindings sum.
  - freq integration: with a pitch binding active, `~matVariation` of a melodic
    voice produces a `\freq` that equals `~lpNote(degree + offset, 0).midicps *
    freqRatio` (assert the transposed freq differs from the un-modulated one in
    the expected direction).
  - gating: `~matSetVoiceMod` drops a `pitch` binding on `\kick` and a `\res`
    binding on `\hats` (target not in `~matModTargets`).
- **Web** (`test/matrix-state.test.mjs`, `node --test test/*.test.mjs`):
  - `MATRIX_MOD_TARGETS` includes `pitch` for melodic voices and `res` for
    res-voices, and does NOT include them for ineligible voices (e.g. kick has
    no pitch, hats has no res).
  - `MOD_TARGET_LABELS` has entries for `pitch` and `res`.

## Out of scope (→ cycle 2)

- Default per-instrument pose→target mappings baked into presets.
- Preset variety / richer arrangements.
- Any new modulation SOURCE (the 19 are unchanged).
- New SynthDef args (pitch uses the existing degree→freq path; res uses the
  existing `res` arg).

## Decided defaults

- `~matPitchRange` = 7 (± scale degrees at full deflection), env-tunable.
- Pitch is bipolar (neutral at source 0.5); res is direct (source 0 → res 0).
- Pitch-capable voices = the 10 freq-Pfunc voices; res-capable = the 10
  `~matResVoices`.
