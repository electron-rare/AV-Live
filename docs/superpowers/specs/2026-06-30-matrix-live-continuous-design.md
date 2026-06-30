# Matrix `_live` section = continuous full groove (no intro/breakdown)

**Date**: 2026-06-30
**Status**: design approved, pending plan
**Scope**: `sound_algo/data_only/matrix_presets/generate_presets.py` + `test_sections.py` + regenerated `*.matrix`. Follow-on refinement to presets v4.

## Context

In presets v4 each morceau is split into `_intro` / `_live` / `_outro`. The
`_live` section reuses the morceau's original arc, which is a standalone 64-bar
piece WITH its own intro: the grid starts near-empty and rebuilds (I=8, B=34, …,
plateau P=133) and has a mid breakdown (K=30) — measured on `techno_drive_live`.
So `_live` re-introduces instead of being the sustained groove the `_intro`
builds up to. The user wants `_live` to be the **continuous full loop**: full
from bar 0, no intro ramp, no breakdown — the intro builds to it, the outro
descends from it.

## Decision (from brainstorming)

`_live` = the **plateau (P, bars 32-47) tiled across all 64 bars** — a clean,
loopable full groove. No intro, no breakdown. Intro/outro sections unchanged.

## Design

### `make_live_continuous(g)` (generate_presets.py)
Applied to the `_live` grid AFTER `apply_colors` (so it tiles the coloured
plateau, which already carries the plateau's internal variation — e.g. the
double-time hats on the plateau's second half):
```python
def make_live_continuous(g):
    """Live = the plateau groove tiled across all 64 bars: full from bar 0, no
    intro ramp, no breakdown. The intro builds to it, the outro descends from it."""
    ps, pn = SECTIONS["P"]            # (32, 16)
    for row in g:
        plateau = row[ps:ps + pn]     # the 16-bar full-groove slice
        for b in range(len(row)):
            row[b] = plateau[(b - ps) % pn]
    return g
```
`(b - ps) % pn` keeps the plateau anchored at bars 32-47 and repeats it to fill
0-31 and 48-63, so each 16-bar block is the full plateau.

### Wiring (`to_sc` + `main`)
- `to_sc(name, arc_fn, instkit, melodies, extra, post=None)`: after
  `apply_colors(g)`, call `post(g)` if given.
- `main()`: `post = make_live_continuous if sec == "live" else None`.
- intro/outro pass `post=None` (unchanged).

## Testing

- **`test_sections.py`**: mirror the generator — apply `make_live_continuous` to
  the `_live` grid in `grid_of(...)` when `sec == "live"`. Then:
  - existing checks hold: intro builds (late>early), outro breaks (early>late),
    live is the densest.
  - NEW: `_live` is FULL from the start — `active(live, 0, 16)` is within ~15% of
    `active(live, 32, 48)` (no intro ramp); and `_live` has NO breakdown dip —
    `active(live, 48, 64)` is also within ~15% of the plateau. (Tiling makes all
    four 16-bar blocks equal, so these hold with margin.)
- **SC**: `validate_presets.scd` → `84/84 PASS` + `DEFAULTS PASS` unchanged
  (peak_drop_live grid changes but the voiceMods/voicePoses assertions are
  unaffected — the transform only moves cells, doesn't touch mods/poses).
- **Live smoke** (macm1): reload a `_live` preset → full groove from bar 0, loops
  cleanly, no intro/breakdown; `_intro`/`_outro` unchanged.

## Out of scope

- Changing `_intro`/`_outro` arcs, the pattern families, or the per-voice
  mods/poses.
- Any new live dynamics beyond the plateau's own internal variation.

## Decided defaults

- `_live` = plateau tiled across 64 bars (full loop, no intro/breakdown).
- Transform applied post-`apply_colors`, live section only, via `to_sc(post=)`.
