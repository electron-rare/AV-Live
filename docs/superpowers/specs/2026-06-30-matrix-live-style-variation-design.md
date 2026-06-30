# Matrix `_live` per-style variation (full loop that breathes)

**Date**: 2026-06-30
**Status**: design approved, pending plan
**Scope**: `sound_algo/data_only/matrix_presets/generate_presets.py` + `test_sections.py` + regenerated `*.matrix`. Refinement of the `_live` continuous loop.

## Context

`make_live_continuous` tiles the plateau across all 64 bars, so the `_live`
loop is four identical 16-bar blocks (133/133/133/133 on techno_drive) — full
but static. The user wants variation in the live loop, **adapted to each style**
(per genre), while staying full (no voice drops, no intro/breakdown — those
were the point of the previous fix).

## Decision (from brainstorming)

Keep full density; add per-style variation by **recolouring active cells** (the
matrix colour 1-6 system changes the pattern a voice plays without removing it)
+ **phrase-end fills**. The variation profile is keyed to the morceau's style.

## Design

### Style derivation — `LIVE_STYLE` (generate_presets.py)
Explicit morceau -> style map (7 groups), default `"techno"`:
- **techno**: techno_drive, detroit_soul, peak_drop, rave_stab, acid_journey
- **psy**: dub_techno, psytrance_roll, minimal_hypno, hypnotic_arp
- **trance**: trance_euphoria, melodic_builder, melodic_deep, progressive_lift, synthwave_drive
- **breaks**: breakbeat, bass_science, jungle_amen, dnb_roller, footwork_chop, neuro_reese, tribal_perc
- **electro**: electro_808, ebm_body, electro_funk
- **industrial**: schranz_drive, industrial_grind, hardcore_punk
- **ambient**: ambient_intro

### Variation profiles — `LIVE_VAR`
Per style: `busy` voices recoloured in `busy_blocks` (16-bar block indices 0-3)
to `busy_color`; `fill` voices' active cells set to colour 6 on the last 2 bars
of every block. Colours chosen per voice kind — rhythmic voices use 2 (busier)
or 4 (double-time); melodic voices use 3 (octave-up lift), since step-mode
ignores stretch so 2/4 are inaudible on melodic voices.

| style | busy voices | busy_blocks | busy_color | fill voices |
|-------|-------------|-------------|-----------|-------------|
| techno | hats, perc | 1, 3 | 4 (double) | snare, clap, perc |
| psy | acid, arp, reese | 1, 3 | 3 (octave) | perc |
| trance | arp, lead | 2 | 3 (octave) | snare, clap |
| breaks | snare, shaker | 1, 3 | 2 (busier) | snare, perc, tom |
| electro | hats, clap | 1, 3 | 2 (busier) | clap, perc |
| industrial | perc, tom | 1, 3 | 2 (busier) | kick, perc, tom |
| ambient | bells, melody | 2 | 3 (octave) | (none) |

### `make_live_continuous(g, style="techno")`
1. Tile the plateau (existing).
2. `_live_variation(g, style)`:
   ```python
   def _live_variation(g, style):
       prof = LIVE_VAR.get(style, LIVE_VAR["techno"])
       for blk in prof["busy_blocks"]:
           for v in prof["busy"]:
               vi = VI[v]
               for b in range(blk*16, blk*16+16):
                   if g[vi][b] > 0: g[vi][b] = prof["busy_color"]
       for blk in range(BARS // 16):
           for v in prof["fill"]:
               vi = VI[v]
               for b in (blk*16+14, blk*16+15):
                   if g[vi][b] > 0: g[vi][b] = 6
       return g
   ```
   Only recolours active (`> 0`) cells -> density unchanged, voices never dropped.

### Wiring
- `main()`: `post = (lambda g: make_live_continuous(g, LIVE_STYLE.get(name, "techno")))
  if sec == "live" else None`.
- `test_sections.grid_of`: `G.make_live_continuous(g, G.LIVE_STYLE.get(name, "techno"))`.

## Testing

- **`test_sections.py`**: the density asserts (live full-from-start, no breakdown
  dip, live densest) STILL hold — recolouring keeps cells non-zero. NEW: assert
  the live is not four identical blocks (variation present) for every morceau
  except the ones whose profile is genuinely minimal — i.e. the live's 4 blocks
  are not all byte-equal (`len({tuple(row[i*16:i*16+16]) ...}) > 1` for some voice).
- **SC**: `validate_presets.scd` -> 84/84 + DEFAULTS PASS (cells only recoloured;
  mods/poses/instruments untouched). Deterministic regen.
- **Live smoke**: reload several `_live` of different genres -> each loops full but
  evolves in a style-appropriate way (techno double-time hats + fills; breaks
  snare rolls; ambient gentle bell octaves; etc.); intro/outro unchanged.

## Out of scope

- Per-morceau (vs per-style) bespoke variation; new voices; intro/outro changes.

## Decided defaults

- 7 style profiles; recolour-active + phrase-fills; full density preserved.
- Rhythmic busy -> colour 2/4, melodic busy -> colour 3.
