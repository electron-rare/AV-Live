# Matrix load/save — list persistence fix + queued "load next"

**Date**: 2026-06-30
**Status**: design approved, pending implementation plan
**Scope**: `sound_algo/data_only/matrix.scd` (engine) + `web_realart/public/control/` (web UI) + tests. Two related changes to the matrix persistence bar. No preset/generator change.

## Context

The matrix control surface has a persistence bar (`.matrix-persist`): a name
input, **SAUVER** (`/matrix/save`), a preset `<select>`, **CHARGER** (immediate
`/matrix/load`), and a refresh. Two gaps:

1. **SAUVER bug** — user saves disappear from the CHARGER list after an engine
   restart. Root cause: `~matNames` (matrix.scd ~494) serves the *user* dir
   (`~matDir = ~/.config/av-live/matrices`) from the **in-memory `~matSavedNames`
   Set**, which is reset to empty on boot (~66). Files on disk (e.g. `saisia.matrix`)
   are never re-scanned, so they are absent from `/matrix/list` until re-saved.
   The disk-scan branch (`ls` + tmpfile + `systemCmd`) used for other dirs works
   headless — the Set was an over-cautious workaround that broke persistence.
2. **No "load next"** — CHARGER swaps the grid immediately, cutting the current
   pattern mid-flight. The user wants an Ableton-style queued load that fires at
   the loop boundary.

## Decisions (from brainstorming)

- Queued load triggers at the **loop wrap** (the `~matPlay` point already used by
  ÉVOLUE — playhead jumped backward at the end of `~matBars`/the loop region).
- The **SAUVER bug is a real fix**: `~matNames` for the user dir scans the disk
  (∪ `~matSavedNames` for same-session saves).
- If the playhead is **not playing**, "SUIVANT" falls back to an immediate load
  (otherwise nothing would happen).

## Part A — save-list persistence fix

`~matNames` (matrix.scd): for `dir == ~matDir`, scan the directory from disk with
the same `ls -1 <dir> > tmp; read; filter .matrix` mechanism already used for
other dirs, then **union with `~matSavedNames`** (so a just-saved name appears
even on the rare chance the scan misses it). For non-user dirs: unchanged. Result
is de-duplicated (already `.as(Set)` in `~matListPush`).

## Part B — queued "load next"

### Engine (matrix.scd)
- New state `~matQueuedLoad` (nil = nothing armed, else a preset name string).
- New OSCdef `/matrix/loadnext <name>`:
  - if playing (`~lp[\matPlaying] == true`): set `~matQueuedLoad = name`;
    emit `/matrix/queued <name>` (UI shows armed state).
  - else: `~matLoad.(name)` immediately (fallback) + emit `/matrix/queued ""`.
- The `~matPlay` playhead Routine already detects the wrap at line ~421-422
  (`~lp[\matBar] < ~matPrevBar` after `~matNextBar`), where ÉVOLUE mutates.
  Replace that single evolve `.if` with: on wrap, **if `~matQueuedLoad.notNil`**
  → `~matLoad.(~matQueuedLoad)`, `~matQueuedLoad = nil`, emit `/matrix/queued ""`,
  and **skip this cycle's evolve** (freshly loaded preset plays one clean cycle);
  **else** the existing `~matEvolve.if({ ~matEvolveStep.() })`.
- **Re-entrancy caveat** (verify in the plan): `~matLoad`/`~matLoadFile` is called
  from *inside* the running Routine, so it must only swap the grid/instruments/base
  data and **must not restart the playhead Routine** (no `~matPlay.()` from the
  load path) — otherwise it kills the routine it runs in. If `~matLoad` restarts
  playback, factor a grid-only load for the wrap hook.
- The loaded preset becomes the new evolve base (via `~matLoad`'s base reset), so
  ÉVOLUE keeps working on it from the next wrap.

### Web (`web_realart/public/control/`)
- `index.html`: a **SUIVANT** button in `.matrix-persist` after CHARGER.
- `main.js`: SUIVANT click → `send("/matrix/loadnext", <select>.value)`. An
  `on("/matrix/queued", args)` handler sets/clears an `armed` CSS class on the
  SUIVANT button and shows the queued name (e.g. button label or a small badge);
  empty string clears it.
- `control.css`: an `.armed` style (e.g. pulsing/highlight) for the SUIVANT button.

## Testing

- **SC** (`test_matrix.scd` or a focused snippet, `sclang` headless):
  - Part A: write a dummy `<x>.matrix` into a temp `~matDir`, call
    `~matNames.(~matDir)`, assert `\x` is included (disk-scanned, not just the Set).
  - Part B: arm `~matQueuedLoad`, simulate a wrap, assert the queued preset loads
    and `~matQueuedLoad` is nil afterward; arm while not playing → immediate load.
- **Web** (`node --test web_realart/public/control/test/*.test.mjs`): SUIVANT
  click sends `/matrix/loadnext` with the selected name; `/matrix/queued <name>`
  sets the armed class, `/matrix/queued ""` clears it.
- **Live smoke** (macm1): save a preset → restart engine → it still lists +
  loads (Part A); arm SUIVANT during playback → swaps at the next wrap (Part B).

## Out of scope

- Changing CHARGER (immediate) or SAUVER button behaviour beyond the list fix.
- Adjustable quantization (1/4/8/16 bars) — wrap-only for now.
- Per-voice / partial queued loads.

## Decided defaults

- Queued load fires at the loop wrap; skips that cycle's evolve.
- "SUIVANT" while stopped = immediate load.
- `~matNames` user dir = disk scan ∪ in-memory Set.
