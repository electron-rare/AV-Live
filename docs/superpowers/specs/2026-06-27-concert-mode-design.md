# Concert mode — body-driven techno setlist

Date: 2026-06-27
Status: design approved, pending spec review
Scope: `sound_algo/data_only/` (SuperCollider) + one OSCdef in `sound_algo/control/data_feeds.scd`

## Goal

Expand body-play into a full **techno concert**: a sequential setlist of 8
distinct "morceaux" (hard / dub / acid / hypnotic), each a unique instrument
with its OWN SynthDefs, rhythm, and custom body→sound mapping. The performer
advances through the setlist with a signature gesture (arms crossed), and the
iPhone-tracked body plays each morceau. Driven by the existing pose pipeline
(`data_only_viz --iphone-usb` → `/pose/*` OSC → SC).

## Context — what already exists

Body-play (`scene_pose_play.scd` + `synthdefs_play.scd`) has 3 modes selected
by posture, one shared palette (`\bp_*`). Concert mode is a NEW, richer scene
alongside it; body-play stays as-is.

Pose signals already arrive in SC (populated by OSCdefs in
`control/data_feeds.scd`), keyed by pid:
- `~poseState[pid]` = `(labelIdx:, probs:)` — posture/action (0/1/2).
- `~poseKin[pid]` = `(speed:, accel:, symmetry:)` — body kinematics.
- `~handFeat` = `(lx:, ly:, lopen:, lspeed:, rx:, ry:, ropen:, rspeed:)` —
  per-hand position (normalized 0–1), openness, speed.
- NEW (this design): `~poseCenter[pid]` = `(cx:, cy:)` from `/pose/center`,
  for spatial position; depth proxy via `/pose/sho_span` → `~poseCenter[pid][\depth]`.

Lifecycle infra (`scenes.scd`): `~doScene` is exclusive (calls `~doStopAll`
first), `~doRegisterPriv.(name, killFn)` registers a scene's teardown, the FX
rack (reverb + comp + limiter) runs on `out=0`. SC remote: `/control/doScene <name>`.

## Architecture

### The concert engine (`~concert`)

A single Event holding the setlist and runtime state, driven by a Routine on a
`TempoClock` (control tick in beats, like `~bpCtlDur`). It:
- holds `~concert.morceaux` — an ordered list of morceau modules.
- tracks `idx` (current morceau), starts `morceaux[0]` on `\start`.
- each control tick: calls the current morceau's `update` with the live pose
  snapshot, AND runs the advance-gesture detector.
- on advance: **crossfade** — the current morceau's `stop` releases its synths
  with a fade (~2–3 s) while the next morceau's `start` fades in; `idx` += 1
  (clamped at the last morceau — linear, no wrap).
- registers a single kill via `~doRegisterPriv.(\concert, { ~concert.stop })`
  so `~doStopAll` / scene switch / `\stop` tears the whole concert down.

### Morceau module interface

Each morceau is a self-contained Event with one clear responsibility (its
instrument). Uniform interface so the engine treats them identically:

```
(
  name: "Hard Pump", style: \hard,
  defs: [ /* SynthDef names this morceau owns */ ],
  start: { |ctx| /* build synths + per-morceau sequencer state into ctx */ },
  update: { |ctx, pose| /* map pose (handFeat/kin/center) → synth params */ },
  tick:   { |ctx, pose, beat| /* optional: per-beat rhythmic events */ },
  stop:   { |ctx| /* release this morceau's synths with a fade */ },
)
```

- `ctx` is a per-morceau scratch Event the engine creates on `start` and passes
  back to `update`/`tick`/`stop` (holds the morceau's live Synths, sequencer
  counters, smoothed values). Keeps morceaux isolated — no global leakage.
- `pose` is the snapshot the engine reads once per tick: first-person
  `~poseKin`/`~poseState`/`~poseCenter` + `~handFeat`, nil-guarded.
- `update` runs every control tick (continuous param mapping); `tick` runs on
  rhythmic subdivisions (note/percussion triggers). A morceau may use either or both.

### Advance gesture — arms crossed

Detected from `~handFeat`: right hand crossed to the left of the left hand
(`rx < lx - margin`) with both hands near chest height (`ry` and `ly` in a mid
band), sustained ≥ ~1.5 s, then a cooldown (~3 s) before it can fire again. The
engine owns this detector (not the morceaux). On fire → `~concert.next`.

### SynthDef conventions (per-morceau, `synthdefs_concert.scd`)

Each morceau owns its SynthDefs (prefix `\cc_<morceau>_*`, e.g. `\cc_hardpump_kick`).
Shared rules: stereo `Pan2.ar`/`Out.ar(0, ...)` into the global FX rack;
`doneAction: 2` on one-shots; gated `\gate` envelope for sustained voices
(drones, dub chords, acid line) so `update`/`stop` can release them; clip freqs;
lowercase `~`-vars only. Sequenced rhythm lives in the morceau's `tick`, not in
the SynthDef.

## The setlist (8 morceaux)

Arc: **Hypnotic build → Acid → Hard (peak) → Dub (comedown)**.

| # | Morceau | Style | Sound | Custom body mapping |
|---|---------|-------|-------|---------------------|
| 1 | **Hypno Drift** | hypnotic | deep filtered drone + sparse sub pulse | hands height (ry/ly) → drone filter cutoff (opens the space); body cx → stereo drift; very sparse kick on slow pulse |
| 2 | **Hypno Roll** | hypnotic | rolling 16th loop: muted stab + tight kick + shaker | body speed → loop density/energy; left hand → filter sweep; depth (recul) → reverb send |
| 3 | **Acid Line** | acid | resonant 303 (saw + slide) + kick | right hand height → cutoff, right openness → resonance; left hand → octave/accent pattern; speed → tempo. The body plays the line |
| 4 | **Acid Storm** | acid/hard | overdriven 303 + harder kick + noise | acid controls + right-hand speed → distortion/drive; both arms high → screech/peak fill |
| 5 | **Hard Pump** | hard | distorted hard kick + rumble + tight perc | speed → kick intensity/distortion + rumble depth; left hand → highpass; cx position → which perc layer |
| 6 | **Hard Rave** | hard | hoover/stab + hard break + crash | right hand → stab trigger + note; left hand height → chord/transpose; jump (accel spike) → crash + impact; speed → break density |
| 7 | **Dub Chords** | dub | filtered dub chord + long delay + deep sub | right hand → chord trigger; both hands → delay feedback + filter; tempo kept low; spacious |
| 8 | **Dub Space** | dub | minimal: sub + clicks + big reverb | depth (recul, sho_span) → reverb size; hands → sparse triggers; the body recedes into space. Outro |

Per-morceau scales/keys are chosen to fit the style (e.g. acid in a phrygian/
minor pentatonic, hard in a single-note rumble, dub in a sus chord). The plan
fixes exact notes; the design fixes the identity + mapping above.

## Integration

- New scene `\concert` in `scenes.scd`'s `~doScene` switch → `~doSceneConcert.value`
  (mirrors `\play` → `~doScenePlay`). Selectable via `/control/doScene "concert"`.
- `boot.scd`: load `synthdefs_concert.scd` (after `synthdefs_play.scd`) and
  `scene_concert.scd` (after `scene_pose_play.scd`). Default boot scene: keep
  `\play` for now; switch to `\concert` is a one-line change once it's validated
  (offer it after the live smoke).
- New OSCdef `\poseCenter` (`/pose/center`) + depth from `/pose/sho_span` in
  `control/data_feeds.scd`, populating `~poseCenter`.

## Testing

- Per `.scd` edit: paren/bracket balance (P:0 B:0; TLB:1 for `.load` files) +
  confirm load via headless `sclang`.
- SynthDefs compile (boot scsynth headless, `\cc_*` all present after `s.sync`).
- Engine unit checks (headless sclang): setlist advances on a synthetic
  arms-crossed `~handFeat` held 1.5 s; `~doStopAll` tears the concert down
  (current morceau released); crossfade releases the outgoing morceau's synths.
- Live smoke on macm1 (iPhone-usb stack up): `/control/doScene "concert"`,
  perform — each morceau sounds distinct, arms-crossed advances, the body drives
  each morceau's mapping, no stuck/runaway synths across transitions.

## Out of scope

- Going backwards in the setlist (linear only; arms-crossed = next).
- Spatial-zone morceau selection (navigation is sequential by gesture).
- Visual/Metal changes — concert mode is audio (the renderer keeps showing the
  skeleton as today).
- Recording/looping/automation of a performance.

## Implementation decomposition (for the plan)

This is large (8 custom instruments). The plan should build incrementally,
each step independently testable:
1. `~poseCenter` OSCdef + the concert engine (setlist, crossfade, arms-crossed
   gesture, lifecycle) with ONE minimal morceau, validated end to end.
2–N. The morceaux in batches of ~2 (one per style pair), each a task: its
   SynthDefs + `start/update/tick/stop`, added to the setlist, tested live.
The engine and the morceau interface are the contract every morceau task targets.
