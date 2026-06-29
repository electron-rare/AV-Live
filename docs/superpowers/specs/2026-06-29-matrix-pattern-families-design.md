# Matrix hand-authored pattern families (refactor SP-C2)

**Date**: 2026-06-29
**Status**: design approved, pending implementation plan
**Scope**: pattern bank only (`sound_algo/data_only/matrix_presets/patterns.py`) + `PRESET_FAMILY` wiring + regeneration/validation. NO engine/web changes. Sub-project C2 of the matrix refactor (cycle 2). The timing-swing engine feature is a separate follow-up (SP-E).

## Context

`patterns.py` is thin on authored variety: `MEL` has only 3 families (`default`
for all mel voices, `dub` on `sub`, `psy` on `acid`) — 8/10 mel voices are
`default`-only. `DRUMS` has 12 families but skewed: `crash, fx, ride, rim,
shaker, sweep` have NO custom family (fallback only), and `techno/breaks/dnb`
cover only a few voices. SP-C1 gave every voice's `default` family a contrasted
6-colour spectrum via `derive_drum_colors`/`derive_mel_colors`; this sub-project
adds **hand-authored characterful style families** so presets of different
genres feel distinct, plus velocity humanization.

## Decisions (from brainstorming)

- **Hand-author all 6 colours per (voice, family).** Each colour is written by
  hand (NOT derived from a base) — maximum musical character. The 6 colours
  still follow the colour-role convention for contrast (1 base · 2 busier · 3
  broken/syncopated · 4 double-time · 5 sparse · 6 fill), but each is an explicit
  authored pattern, not a transformation. No `fam()`/derive shortcut here (that
  was SP-C1's job for the `default` family).
- **Existing families untouched.** `default` (SP-C1-derived) and the existing
  authored families (`dub` on sub, `psy` on acid, the drum style families) keep
  their current content; SP-C2 only ADDS new (voice, family) entries.
- **Velocity humanization is baked into the authored colours** (varied accents
  `X` / ghosts `o` / soft `-`, not robotic all-`x`).
- **Batch workflow.** Author the whole set, then the user reviews the final
  sound on the live rig and we iterate on what sounds wrong. Timing swing is
  out of scope (SP-E, engine).

## Architecture (pure content)

- Each new family is **6 explicit hand-authored colours** added to the existing
  dicts, exactly like the current authored families:
  ```python
  DRUMS["ride"]["techno"] = ["x.x.x.x.x.x.x.x.",  # 1 base: rolling 8ths
                             "xXx.xXx.xXx.xXx.",  # 2 busier: accented
                             "x..xx..xx..xx..x",  # 3 broken: syncopated
                             "xxxxxxxxxxxxxxxx",  # 4 double: 16ths
                             "x...x...x...x...",  # 5 sparse: quarters
                             "x.x.x.x.x.x.xXXX"]  # 6 fill: accent roll tail
  MEL["lead"]["dub"] = [_mel([...]), _mel([...]), _mel([...]),
                        _mel([...]), _mel([...]), _mel([...])]   # 6 motifs
  ```
  Colours follow the role convention (base/busier/broken/double/sparse/fill) so
  they stay contrasted, but every cell is hand-written for character. DRUMS
  store 16-char strings (parsed by `_rhythm` in `patterns_for`); MEL store
  `_mel([...])` motif lists.
- New entries are added to the existing `DRUMS`/`MEL` dicts; `patterns_for`
  already selects `dfam`/`mfam` then falls back to `default` — no change needed
  there (a voice that now HAS the requested style family stops falling back).
- `PRESET_FAMILY` is extended/retargeted so presets actually reference the new
  families (e.g. `dub_techno -> ("techno", "dub")`, a psy preset -> mel `psy`,
  a house preset -> mel `house`, ambient_intro -> mel `ambient`).

## Content to author (the characteristic bases)

### New MEL families (base motif per voice where the style is musical)
| Family | Mel voices it covers | Feel |
|--------|----------------------|------|
| `dub` | sub*(exists), reese, pad, chord, bells, melody | deep, sparse, spacey, off-beat stabs |
| `psy` | acid*(exists), sub, reese, arp, lead, stab | rolling 16th basslines, fast arps |
| `house` | pad, chord, stab, bells, lead, melody | chord stabs, syncopated, vocal-ish |
| `ambient` | pad, bells, melody, sub, reese | long, sparse, evolving, few notes |
(* already authored — leave as-is, only add the missing voices.)

### Percussion voices (give the 6 fallback-only drum voices authored bases + fills)
`crash, ride, rim, shaker, fx, sweep` — author a characteristic base per
relevant family (at minimum `default` stays SP-C1-derived; add `techno`/`breaks`/
`dnb` bases where the voice plays a role: e.g. `ride` techno = rolling 8ths,
`shaker` = 16th groove, `crash` = downbeat hits + a fill, `rim` = syncopated
clicks).

### Complete skewed drum styles
For `techno`, `breaks`, `dnb`: add base patterns for the voices these families
currently omit (so a `breaks` preset has a coherent breaks feel across kick,
snare, hats, perc, ride, shaker — not just 3 voices).

### Velocity humanization
Authored bases use varied dynamics (`X` accents on strong beats, `o` ghosts,
`-` soft) so the groove breathes; the existing `_VEL` map (`. o - x X` =
0/.30/.50/.80/1.0) is the vocabulary. No all-`x` rows.

## Testing

- **Python** (standalone, `uv run python`, new `test_families.py`):
  - Validity: EVERY family in `DRUMS`/`MEL` (existing + new) is a list of exactly
    6 patterns; each drum string is 16 chars over `. o - x X`; each mel motif is
    16 steps of `None`/`(int, float)` (i.e. `_rhythm`/`_mel` accept them).
  - Contrast: each new family's 6 colours are not all identical (≥4 distinct),
    colour 5 (sparse) has ≤ hits of colour 1, colour 6 (fill) has its last steps
    active — a light sanity check that the hand-authored convention holds.
  - Untouched: existing families (`MEL["sub"]["dub"]`, `MEL["acid"]["psy"]`, the
    drum style families) are byte-identical to before.
  - Wiring: every `(dfam, mfam)` named in `PRESET_FAMILY` exists for the relevant
    voices (or falls back to `default` cleanly — no missing-key crash).
- **SC validation** (`validate_presets.scd`): regenerate the 28 presets, all 28
  load (`28/28 PASS`).
- **Musical review (user, batch):** reload the genre presets on the live rig and
  listen; iterate on bases that sound wrong.

## Out of scope

- Timing swing / micro-timing (SP-E, engine).
- Engine/web changes; new presets (SP-D).
- Changing `default` families or the SP-C1 derivation; changing existing
  authored families.

## Decided defaults

- Full hand-authored 6-colour sets per new (voice, family) — NOT derived.
- Styles covered: dub, psy, house, ambient (mel) + complete techno/breaks/dnb
  (drums) + percu voice families. Velocity-humanized authored colours.
- Existing families and `default` untouched; only additions + `PRESET_FAMILY`
  retargeting.
