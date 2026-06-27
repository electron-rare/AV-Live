# Body-trigger framework — Phase 1 (skeleton data + FX/dramatic gestures)

Date: 2026-06-27
Status: design approved, pending spec review
Scope: `sound_algo/data_only/` + `sound_algo/control/data_feeds.scd` + `data_only_viz/pose_bridge.py`

## Goal

Make the body fire EVENTS during the concert, via an extensible gesture→event
framework (not a fixed list). Phase 1 ships: (A) a skeleton data layer feeding
the full body to SC, (B) the `~ccGesture` framework (declarative registry +
engine evaluation with hold/cooldown), and (C) a master "event FX" layer + a
first batch of FX/dramatic gestures (jump, stomp, squat, spin, T-pose →
crash/drop, kick, breakdown, stutter, swell). Adding ANY future trigger =
register one more `~ccGesture` — Phase 2 (harmonic/melodic triggers + a global
`~ccHarmony` the morceaux read) plugs into the SAME framework with no engine
change.

## Context — what exists

Concert mode (`scene_concert.scd` + 8 morceaux) runs body-driven, advance via
crossed wrists. Pose signals in SC: `~poseKin` (speed/accel/symmetry),
`~poseState` (posture), `~poseCenter` (cx/cy/depth), `~poseWrist` (lx/ly/rx/ry),
and `~ccPose` wrist-backs `pose[\hands]` at distance. The data-only FX rack
(`engine.scd`) is reverb+comp+limiter on `out=0`; morceaux `Out.ar(0, ...)` into
it. At full-body distance MediaPipe gives reliable BODY joints (not hands/face
mesh) — this layer is body-only.

## A. Skeleton data layer

`data_only_viz/pose_bridge.py` (`_emit_person`) sends a compact fixed-layout
route from the MediaPipe-33 body landmarks of the first/each person:

```
/pose/skel  <pid> <nose.x nose.y> <shL.x shL.y> <shR.x shR.y>
            <hipL.x hipL.y> <hipR.x hipR.y> <kneeL.x kneeL.y> <kneeR.x kneeR.y>
            <ankL.x ankL.y> <ankR.x ankR.y>
```
(MediaPipe indices: nose 0, shoulders 11/12, hips 23/24, knees 25/26, ankles
27/28; normalized 0–1, y=0 top.) Throttled with the other pose sends.

SC (`control/data_feeds.scd`): OSCdef `\poseSkel` → `~poseSkel[pid] = (nose:(x,y),
shL:, shR:, hipL:, hipR:, kneeL:, kneeR:, ankL:, ankR:)` (each an Event with x,y),
cleared on `\poseLeave`. Head orientation derived where needed (e.g. tilt =
nose.x vs shoulder-midpoint.x; nod = nose.y vs shoulder.y).

## B. The `~ccGesture` framework

A registry mirroring the morceau registry, owned by the concert engine:

```
~ccGestures = [];
~ccGestureAdd = { |g| ~ccGestures = ~ccGestures.add(g) };
// g = (
//   name: \jump, family: \fx,
//   hold: 0.0,        // seconds the detect must stay true before firing (0 = instant)
//   cooldown: 0.8,    // seconds before it can fire again
//   detect: { |pose, prev| /* -> Boolean, reads pose[\skel]/[\center]/[\wrist]/[\kin] + prev for velocity */ },
//   fire:   { /* the event: play a synth, set a master FX param, ... */ },
//   release:{ /* optional: called once when a held gesture ends (e.g. squat -> end breakdown) */ },
// )
```

Engine evaluation, each control tick (in the existing `~concert` routine):
- snapshot `pose = ~ccPose.value` (extended below) and keep `prev` (last tick's).
- for each registered gesture: evaluate `detect.(pose, prev)`. Track per-gesture
  `holdT` and `lastFire` in a parallel state dict keyed by gesture name. When
  detect is true and `holdT >= hold` and `now - lastFire > cooldown` → `fire`,
  set `lastFire`, reset `holdT`. For `hold>0` gestures, also call `release` once
  when detect goes false after having fired (for held events like squat).
- The gesture layer runs ALONGSIDE the current morceau (whose continuous
  arm/body mappings are unchanged) and the advance detector.

`~ccPose` snapshot gains: `skel:` (from `~poseSkel`), and the engine passes the
PREVIOUS snapshot to `detect` so velocity gestures (jump cy-velocity, stomp
ankle-velocity) need no per-gesture state.

## C. Master event-FX layer

FX events act on what's currently playing, so they need a master processing
stage + event one-shots. Add (in `scene_concert.scd` or a small
`concert_fx.scd` loaded by boot):
- A **master filter** Synth on a bus the morceaux route through (or reading the
  main mix), with a controllable lowpass cutoff `~ccMaster[\cut]`; default open.
  Squat → sweep `~ccMaster[\cut]` down (breakdown); release → sweep back up.
  Jump → quick dip-and-release of the cutoff (the "drop").
- A **stutter / beat-repeat** on the master, engaged for ~1 s by spin.
- **Event synths** (one-shots, into `out=0`): `\cc_ev_crash` (jump), `\cc_ev_kick`
  (stomp, a heavy kick), `\cc_ev_swell` (T-pose, a rising pad+noise into reverb).

Routing: the cleanest is a master FX group between the morceaux and the existing
reverb/comp/limiter rack — the plan picks the concrete SC routing (a dedicated
bus + a master synth in a group ordered after the morceaux, before the rack).

## First batch of gestures (FX/dramatic family)

| name | detect (on the skeleton snapshot) | hold | event (fire / release) |
|------|-----------------------------------|------|------------------------|
| `\jump` | body `cy` rises fast: `pose.center.cy < prev.center.cy - 0.06` | 0 | `\cc_ev_crash` + master cutoff dip-and-release |
| `\stomp` | an ankle drops fast: `max(ankL.y, ankR.y velocity) > 0.05/tick` (plant) | 0 | `\cc_ev_kick` (heavy) |
| `\squat` | hips near knees: `mean(hip.y) > mean(knee.y) - 0.10` | 0.6 | sweep master cutoff DOWN (breakdown); `release` sweeps it back UP |
| `\spin` | shoulders swap x: sign of `(shR.x - shL.x)` flips vs prev | 0 | engage master stutter for ~1 s |
| `\tpose` | wrists wide at shoulder height: `\|wristR.x - wristL.x\| > 0.4` and wrists near `shoulder.y ± 0.12` | 0.8 | `\cc_ev_swell` + reverb send up |

All five are GLOBAL (same gesture → same event in any morceau), so they're
learnable and don't depend on the active morceau.

## Testing

- `.scd` balance (`P:0 B:0`, TLB:1 for `.load` files) + headless load on GrosMac
  sclang (server output-only; macOS has no `timeout` → background+kill).
- Framework unit (headless): register a stub gesture, feed synthetic `~poseSkel`
  + a `prev`, assert `fire` runs once after `hold` and not again within
  `cooldown`; `release` runs when a held detect drops.
- Each batch gesture (headless): feed a synthetic skel that satisfies its
  `detect` (e.g. cy drop for jump, hip≈knee for squat) and assert its event
  synth is created / master param moves. SynthDefs `\cc_ev_*` compile.
- Live smoke on macm1 (concert running): jump → crash+drop audible, stomp →
  kick, squat → breakdown sweep + release, spin → stutter, T-pose → swell. Tune
  thresholds by ear.

## Out of scope (Phase 2 — same framework, separate spec)

- Harmonic triggers: a global `~ccHarmony` (root/scale/pad) that gestures change
  (step→transpose, lean→pad bright/dark, head-tilt→scale) and the morceaux READ
  for their chords/pads (a morceau refactor).
- Melodic triggers: `~ccHarmony[\phrase]` changed by gestures (arm-raise→next
  phrase, head up/down→octave), morceaux read it for lead/arp notes.
- Percussion/texture gestures (foot-tap→hat, etc.) — register more `~ccGesture`.
- Multi-person (per-person gesture layers).
These all register via `~ccGestureAdd` with no engine change — that is the point
of the framework.

## Implementation note (for the plan)

Decompose: (1) skeleton data layer (`/pose/skel` + `~poseSkel`) + extend
`~ccPose` with `skel` and prev-snapshot plumbing. (2) The `~ccGesture` framework
+ engine evaluation loop (validated with a stub gesture). (3) The master event-FX
layer (master filter + stutter + `\cc_ev_*` synths + routing). (4) The five
batch gestures, one or two per task, each tested. Each step independently
testable headless; audio tuned at the live smoke.
