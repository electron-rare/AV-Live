# Default pose→instrument mappings in presets (refactor SP-A)

**Date**: 2026-06-29
**Status**: design approved, pending implementation plan
**Scope**: preset generator only (`sound_algo/data_only/matrix_presets/generate_presets.py`) + its validation. NO engine changes (the Cycle-1 `pitch`/`res` targets + the per-voice mod system are already shipped). Sub-project A of the matrix refactor (cycle 2).

## Context

The matrix engine supports per-voice modulation bindings `~matVoiceMods[voice]` =
list of `(source, target, depth)`, targets `amp/cutoff/pan/rev/res/pitch`, 19
pose sources, applied live. Presets carry these via `voiceMods`/`voicePoses`
keys, but only `techno_drive` has demo bindings (`VOICE_MODS_DEMO`/
`VOICE_POSES_DEMO`, generate_presets.py:518-529); the other 27 presets ship
empty. This sub-project bakes a **fixed, logical, role-adapted default mapping
scheme** into every preset so the body/hands control instruments expressively
out of the box.

### Constraints carried in

- **No runtime switching.** Mappings are FIXED per instrument, identical across
  all presets (one global consistent scheme). No close/far mode, no distance
  watcher — explicitly out of scope (the engine stays untouched).
- **Mixed sources by role** (`project_concert_mode`: hand tracking dies at
  full-body distance). Soloist voices use HAND sources (expressive, close-up);
  energy/structure voices use BODY sources (robust at any distance).
- **Cycle-1 target eligibility** (which voices accept which target) must be
  respected — emit only valid bindings:
  - `cutoff`: perc, acid, arp, lead, stab, pad, reese, melody, chord
  - `res`: sub, acid, arp, lead, stab, pad, reese, bells, melody, chord
  - `pitch`: sub, acid, arp, lead, stab, pad, reese, bells, perc, tom
  - `amp`, `pan`, `rev`: all voices
- **Cycle-1 minors honored**: pitch is bipolar (neutral at source 0.5 → the
  resting `rHandY`/`bodyY` give 0 transpose) and applies only on the step path
  (active melodic voices have steps → fine); `res` is additive-from-0 (a source
  resting low gives low resonance) so res bindings use modest depth and sources
  whose rest reads musically (limbSpan low when arms down opens up as they
  spread; lHandX similar).

## The fixed mapping scheme

Applied to each voice ACTIVE in a preset (skip muted voices), filtered by
eligibility:

| Role | Voices | Bindings (source → target, depth) |
|------|--------|-----------------------------------|
| Lead (hands) | acid, arp, lead, stab | rHandX→amp 0.4 · rHandY→pitch 0.4 · lHandY→cutoff 0.5 · lHandX→res 0.4 |
| High-mel (hands) | bells | rHandX→amp 0.4 · rHandY→pitch 0.4 · lHandX→res 0.4 |
| High-mel (hands) | melody | rHandX→amp 0.4 · lHandY→cutoff 0.5 · lHandX→res 0.4 |
| Bass (body) | reese | bodyVitesse→cutoff 0.5 · bodyY→pitch 0.3 · limbSpan→res 0.4 · bodyX→pan 0.3 |
| Bass (body) | sub | bodyVitesse→res 0.4 · bodyY→pitch 0.3 · bodyX→pan 0.3 |
| Pad/harm (body) | pad, chord | bodyVitesse→cutoff 0.4 · limbSpan→rev 0.4 · bodyX→pan 0.3 |
| Pitched perc (body) | perc | bodyVitesse→cutoff 0.4 · bodyY→pitch 0.3 · bodyX→pan 0.3 |
| Pitched perc (body) | tom | bodyY→pitch 0.3 · bodyVitesse→amp 0.3 · bodyX→pan 0.3 |
| Drums (body) | kick, hats, clap, ride, rim, snare, crash, shaker | bodyVitesse→rev 0.3 · bodyX→pan 0.3 |
| FX (body) | sweep, fx | danse→rev 0.5 · bodyVitesse→amp 0.4 |

Every binding above is eligibility-valid for its voice (verified against the
Cycle-1 table: e.g. sub uses `res` not `cutoff`; bells omits `cutoff`; melody
omits `pitch`; perc/tom omit `res`).

**Default poses** (`voicePoses`): minimal — `danse → gate` on `fx` and `sweep`
(the dance gesture swells the effects). All other voices: empty. Fine-grained
pose triggers stay a per-performance live choice.

## Architecture (pure content)

- New helper `default_mods(voice)` in `generate_presets.py`: returns the role's
  binding list for the voice, each binding a `(source, target, depth)` tuple,
  **filtered through an eligibility map** (a Python mirror of the Cycle-1
  per-voice target sets) so an invalid binding can never be emitted. A voice
  with no role match returns `[]`.
- New helper `default_poses(voice)`: returns `[("danse","gate")]` for `fx`/
  `sweep`, else `[]`.
- The existing `emit_voicemods(name)` / `emit_voiceposes(name)` (generate_
  presets.py:542-567) source their per-voice lists from these helpers. The
  `VOICE_MODS_DEMO`/`VOICE_POSES_DEMO` literals (incl. the techno_drive demo)
  are REMOVED — the helpers are the single source of default bindings (YAGNI:
  no per-preset override layer for now; the scheme is uniform across presets).
- **Active-voice filter**: emit default mappings only for voices the preset
  actually plays (has a non-empty step pattern / is in the kit). If determining
  "active" per voice is impractical in `to_sc`, emitting for all 22 is an
  acceptable fallback (mappings on silent voices are inert — no notes to
  modulate); prefer active-only for tidiness, document whichever is chosen.
- No SC, no web changes. The web target dropdown + SC gating already handle
  these bindings (Cycle 1).

## Testing

- **Python** (the generator's own test surface; use `uv`):
  - `default_mods("lead")` returns the 4 lead-hand bindings; `default_mods("sub")`
    returns res (not cutoff) + pitch + pan; `default_mods("bells")` omits cutoff;
    `default_mods("melody")` omits pitch; `default_mods("perc")`/`("tom")` omit
    res; `default_mods("kick")` returns only body amp/pan/rev-eligible bindings
    (bodyVitesse→rev, bodyX→pan).
  - Eligibility filter: every binding `default_mods(v)` returns has a target in
    that voice's eligibility set (assert across all 22 voices — no invalid
    emission).
  - `default_poses("fx")` == `[("danse","gate")]`; `default_poses("kick")` == `[]`.
- **SC validation** (extend the existing `matrix_presets/validate_presets.scd`):
  regenerate the 28 presets, load all 28 via `~matLoadFile` (28/28 PASS), and
  assert a representative preset has a lead voice with its 4 hand bindings in
  `~matVoiceMods` and a drum voice with its body bindings — proving the emitted
  defaults parse and survive load.

## Out of scope

- Any engine change (no mode switch, no new sources/targets — Cycle 1 done).
- Preset variety / auto-color arrangement / new presets (sub-projects B/C/D).
- Per-preset bespoke mappings (the scheme is uniform across presets; per-preset
  tuning / an override layer can come later if needed).

## Decided defaults

- One uniform fixed scheme across all presets; soloists→hands, structure→body.
- Depths: 0.3–0.5 (modest, musical). Pitch depth 0.3–0.4 (≈ ±2-3 scale degrees
  at `~matPitchRange` 7).
- `danse→gate` on fx/sweep is the only default pose.
- Emit for active voices (all-22 fallback acceptable, documented).
