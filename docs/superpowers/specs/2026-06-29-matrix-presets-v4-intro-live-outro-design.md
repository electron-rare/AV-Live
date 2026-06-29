# Matrix presets v4 — intro/live/outro triplets + hand-authored families

**Date**: 2026-06-29
**Status**: design pending approval
**Scope**: preset generator (`sound_algo/data_only/matrix_presets/generate_presets.py` + `patterns.py`) + regeneration/validation. NO engine/web changes. Supersedes the SP-C2 families-only spec/plan (folds it in). Sub-projects C2+D merged.

## Context

The 28 matrix presets are each a single 64-bar grid. The user wants each
*morceau* decomposed into **three sections — intro / live / outro — as three
separate `.matrix` files**, hand-arranged per morceau (28 → 84 presets). And the
pattern bank is thin (mel: only `dub` on sub, `psy` on acid; 6 drum voices
fallback-only) — so this effort ALSO hand-authors new pattern families. Both are
pure content/generation; the engine (SP-C1 derivation, per-voice mods, evolve)
is untouched.

## Decisions (from brainstorming)

- **Three separate presets per morceau.** Each of the 28 morceaux emits
  `<name>_intro.matrix`, `<name>_live.matrix`, `<name>_outro.matrix` (= 84). No
  engine feature, no in-grid section zones — three independent grids loaded
  separately (`/matrix/load <name>_live` etc.).
- **Hand-arranged per morceau.** Each section's arrangement (which voices play,
  density, which colours) is authored per morceau — not auto-derived from live.
- **Hand-authored pattern families** (the merged SP-C2): full 6-colour sets for
  `dub/psy/house/ambient` (mel) + percu-voice and style-completion drum families
  — written by hand, NOT derived (SP-C1 derivation stays for the `default`
  family only).
- **Full batch.** Author all 84 + all families in one batch; the user reviews by
  ear on the live rig and we iterate on what sounds wrong.

## Section semantics

| Section | Feel | Arrangement |
|---------|------|-------------|
| **intro** | build-up / entry | starts sparse (kick + 1-2 elements), voices ENTER progressively across the 64 bars, ends near-full → leads into live |
| **live** | the main groove | full arrangement (≈ the current per-style arc), all the morceau's voices active, the richest section |
| **outro** | breakdown / exit | starts ~full, voices DROP OUT progressively, thins to a sparse tail/near-empty end → a clean stop or loop-out |

The three are coherent (same instkit + key + families per morceau); they differ
in voice activation + density over the 64 bars.

## Architecture (pure content)

### Generator restructure (`generate_presets.py`)
- Replace the flat `PRESETS = { name: (arc, instkit, melodies, extra) }` with a
  per-morceau structure carrying three section arrangements:
  ```python
  MORCEAUX = { "techno_drive": dict(
      instkit=K_909, melodies={...}, fam=("techno","default"),
      intro=arc_intro_fourfloor, live=arc_four_floor, outro=arc_outro_fourfloor,
      extra=None) , ... }
  ```
- `main()` loops morceaux × {intro, live, outro}, calling `to_sc(f"{name}_{sec}",
  section_arc, instkit, melodies, extra)` → writes 84 `.matrix` files.
- Section arcs are hand-specified per morceau. To stay consistent and tractable
  while remaining per-morceau, they are built from reusable **section-arc
  helpers** (`build_intro(g, schedule)`, `build_outro(g, schedule)`) driven by a
  per-morceau voice-entry/exit schedule — the hand-authoring is the morceau's
  schedule + density choices, the helper enforces the section shape. `live` is
  the morceau's existing full arc.
- `live` = the current arc (the 28 existing arcs become the `live` sections).
  `intro`/`outro` are authored as the build/breakdown of that arc.

### Pattern families (`patterns.py`) — merged SP-C2
- Hand-authored 6-colour entries added to `DRUMS`/`MEL` (dub/psy/house/ambient
  mel families on the matrix voices; ride/shaker/crash/rim/fx/sweep drum
  families; complete techno/breaks/dnb for uncovered voices). Existing families
  + every `default` untouched.
- `PRESET_FAMILY` keyed per the 84 preset names (or resolved from the morceau +
  section), mapping each to `(drum_family, mel_family)`.

### Wiring / consumers
- `launch_concert.sh` `MATRIX_PRESET` default → `techno_drive_live`.
- The web `/matrix/list` and preset selectors now show 84 names (no code change;
  they list whatever SC reports). Naming `<morceau>_<section>` sorts the three
  together.

## Testing

- **Python** (`test_families.py` extended + a `test_sections.py`):
  - family validity/contrast (existing harness).
  - section coverage: each of the 28 morceaux yields intro/live/outro; each
    section grid is valid (22×64, colours 0-6).
  - section shape sanity: intro's first bars are sparser than its last (voices
    enter); outro's last bars are sparser than its first (voices exit); live is
    the densest of the three on average.
- **SC validation** (`validate_presets.scd`): regenerate, all **84** load
  (`84/84 PASS`).
- **Musical review (user, batch):** load the `_intro`/`_live`/`_outro` of several
  morceaux on the live rig and listen; iterate on weak sections/families.

## Out of scope

- Engine/web changes (no in-grid section zones, no named-loop navigation — those
  were the rejected options).
- Timing swing (SP-E, still later).
- Changing the SP-C1 `default` derivation, per-voice mods, or evolve.

## Decided defaults

- 84 presets = 28 morceaux × {intro, live, outro}, hand-arranged per morceau via
  reusable section-arc helpers + per-morceau schedules; `live` = the existing arc.
- Hand-authored 6-colour families (not derived); existing families/default kept.
- Full batch; user ear-reviews and we iterate.
