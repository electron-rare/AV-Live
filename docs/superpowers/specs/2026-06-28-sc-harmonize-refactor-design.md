# SC harmonization refactor — master design

**Date:** 2026-06-28
**Status:** Approved scope (full A→F), design for review
**Scope:** Refactor and harmonize the SuperCollider layer of AV-Live
(`sound_algo/`) — consolidate duplicated functions, unify conventions, reduce
fragmentation — without breaking the running live concert.

## Goal

Reduce technical debt in the SC codebase by bringing scattered/overlapping
functions together behind single sources of truth, unifying namespaces,
clocks, and OSC handling, and finally unifying the two parallel boot universes.
Delivered as six independent, sequentially-shippable lots (A→F), each on a
branch, each verified, so the live concert never breaks.

## Hard constraints (apply to every lot)

- The live concert runs on this code. Every lot is **incremental** and must
  leave the system bootable and playable. No big-bang rewrite.
- Work on the `refactor/sc-harmonize` branch (never directly on `main`).
- `.scd` files keep the project invariants: `.load`-compatible files have
  exactly ONE top-level `(...)` block; parens/brackets balance must be
  `P:0 B:0` (skill `validating-scd-files`).
- After each lot: run `cd sound_algo/tests && bash run_all.sh` (E2E syntax /
  load / reload-guard / SynthDef-compile), the balance check on every edited
  `.scd`, and a headless boot smoke (`sclang boot.scd` in both LIVE and
  data-only paths reaches its READY banner with no error).
- SC env vars stay lowercase `~xxx`. Comments in French (project convention for
  `sound_algo`). No emojis.
- Commits: subject ≤ 50 chars, no AI attribution, no `--no-verify`, no
  underscore in the commit scope.
- **Behavior parity:** a refactor lot changes structure, not sound. Any audible
  or OSC-contract change must be called out explicitly in that lot's plan.
- Backward-compat shims: when renaming a public `~xxx` symbol, keep a
  deprecated alias for one lot cycle so half-migrated state during a live
  session does not crash.

## Current debt (from the codebase audit)

1. **Duplicated music helpers** — `~lpNote` (launchpad.scd:136), `~ccNote`
   (concert), `~fpResolve` (finger_piano.scd), scale arrays in
   `palette/scales.scd` plus re-embedded fallbacks in finger_piano.scd and
   `~ccScales`. Multiple degree→note and scale definitions.
2. **Namespace collision `~cc`** — used for "chains" (`live/chains.scd`) AND
   "concert" (`data_only/scene_concert.scd`).
3. **Clock fragmentation** — `TempoClock.default` (LIVE) vs
   `~lp[\clock]` (126 BPM, isolated); tempo written from 3 unsynchronized
   paths (vdmx_send 60 Hz, web_bridge 4 Hz, OSC) with no lock.
4. **OSC sprawl** — 3 listen ports (57120/57121/1234), OSCdefs scattered over
   6+ files, potential `/control/*` collision (launchpad ↔ web_bridge),
   inconsistent idempotent registration.
5. **Two parallel boot universes** — LIVE (`00_load.scd` → `live/_load.scd`)
   vs data-only (`boot.data-only.scd` / `data_only/boot.scd`) duplicate
   `engine`, setup, and re-load `control/*`.
6. **Giant files** — `control/jump.scd` (2225), `live/live.scd` (1428),
   `data_only/scenes.scd` (1306), `live/live_fx_panel.scd` (826).
7. **Inconsistent conventions** — uneven OSCdef idempotence, uneven nil-guards,
   mixed FR/EN comments.

## Lots (decomposition, in dependency order)

Each lot is its own spec → plan → implement → verify cycle. This master doc is
the roadmap; lots B–F get their own detailed design docs when reached.

### Lot A — Unified music helpers (FIRST, detailed below)
Single source of truth for scales and degree→note resolution. No deps.
Risk: low. Foundation for B/C.

### Lot B — Namespace disambiguation
Rename the concert namespace off `~cc` (e.g. `~co`) to free `~cc` for live
chains; keep `~cc*` concert aliases deprecated for one cycle. Risk: low–medium
(reference updates across data_only/). Depends on: A (shared note helper makes
concert refs cleaner).

### Lot C — Clock unification
One master `TempoClock` (the default), concert/launchpad clock becomes a slave
(or the same clock) so a tempo change propagates; serialize tempo writes
through a single `~setTempo` so vdmx/web/OSC don't race. Risk: medium (live
feel/timing). Depends on: B.

### Lot D — Centralized OSC
A single OSC registry/dispatcher (`control/osc.scd`): one place that declares
ports, registers handlers idempotently, and resolves the `/control/*`
collision (launchpad vs web_bridge) by explicit routing. Risk: medium.
Depends on: B (clear namespaces), C (tempo routes go through `~setTempo`).

### Lot E — Split giant files
Break `jump.scd`, `live.scd`, `scenes.scd`, `live_fx_panel.scd` into focused
modules by responsibility (mechanical, large). Risk: medium (load order).
Depends on: A–D (so extracted modules use the consolidated helpers).

### Lot F — Unify boot universes
Shared `engine`/`setup` and a single entry point with a `--mode live|data`
flag, replacing the two parallel bootstraps. Risk: HIGH (the concert spine).
LAST; depends on all prior lots (shared helpers/clock/OSC make the merge
tractable).

---

## Lot A — detailed design (the first implementation target)

### Problem
Degree→MIDI-note and scale definitions are duplicated and divergent:
- `~lpNote.(deg, oct)` in `data_only/launchpad.scd:136` (nil-guards `~ccNote`,
  falls back to a hardcoded `[0,2,3,5,7,8,10]` minor over root 45).
- `~ccNote` in the concert engine (`data_only/scene_concert.scd`) resolving
  against `~ccHarmony` (root/scale/octave/phrase) and `~ccScales`.
- `~fpResolve` in `control/finger_piano.scd` with its own `~fpScaleArr` and an
  embedded 8-scale fallback table (because `palette/scales.scd` is not loaded
  in data-only mode).
- `palette/scales.scd` — the LIVE source of truth for scale arrays, not loaded
  in data-only.

### Design
Create one self-contained, dependency-free module
**`sound_algo/palette/note.scd`** that is the single source of truth for
scales and degree→note, loadable by BOTH boot paths (LIVE and data-only):

- `~scales` — an `IdentityDictionary` of named scales as **degree-offset**
  arrays (semitone offsets from root, e.g. `minorPent: [0,3,5,7,10]`,
  `minor: [0,2,3,5,7,8,10]`, dorian/phrygian/blues/japanese/hijaz/hirajoshi).
  This is the canonical list; existing absolute-MIDI arrays in
  `palette/scales.scd` (e.g. `~scaleMinorPent = [60,63,...]`) are kept and
  rederived from `~scales` + root 60 so LIVE callers are unaffected.
- `~noteFor.(degree, scaleName, root, octave)` → MIDI note Integer. Pure,
  nil-guarded, wraps degree over the scale with octave carry. Single
  implementation used everywhere.
- `~freqFor.(degree, scaleName, root, octave)` → `~noteFor(...).midicps`.

### Migration (behavior-preserving)
- `~lpNote.(deg, oct)` becomes a thin wrapper over `~noteFor` using the concert
  harmony state (`~ccHarmony.root/scale/octave`) with the SAME default it has
  today (root 45, minor) when concert state is absent.
- `~ccNote` becomes a thin wrapper over `~noteFor` reading `~ccHarmony`.
- `finger_piano.scd`: `~fpScaleArr` and `~fpScales` are derived from `~scales`
  (no more re-embedded fallback table); `~fpResolve` keeps its signature and
  output, internally calling `~noteFor`. The data-only boot loads
  `palette/note.scd` before `finger_piano.scd`, removing the "scales absent"
  problem at its root (this generalizes the `154db32` fallback fix).
- `palette/scales.scd` keeps its public `~scaleXxx` arrays (re-derived from
  `~scales`) so LIVE melody/harmony generators are untouched.

### Loading
`palette/note.scd` is loaded:
- LIVE: by `live/_load.scd` immediately before `palette/scales.scd`.
- data-only: by `data_only/boot.scd` and `boot.data-only.scd` before
  `control/finger_piano.scd` (and before `launchpad.scd`).
Idempotent (re-load safe), single top-level block.

### Interfaces produced
- `~scales` (IdentityDictionary: Symbol → [Int offsets])
- `~noteFor.(degree:Int, scaleName:Symbol, root:Int=60, octave:Int=0) -> Int`
- `~freqFor.(...) -> Float`
- Unchanged public surface: `~lpNote`, `~ccNote`, `~fpResolve`,
  `~scaleMinorPent` & friends (now derived, same values).

### Testing
- New `sound_algo/tests/test_note.scd` (headless, `0.exit`): asserts
  `~noteFor.(0,\minorPent,60,0) == 60`, `~noteFor.(5,\minorPent,60,0)` wraps
  with octave carry, `~freqFor` == `.midicps`, and that the derived
  `~scaleMinorPent` equals the historical `[60,63,65,67,70,72,75,79]` (parity).
- Parity check for `~fpResolve`: same note output as before for a sample
  (hand, finger) given the same scale/root.
- Balance `P:0 B:0` on `note.scd` + every edited file; `tests/run_all.sh` green;
  headless boot smoke (LIVE + data-only) reaches READY.

### Files (Lot A)
New: `sound_algo/palette/note.scd`, `sound_algo/tests/test_note.scd`.
Edit: `palette/scales.scd` (derive arrays from `~scales`),
`data_only/launchpad.scd` (`~lpNote` → wrapper), `data_only/scene_concert.scd`
(`~ccNote` → wrapper), `control/finger_piano.scd` (derive scales, `~fpResolve`
→ `~noteFor`), `live/_load.scd`, `data_only/boot.scd`, `boot.data-only.scd`
(load `note.scd`).

## Out of scope (for the whole refactor)
- Touching the 1099 instrument SynthDefs or the 345 track files individually
  (only their loaders/helpers, when a lot requires it).
- Changing the musical content / sound design.
- Rewriting the Python (`data_only_viz`) or Swift (`launcher`) sides.

## Verification strategy (all lots)
Existing E2E suite (`sound_algo/tests/run_all.sh`) + per-file balance check +
headless boot smoke in both modes +, where a lot has logic, a dedicated
headless `.scd` test. A lot is done only when all are green and behavior parity
is confirmed.
