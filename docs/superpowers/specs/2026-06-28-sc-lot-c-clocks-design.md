# SC Refactor Lot C — Clock unification — design

**Date:** 2026-06-28
**Status:** Approved scope (single clock), design for review
**Parent:** `2026-06-28-sc-harmonize-refactor-design.md` (Lot C). Reordered ahead
of Lot B per user decision.

## Goal

Collapse the four independent SC clocks into ONE (`TempoClock.default`) and
route every runtime tempo change through a single coordinated `~setTempo.(bpm)`,
so changing the tempo from any controller stays globally consistent and the
concert/launchpad/body-play layers no longer drift from the live tempo.

## Current state (from audit)

Four clocks, none synchronized:
- `TempoClock.default` — all LIVE Pdefs; 11+ uncoordinated writers.
- `~lp[\clock]` — `launchpad.scd:94`, `TempoClock(126/60).permanent_(true)`,
  launchpad Pdefs / `~lpArm`.
- `~concert[\clock]` — `scene_concert.scd:140`, `TempoClock(126/60)…`, concert
  Routine + morceaux build-ups (138/145/156 then reset 126).
- `~bpEngine[\clock]` — `scene_pose_play.scd:89`, `TempoClock(100/60)…`,
  body-play Routine.

sclang is single-threaded → no data race, but last-writer-wins and the layers
never follow each other (web tempo change leaves launchpad/concert at 126;
`/launch/tempo` leaves the live Pdefs unchanged).

## Design — one clock via aliasing + a single setter

### 1. Single clock by aliasing (minimal churn)
The three secondary clock SLOTS become aliases of `TempoClock.default` instead
of separate `TempoClock` instances. Every existing `.play(~lp[\clock])`,
`.play(~concert[\clock])`, `.play(~bpEngine[\clock])`, and every
`~xxx[\clock].tempo = …` keeps compiling and now operates on the single clock —
no call-site rewrites needed.
- `launchpad.scd:94`   → `~lp[\clock]      = ~lp[\clock]      ? TempoClock.default;`
- `scene_concert.scd:140` → `~concert[\clock] = TempoClock.default;`
- `scene_pose_play.scd:89` → `~bpEngine[\clock] = TempoClock.default;`

### 2. Single coordinated setter
In `engine.scd` (where `~bpm` lives), add:
```supercollider
~setTempo = { |bpm|
    ~bpm = bpm.clip(20, 300);
    TempoClock.default.tempo = ~bpm / 60;
    ("[tempo] " ++ ~bpm ++ " BPM").postln;
};
```
One clock → setting `TempoClock.default.tempo` IS setting every layer.

### 3. Route runtime tempo writers through `~setTempo`
Replace direct `~bpm = …; TempoClock.default.tempo = …` (and the
`~lp[\clock].tempo`/`~concert[\clock].tempo` writes) with `~setTempo.(bpm)` in
the runtime CONTROLLER paths:
- `web_bridge.scd:176-177` (`/control/bpm`)
- `control/web_bridge.scd:97-99` (`~applyTempo`)
- `pd/bridge.scd:51, 102` (`/play`, `/tweak/bpm`)
- `control/vdmx_send.scd:93` (`/ctl/bpm`)
- `live/midi_init.scd:94` (CC 36)
- `data_only/launchpad.scd:333-337` (`/launch/tempo` — both writes collapse to
  one `~setTempo`)
- `control/finger_piano.scd` (`/control/fp bpm`)
- `live/scenes.scd:61` (`~loadScene` tempo recall)
- `data_only/morceaux/*.scd` (build-up `update`/`stop` tempo writes — now drive
  the global tempo, which is the intended "the whole track speeds up")

### 4. Per-scene initial tempo (explicit)
Clocks no longer carry their own 126/100 init. Each mode sets its base tempo
once, via `~setTempo`, on entry:
- data-only concert/launchpad boot → `~setTempo.(126)`.
- body-play scene entry → `~setTempo.(100)`.
- LIVE boot (`live/_load.scd:111`, already sets default) → `~setTempo.(~bpm ? 132)`.

### 5. Intentional exceptions (NOT routed through `~setTempo`)
- **Tape-stop ramps** (`live/live.scd:766-796`): progressive `TempoClock.default.tempo`
  glissando is an AUDIO EFFECT that ramps then restores; it must write the clock
  directly and must NOT touch `~bpm`. Left as direct clock writes (documented).
- **Track-init** (`tracks/*.scd`): each track sets `TempoClock.default.tempo =
  ~bpm/60` at start; with one clock this already works and rewriting ~345 files
  is out of scope. Left as-is.
- **Manual dev preset blocks** (`live/tweaks.scd`, `live/live_fx_panel.scd`,
  `00_load.scd`, `01_live.scd`): IDE Cmd+Enter helpers; left as-is.

## Behavior changes (called out)
- Concert, launchpad, and body-play now share the global tempo. A tempo change
  from any controller moves every layer together (the fix).
- Morceaux build-ups now change the GLOBAL tempo (whole track speeds up), not a
  separate concert clock. Intended.
- The separate 126/100 default tempos are gone; each scene sets its base via
  `~setTempo` on entry. If a scene's entry tempo call is missing, that scene
  inherits the current global tempo (must verify each entry sets it).

## Components / files
- New: `~setTempo` in `sound_algo/engine.scd` AND `sound_algo/data_only/engine.scd`
  (both engines, since the two boot universes load different engine files).
- Edit (alias clocks): `data_only/launchpad.scd`, `data_only/scene_concert.scd`,
  `data_only/scene_pose_play.scd`.
- Edit (route writers): the controller files listed in §3.
- Edit (per-scene init): boot/scene-entry points in §4.

## Testing
- New headless `sound_algo/tests/test_tempo.scd`: define a stub
  `TempoClock.default`, call `~setTempo.(140)`, assert `~bpm == 140` and
  `TempoClock.default.tempo == 140/60`; assert that after the alias lines run,
  `~lp[\clock] === TempoClock.default` and `~concert[\clock] === TempoClock.default`.
- Balance `P:0 B:0` on every edited modular `.scd`.
- Boot smoke (LIVE + data-only) reaches READY; `run_all.sh` at merge.
- Live smoke at merge: change tempo from one controller, confirm launchpad +
  concert + live patterns all follow.

## Out of scope
Track-init files, tape-stop ramp internals, dev preset blocks (see §5). Lot B
(namespace rename) deferred. No sound-design changes.
