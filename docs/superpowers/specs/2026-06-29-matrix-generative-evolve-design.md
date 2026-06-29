# Matrix generative per-cycle evolution (refactor SP-B)

**Date**: 2026-06-29
**Status**: design approved, pending implementation plan
**Scope**: SuperCollider matrix engine (`sound_algo/data_only/matrix.scd`) + small OSC/web. Sub-project B of the matrix refactor (cycle 2).

## Context

The matrix is a 22-voice × 64-bar grid; each cell holds a colour 0-6 (0 = off,
1-6 = a per-voice variation). The play routine (`~matPlay`, matrix.scd ~362-375)
advances the playhead bar-by-bar; `~matApplyBar.(bar)` reads `~lp[\matrix][vi]
[bar]` and re-sources each voice to that colour's variation. The loop region
defaults to the full 64 bars (`~lp[\matLoopStart]=0`, `~lp[\matLoopEnd]=63`).

So the arrangement already evolves across 64 bars — but the generated grids use
long homogeneous sections (a voice holds one colour for 4-24 bars), and the
64-bar cycle then **repeats identically forever**, which reads as hypnotic/
static. There is no auto-variation. This sub-project adds **bounded generative
mutation**: at each loop wrap, the engine recolours a few active cells so no two
cycles are identical, while staying close to the preset's intent.

## Decisions (from brainstorming)

- **Recolour active cells only.** The on/off density (rhythm) is preserved; only
  the COLOUR (variation) of already-active cells changes (1-6 → a different
  1-6). The 6 colours of a voice are all musically coherent variations, so a
  recolour is always in-place.
- **Bounded drift.** Each cycle re-derives the working grid from an immutable
  base snapshot (the preset arrangement) — mutations do NOT accumulate, so it
  never drifts into mush; every cycle is "base + fresh light noise".
- **Default OFF**, performer-enabled. Rate default 0.15 (≈15% of active cells
  recolour per cycle), env-tunable. Mutation runs once per 64-bar cycle (at the
  loop wrap).

## Architecture

### Data model
- `~matBaseGrid` — immutable snapshot of the clean preset grid (a 2-level copy:
  `~lp[\matrix].collect({ |row| row.copy })`). Taken when evolution is ENABLED.
- `~lp[\matrix]` — the working/playing grid (unchanged role: `~matApplyBar`
  reads it, the web shows it). Evolution OFF ⇒ identical to base.
- `~matEvolve` (Boolean, default `false`), `~matEvolveRate` (0..1, default 0.15,
  `~matEvolveRate ? 0.15`, env-tunable).

### Mutation step (`~matEvolveStep`)
Derives the working grid from the base, once per cycle:
```
for each voice vi, each bar b:
    base = ~matBaseGrid[vi][b]
    if base != 0 and rand(0..1) < ~matEvolveRate:
        ~lp[\matrix][vi][b] = a random colour in 1..6 that is != base   # recolour
    else:
        ~lp[\matrix][vi][b] = base                                       # keep
then ~matGridPush.()        # web reflects the evolution
     invalidate ~matLastColor (set all -1)  # force re-source on the next bar
```
Bounded because every cell is re-derived from `~matBaseGrid` (no accumulation).
0-cells always stay 0 (density preserved). A mutated cell is guaranteed to
differ from its base colour (so the rate is the true change fraction).

### Trigger point
In the `~matPlay` routine, when the playhead WRAPS back to `~lp[\matLoopStart]`
after completing a cycle (detect via the previous bar being `~lp[\matLoopEnd]`,
or `newBar < prevBar`), and `~matEvolve` is true, call `~matEvolveStep` before
applying that bar. Runs once per full loop, not per bar.

### Enable / disable (OSC)
- `/matrix/evolve [0/1]`: ON → `~matEvolve = true; ~matBaseGrid = <2-level copy
  of ~lp[\matrix]>`. OFF → `~matEvolve = false; ~lp[\matrix] = <2-level copy of
  ~matBaseGrid>` (restore the clean grid), `~matGridPush.()`, re-source.
- `/matrix/evolverate [0..1]`: `~matEvolveRate = value.clip(0,1)`.
- Outbound echo `/matrix/evolve [stateInt, rate]` so the web reflects state.

### Live edits while evolving
- `~matSetCell.(vi, bar, color)`: writes `~lp[\matrix][vi][bar]` as today AND,
  when `~matEvolve` is true, also writes `~matBaseGrid[vi][bar]` — so a live
  edit persists into the base and is not overwritten on the next cycle.
- `~matSave`: serializes the CLEAN arrangement — `(~matEvolve.if({ ~matBaseGrid
  }, { ~lp[\matrix] }))` — never the mutated working grid.
- `~matLoad`/`~matLoadFile`: unchanged (sets `~lp[\matrix]`). If evolution is on
  at load time, re-snapshot `~matBaseGrid` from the freshly loaded grid.

### Web (minor)
- A toggle "ÉVOLUE" + a rate slider in the matrix transport area, sending
  `/matrix/evolve` / `/matrix/evolverate` and reflecting the echoed state. The
  grid display already refreshes from `~matGridPush` each cycle.

## Testing

- **SC** (`test/test_matrix.scd`, existing harness; no server; `pass`/`try`;
  `TEST PASS`):
  - density preserved: build a `~matBaseGrid` with known 0 and non-0 cells, run
    `~matEvolveStep` with rate 1.0, assert every 0-cell stays 0 and every active
    cell stays active (1..6).
  - recolour differs: with rate 1.0, every active cell's new colour ≠ its base
    colour and ∈ 1..6.
  - bounded/no-accumulation: enabling snapshots the base; after two
    `~matEvolveStep` calls, disabling restores `~lp[\matrix]` to `~matBaseGrid`
    exactly (the base is untouched by mutation).
  - rate 0.0: `~matEvolveStep` leaves the working grid identical to the base.
  - live edit during evolve: `~matSetCell` with `~matEvolve` true updates
    `~matBaseGrid` too (so the edit survives a subsequent `~matEvolveStep`).
  - save picks base: with evolve on and a mutated working grid, the `~matSave`
    payload grid equals `~matBaseGrid`, not the mutated `~lp[\matrix]`.
- **Web** (`node --test test/*.test.mjs`): `/matrix/evolve` / `/matrix/evolverate`
  send payload shapes; the echoed-state handler updates the toggle/slider.

## Out of scope (other sub-projects)

- Denser deterministic grids / richer patterns (SP-C) and new presets (SP-D).
- Density mutation (0↔colour) — explicitly excluded; recolour-only.
- Accumulating random-walk drift — explicitly excluded; bounded only.
- Per-section or tempo-synced evolution curves — v1 is uniform per-cycle.

## Decided defaults

- `~matEvolveRate` = 0.15, env-tunable. Evolution default OFF (performer enables).
- Recolour active cells only; bounded from an immutable base snapshot.
- Mutate once per 64-bar loop wrap; mutated colours differ from base and ∈ 1..6.
