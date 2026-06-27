# Body-trigger framework (skeleton data + FX + harmonic/melodic conducting)

Date: 2026-06-27 (rev: harmonic/melodic brought IN scope)
Status: design approved, pending spec review
Scope: `sound_algo/data_only/` + `sound_algo/control/data_feeds.scd` + `data_only_viz/pose_bridge.py`

## Goal

Make the body CONDUCT the concert, via an extensible gesture→event framework
(not a fixed list). Ships: (A) a skeleton data layer feeding the full body to
SC, (B) the `~ccGesture` framework (declarative registry + engine evaluation
with hold/cooldown), (C) a master "event FX" layer + FX/dramatic gestures
(jump, stomp, squat, spin, T-pose → crash/drop, kick, breakdown, stutter,
swell), and (D) a global harmonic/melodic state `~ccHarmony` that the pitched
morceaux READ for their root/scale/pad/phrase, CHANGED by harmonic gestures
(step→transpose, lean→pad bright/dark, head-tilt→scale) and melodic gestures
(arm-raise→next phrase, head up/down→octave). Adding ANY further trigger =
register one more `~ccGesture` with no engine change — that is the framework's
whole point.

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

## D. Harmonic & melodic conducting (`~ccHarmony`)

A global harmonic/melodic state the body conducts and the pitched morceaux read:

```
~ccHarmony = (root: 45, scale: \minor, pad: \dark, phrase: 0, octave: 0);
~ccScales  = ( minor:    [0,2,3,5,7,8,10],  dorian: [0,2,3,5,7,9,10],
               phrygian: [0,1,3,5,7,8,10],  penta:  [0,2,4,7,9] );
// quantize a scale degree to the current root+scale(+octave) -> midinote
~ccNote = { |degree, oct=0|
    var sc = ~ccScales[~ccHarmony[\scale]];
    var d  = degree.asInteger;
    ~ccHarmony[\root] + ((~ccHarmony[\octave] + oct + (d div: sc.size)) * 12)
        + sc[d % sc.size];
};
```

**Morceau integration — refactor the PITCHED morceaux** (`01_hypno_drift` drone,
`03_acid_line`, `04_acid_storm`, `06_hard_rave` stabs, `07_dub_chords`,
`08_dub_space` sub) to derive their notes from `~ccNote.(degree)` instead of
baked-in roots/scales. Each keeps its OWN rhythm and degree SEQUENCE; only
root/scale/octave/pad come from `~ccHarmony`. The purely percussive morceaux
(`02_hypno_roll`, `05_hard_pump`) are untouched.

**Harmonic gestures** (register via `~ccGestureAdd`, family `\harmony`):
| name | detect (intent) | event |
|------|-----------------|-------|
| `\stepR` | stepped into screen-right zone (`center.cx > 0.70`), held 0.5 | `~ccHarmony[\root]` += 2 (clamp 33–57) |
| `\stepL` | screen-left zone (`center.cx < 0.30`), held 0.5 | `~ccHarmony[\root]` -= 2 (clamp) |
| `\leanFwd` | torso pitched forward (shoulders well above hips: `mean(sh.y) < mean(hip.y) - 0.28`) | `~ccHarmony[\pad] = \bright` (morceau pads read this) |
| `\leanBack` | upright (`mean(sh.y) > mean(hip.y) - 0.20`) | `~ccHarmony[\pad] = \dark` |
| `\tilt` | head tilt L or R (`nose.x` vs shoulder-midpoint.x beyond ±0.06), held 0.4 | cycle `~ccHarmony[\scale]` to the next `~ccScales` key |

**Melodic gestures** (family `\melody`):
| name | detect (intent) | event |
|------|-----------------|-------|
| `\armRaise` | exactly one wrist above its shoulder (the other not), held 0.4 | `~ccHarmony[\phrase]` = `(phrase+1) % 4` |
| `\headUp` | chin up (`nose.y < shoulder.y - 0.30`) | `~ccHarmony[\octave]` = 1 |
| `\headDown` | chin neutral/down (`nose.y > shoulder.y - 0.18`) | `~ccHarmony[\octave]` = 0 |

`~ccHarmony[\phrase]` (0–3) indexes a small per-morceau table of alternate degree
sequences (e.g. acid line carries 4 degree patterns and picks by `phrase`); a
morceau without a phrase table ignores it. `~ccHarmony[\pad]` (`\dark`/`\bright`)
is read by morceaux with a drone/pad to pick a brighter/darker timbre.

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

## Out of scope (the framework already supports these — add later, no engine change)

- Percussion/texture gestures (foot-tap→hat, knee→tom, arms-spread→reverb open,
  fast-shake→grain) — register more `~ccGesture`.
- Multi-person (per-person gesture layers and/or a per-pid `~ccHarmony`).
Both register via `~ccGestureAdd` with no engine change — the framework's point.

## Implementation note (for the plan)

Decompose: (1) skeleton data layer (`/pose/skel` + `~poseSkel`) + extend
`~ccPose` with `skel` and prev-snapshot plumbing. (2) The `~ccGesture` framework
+ engine evaluation loop (validated with a stub gesture). (3) The master event-FX
layer (master filter + stutter + `\cc_ev_*` synths + routing into the FX rack).
(4) The five FX/dramatic gestures (one or two per task). (5) `~ccHarmony` +
`~ccScales` + `~ccNote` global state. (6) Refactor the pitched morceaux to read
`~ccNote`/`~ccHarmony[\pad]`/`[\phrase]`. (7) Harmonic gestures (step/lean/tilt).
(8) Melodic gestures (arm-raise/head). Each step independently testable headless;
audio tuned at the live smoke.
