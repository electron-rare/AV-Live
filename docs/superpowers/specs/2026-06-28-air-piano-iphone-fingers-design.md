# Air-Piano: iPhone finger tracking into SuperCollider

**Date:** 2026-06-28
**Status:** Approved design, ready for implementation plan
**Scope:** Bring per-finger strike data from the iPhone hand tracker into
SuperCollider so the performer can play notes "like a piano" in the air, plus
continuous parameter modulation from hand spacing.

## Goal

The performer plays notes by striking fingers downward in the air (air-piano).
Each finger maps to a fixed scale degree; hand position shifts octave/transpose;
strike speed (or depth) gives velocity. Simultaneously, the distance between the
two hands and their mean position modulate global synth/FX parameters in
continuous fashion.

## Background: existing pipeline (verified)

- The iPhone app `iphone-arbody/` sends Vision HandPose: 21 joints x 2 hands
  (MediaPipe joint order), ~15 fps, over USB/AVLiveWire (TCP :7000). OSC
  `/body3d/kp` on :57128 is legacy/disabled.
- `data_only_viz/iphone_usb_source.py` receives hands into
  `state.persons_hands` (list of hands, each 21 joints x,y,z,confidence).
- `data_only_viz/action_head_pub.py::ActionHeadPublisher` runs a ~30 Hz thread.
  In `_tick()` it calls `_emit_hands()`, which reads `state.persons_hands`
  under `state.lock()`, computes features with
  `data_only_viz/hand_features.py::HandFeatureExtractor`, and emits OSC via
  `data_only_viz/pose_bridge.py::PoseSoundBridge.send_hands()` to
  `127.0.0.1:57121` as:
  `/pose/hands [pid, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]`.
- SuperCollider receives `/pose/*` in `sound_algo/control/data_feeds.scd`
  (port 57121). `OSCdef(\poseHands)` stores left/right hand features into the
  `~handFeat` dict (`\lx \ly \lopen \lspeed \rx \ry \ropen \rspeed \dist`).
- MediaPipe hand joint indices (from `apple_vision_pose.py`):
  - Wrist = 0
  - Thumb: CMC 1, MP 2, IP 3, Tip 4
  - Index: MCP 5, PIP 6, DIP 7, Tip 8
  - Middle: MCP 9, PIP 10, DIP 11, Tip 12
  - Ring: MCP 13, PIP 14, DIP 15, Tip 16
  - Little: MCP 17, PIP 18, DIP 19, Tip 20
  - Fingertips `(4, 8, 12, 16, 20)` = thumb, index, middle, ring, pinky.

**Gap:** per-finger data stops at `data_only_viz`. SC only gets aggregate hand
features. The fine finger data never reaches SC.

## Architecture (Hybrid)

Robust signal processing (strike detection + velocity) lives in Python, where
the raw 30 Hz joint history and numpy already are. All musicality lives in SC
(scale, finger->degree mapping, octave, instrument choice, modulation routing)
so it stays live-codeable during performance. A few detection thresholds are
exposed as environment variables for rehearsal tuning.

```
state.persons_hands (21x3 per hand)
   |
   v  (action_head_pub _tick, ~30 Hz, under state.lock)
FingerStrikeDetector  --strike-->  PoseSoundBridge.send_finger()
   |                                    |
   |                                    v
   |                         OSC /pose/finger -> :57121
   |
   +-- _emit_hands() unchanged (continuous /pose/hands carries dist + positions)
                                        |
                                        v
                  SuperCollider control/finger_piano.scd
                    - OSCdef(\poseFinger): note triggering (air-piano)
                    - continuous modulation hook from ~handFeat
                    - ~fp live API
```

### New OSC message (event-based, only on strike)

```
/pose/finger  <pid> <hand> <finger> <strikeSpeed> <z> <tipx> <tipy>
  pid          int    person id (single performer assumed; 0)
  hand         int    0 = left, 1 = right
  finger       int    0..4 = thumb, index, middle, ring, pinky
  strikeSpeed  float  0..1 normalized peak downward speed of the strike
  z            float  fingertip depth (raw, noisy; SC may use for velocity)
  tipx, tipy   float  fingertip image coords at strike (context for SC)
```

Continuous modulation produces NO new message: SC reads `~handFeat[\dist]` and
hand positions, already updated at 30 Hz by `/pose/hands`.

## Component 1 - Python strike detector

**New file:** `data_only_viz/finger_strike.py`

`class FingerStrikeDetector`:
- Keeps a short per-(hand-slot, finger) history of the fingertip position
  **relative to that finger's MCP knuckle** (thumb relative to its MP joint).
  Using the tip-minus-MCP vector isolates finger flexion from whole-hand
  translation, so moving the whole hand down does not fire all 10 fingers.
- Detects a strike when the downward component of the relative-tip velocity
  exceeds `FINGER_STRIKE_VEL`, the finger was previously "up", and the last
  strike for that finger was more than `FINGER_STRIKE_REFRACTORY_MS` ago.
- Computes `strikeSpeed` from the peak downward velocity during the press,
  normalized to [0,1].
- `step(persons_hands, t_now) -> list[StrikeEvent]` returns zero or more strikes
  for this tick. Pure function of inputs + internal history; no I/O.

Hand-slot identity (which detected hand is "left" vs "right") follows the same
left/right assignment already used by `HandFeatureExtractor` (sort by cx) so the
`hand` field is consistent with `/pose/hands`.

**Integration:** in `data_only_viz/action_head_pub.py`, add `_emit_fingers()`
called from `_tick()` right after `_emit_hands()`, inside the existing
`state.lock()` usage pattern. It instantiates one `FingerStrikeDetector`
(member), calls `step()`, and for each strike calls a new
`PoseSoundBridge.send_finger(...)`.

**New file/edit:** `data_only_viz/pose_bridge.py` gains
`send_finger(pid, hand, finger, strike_speed, z, tipx, tipy)` mirroring
`send_hands()` (same `SimpleUDPClient` to 127.0.0.1:57121).

**Env vars (new):**

| Env | Default | Effect |
|-----|---------|--------|
| `FINGER_PIANO` | `0` | `1` to enable finger strike emission |
| `FINGER_STRIKE_VEL` | `0.02` | downward relative-velocity threshold (normalized image units per frame; tune in rehearsal) |
| `FINGER_STRIKE_REFRACTORY_MS` | `120` | min ms between strikes per finger |

When `FINGER_PIANO` is unset/0, `_emit_fingers()` is a no-op (zero overhead,
harmless if no iPhone is broadcasting).

## Component 2 - SuperCollider air-piano

**New file:** `sound_algo/control/finger_piano.scd`, loaded by the data-only
boot alongside `data_feeds.scd`. Idempotent (`.free` then re-register OSCdef,
matching the existing convention in `data_feeds.scd`).

Contents:

- **`OSCdef(\poseFinger)`** on `/pose/finger`:
  1. Look up the scale degree: `~fpMap[hand][finger]` (configurable table).
     Default: left hand = degrees 0..4 (thumb..pinky) in the base octave,
     right hand = degrees 0..4 one octave up.
  2. Octave/transpose offset from hand x position read from `~handFeat`
     (`\lx` / `\rx` depending on `hand`), quantized to octave steps around
     `~fpOctave`.
  3. Velocity: map `strikeSpeed` (default) or `z` (switchable live via
     `~fpVelSource`) through `~fpSens` to an amp.
  4. Resolve degree -> note using the current scale (`palette/scales.scd`:
     `~scale`, `~root`) -> frequency.
  5. Trigger the instrument `~fpInst` as a one-shot
     (`Synth(~fpInst, [\freq, f, \amp, vel, \gate, 1, ...])` with its own
     envelope `doneAction: 2`, or play through the existing melody instrument
     path). Default instrument: an existing pleasant lead/keys SynthDef; no new
     SynthDef unless the user later wants a dedicated piano timbre.
- **Continuous modulation hook:** extend `data_feeds.scd`'s `\poseHands` OSCdef
  with a single call to `~fpModTick.value` (defined in `finger_piano.scd`, a
  no-op stub if the file is not loaded). `~fpModTick`:
  - `~handFeat[\dist]` -> master VCF cutoff (default target)
  - mean hand Y -> FX send level
  - routable via `~fpMod.(\target, \source)`; smoothing with a one-pole lag to
    avoid zipper noise.
- **Live API `~fp`** (env-direct wrappers, following the project's live-wrapper
  convention since pseudo-method dispatch is broken in SC):
  - `~fpOn.()` / `~fpOff.()` - enable/disable note triggering
  - `~fpScale.(\dorian)` - set scale
  - `~fpInst_.(\rhodes)` - set instrument SynthDef name
  - `~fpSens.(0.5)` - velocity sensitivity
  - `~fpOctave.(3)` - base octave
  - `~fpVelSource.(\strike | \z)` - velocity source
  - `~fpMap` - directly editable finger->degree table

## Runtime topology

This feature runs on the pose-reactive concert path, where `data_only_viz` (the
only place hand data exists) and `data_feeds.scd` are active, reusing port
57121. Pure LIVE mode (`00_load.scd`) can use it too, provided the Python pose
bridge runs alongside; `finger_piano.scd` can be optionally loaded there.

## Single-performer assumption

`/pose/hands` already emits `pid = 0`. The air-piano targets a single performer
(left/right hands of one person). Multi-performer finger piano is out of scope.

## Testing

**Python (pytest under `data_only_viz`):** unit-test `FingerStrikeDetector`
with synthetic fingertip trajectories:
- a single downward relative-flexion spike -> exactly one strike;
- whole-hand downward translation (tip and MCP move together) -> zero strikes;
- two strikes inside the refractory window -> only the first fires;
- `strikeSpeed` increases with steeper downward velocity.

**SuperCollider:** a `.scd` test that sends synthetic `/pose/finger` messages to
SC's own port and verifies a note is triggered (and `~fpOff` suppresses it),
plus the mandatory parentheses/brackets balance check (`validating-scd-files`).

**Manual:** a debug `postln` of each received strike (hand, finger, note, vel)
during rehearsal to tune `FINGER_STRIKE_VEL`.

## Out of scope (YAGNI)

- Spatial-keyboard layout (horizontal position selects key) - rejected in favor
  of the hybrid layout.
- Pinch / flexion-hold note mechanics - rejected in favor of air-strike.
- New dedicated "piano" SynthDef - instrument is configurable; add later only if
  desired.
- Multi-performer finger piano.
- Sending finger data over a new port or transport - reuses :57121.

## Files touched

New:
- `data_only_viz/finger_strike.py`
- `data_only_viz/tests/test_finger_strike.py` (path per project test convention)
- `sound_algo/control/finger_piano.scd`
- `sound_algo/control/test_finger_piano.scd` (or under the project's test dir)

Edited:
- `data_only_viz/action_head_pub.py` (add `_emit_fingers()`)
- `data_only_viz/pose_bridge.py` (add `send_finger()`)
- `sound_algo/control/data_feeds.scd` (add `~fpModTick.value` hook in
  `\poseHands`)
- data-only boot loader (load `control/finger_piano.scd`)
- `CLAUDE.md` env-var table (document `FINGER_PIANO` family)
