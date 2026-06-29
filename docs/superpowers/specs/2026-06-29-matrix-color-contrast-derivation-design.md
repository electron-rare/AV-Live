# Matrix 6-colour contrast derivation (refactor SP-C1)

**Date**: 2026-06-29
**Status**: design approved, pending implementation plan
**Scope**: pattern bank only (`sound_algo/data_only/matrix_presets/patterns.py`) + regeneration/validation. NO engine/web changes. Sub-project C1 of the matrix refactor (cycle 2); the hand-authored families/motifs are a separate follow-up (SP-C2).

## Context

`patterns.py` holds the matrix's per-voice patterns: `DRUMS` (12 drum voices, rhythm-DSL strings `. o - x X` = velocities 0/0.30/0.50/0.80/1.0) and `MEL` (9 melodic voices, `(degree, vel)` motifs), each as a 6-element list (colours 1-6) per groove family, parsed by `_rhythm`/`_mel`. `patterns_for(voice, preset)` picks a family, falling back to `default`.

The 6 colours follow a loose convention (1=base, 4=busy, 5=sparse, 6=fill) but it is NOT codified: many voices' `default` colours are low-contrast (e.g. kick default colours 1-4 are all 4-8 hits), and 14/22 voices have ONLY the `default` family. So the matrix's per-bar variation reads as flat for many voices.

This sub-project codifies a deterministic **6-colour contrast convention** and derives a well-contrasted 6-colour spectrum for **every voice's `default` family**, keeping each voice's characteristic colour 1 as the base. Hand-authored STYLE families (the existing per-style variants) are left untouched — their character is preserved.

## Decisions (from brainstorming)

- **Contrast rule applied uniformly** to the `default` family of ALL 22 voices (not just the 14 thin ones) — "base saine partout". Each voice's `default` becomes `[base] + derive(base)` where `base` = that voice's current `default` colour-1.
- **Authored style families untouched** (kick/hats `techno`/`breaks`/`dnb`/…, sub `dub`, acid `psy`, etc.) — the rule only normalizes the `default` family.
- **Deterministic** transformations (no RNG) so regeneration is byte-for-byte reproducible.
- Engineering only (density/validity invariants); musical character of new families is SP-C2 (hand-authored, user-guided).

## The 6-colour convention

| Colour | Role | Density vs base |
|--------|------|-----------------|
| 1 | base (characteristic) | — |
| 2 | busier | ≥ base |
| 3 | broken (syncopated / octave-displaced) | ≈ base, hits at different positions |
| 4 | double (denser, double-time / arpeggiated) | ≥ base, ≥ colour 2 |
| 5 | sparse (minimal) | < base |
| 6 | fill (base + end roll / closing run) | ≥ base, last steps active |

## Architecture (pure content, deterministic)

### `derive_drum_colors(base)` — base is a 16-step velocity list
- **2 busier**: add ghost hits (`0.30`) on a fixed set of currently-rest off-beat steps.
- **3 broken**: displace off-beat hits by +1 step (fixed syncopation), preserving hit count.
- **4 double**: fill currently-rest 8th-note steps (`i % 2 == 0`) with `0.80`, keeping existing accents.
- **5 sparse**: keep only accents (`1.0`) and down-beats (`i % 4 == 0`); other steps → rest.
- **6 fill**: copy base, then overwrite the last 4 steps (12-15) with an accelerating roll `[0.8, 0.8, 1.0, 1.0]`.

### `derive_mel_colors(base)` — base is a 16-step list of `(degree, vel)` or `None`
- **2 busier**: fill a fixed set of rest steps with a passing note (previous active degree, lower vel).
- **3 broken**: octave-displace notes at fixed positions (`+7` or `+12` to degree).
- **4 double**: fill rest 8th-note steps (`i % 2 == 0`) by repeating the nearest active degree.
- **5 sparse**: keep only notes at strong steps (`i % 4 == 0`).
- **6 fill**: replace the last 4 steps with a stepwise run from the base's last active degree.

Both derivations are pure functions of the base (deterministic). They operate on the **parsed step lists** (the 16-element output of `_rhythm`/`_mel`: drums = velocity floats with 0 for rest; mel = `(degree, vel)` tuples or `None`), returning the same shape — so the result plugs straight into the existing emit path. No DSL-string manipulation.

### Application
- For EACH of the 22 voices, the `default` family becomes `[base, *derive(base)]` (6 colours) where `base` = the voice's current `default[0]`. Drum voices use `derive_drum_colors`; melodic voices use `derive_mel_colors`.
- All non-`default` families (the hand-authored style variants) are emitted unchanged.
- `patterns_for` is unaffected structurally (it still returns 6 colours per voice/family); only the `default` family's colours 2-6 change.

## Testing

- **Python** (standalone assertion script, `uv run python`, no pytest dep — like `test_default_mods.py`):
  - density invariants on representative bases: `density(5) < density(1)`, `density(2) >= density(1)`, `density(4) >= density(1)`, colour 6 has its last 4 steps active; colour 3 has the same hit count as base but ≥1 hit at a different position (drums).
  - validity: every derived colour is 16 steps; drum velocities ∈ {0, .30, .50, .80, 1.0}; mel degrees within the legal range used by `_mel`; rests preserved where required.
  - determinism: `derive_drum_colors(base) == derive_drum_colors(base)` (and mel) — identical on repeat.
  - application: for every voice, the `default` family has 6 colours and colours 2-6 are NOT all equal to colour 1 (real contrast); style families are byte-identical to before.
- **SC validation** (`validate_presets.scd`): regenerate the 28 presets, load all 28 (`28/28 PASS`) — the derived `default` colours parse and play.

## Out of scope

- Hand-authored new families / characterful motifs (SP-C2 — user-guided).
- New presets/styles (SP-D).
- Any engine/web change.
- Changing colour 1 (the characteristic base) of any voice, or touching any non-`default` family.

## Decided defaults

- Apply to the `default` family of all 22 voices; keep colour 1; derive 2-6.
- Deterministic transforms (no RNG).
- Style families untouched.
