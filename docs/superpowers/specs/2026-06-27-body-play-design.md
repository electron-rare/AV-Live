# Body-Play: body-driven musical generation (data-only patch)

Date: 2026-06-27
Status: design approved, pending spec review
Scope: `sound_algo/data_only/` (SuperCollider data-only patch)

## Goal

Make the body actually *play music* — generate notes, sequences and evolving
textures from pose — rather than only modulating FX (which is what the existing
`scene_pose_action.scd` does). The performer's action chooses a musical mode,
their hands play a melody, and their overall movement drives the rhythm/tempo.

This is additive: `scene_pose_action.scd` (pose→FX) keeps its role and runs
alongside; its FX modulation shapes the sounds Body-Play generates.

## Paradigm (approved)

Hybrid:
- **Action → mode**: the action-head label (standing / sitting / dancing)
  selects one of three complete musical modes (scale + tempo + instruments +
  intensity), with a cross-fade between modes.
- **Hands → melody**: the **right hand plays a free lead** triggered by gesture;
  the **left hand holds a chord** that a background arpeggio plays in rhythm.
- **Body → rhythm**: overall movement speed **drives the tempo directly**
  (smoothed); the rhythm section (kick/hat/bass) runs at that tempo.

## Input data (already published to sclang :57121)

Populated by `control/data_feeds.scd` OSCdefs from `data_only_viz`:

- `~poseState[pid] = (labelIdx: 0|1|2, probs: [p0,p1,p2])` — action
  (`/pose/action`). labelIdx: 0=standing, 1=sitting, 2=dancing.
- `~poseKin[pid]   = (speed:, accel:, symmetry:)` — body kinematics
  (`/pose/kin`). speed is the mean joint speed.
- `~handFeat = (lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist)` — hand
  features (`/pose/hands`). Coordinates normalised ~0..1; `*open` = openness;
  `*speed` = per-hand speed; `dist` = inter-hand distance.

All values may be absent/nil when no body is in frame — every read defaults
with `? 0` (the underscore-in-`{}` closure trap from commit 480aa79 is a known
SC hazard: use `coll / n` or `coll.collect{|x| x/n}`, never `coll.collect{_/n}`).

## Architecture

One new module, `sound_algo/data_only/scene_pose_play.scd`, plus one new
SynthDef file `sound_algo/data_only/synthdefs_play.scd`. Four isolated units:

| Unit | What it does | Depends on |
|------|--------------|------------|
| **SynthDefs `\bp_*`** (`synthdefs_play.scd`) | the palette: lead, arp, pad, bass, kick, hat | scsynth |
| **`~bpModes`** (table in `scene_pose_play.scd`) | the 3 modes: scale, root, tempo range, active instruments, intensity | — |
| **`~bpMap`** (pure functions) | turn `~handFeat`/`~poseKin`/`~poseState` into note/chord/tempo/mode values | input data |
| **`~bpEngine`** (TempoClock + Routines + pad voice) | plays lead/arp/rhythm, runs the clock, handles mode cross-fade | the three above |

Rationale for a separate file: generation (notes/sequences/tempo/clock) is its
own concern; folding it into the FX-modulation file would overload one file.
`scene_pose_play.scd` is `.load`-compatible (single top-level `(...)` block,
P:0 B:0 TLB:1) and exposes the scene as `~doScene.(\play)`.

## Palette: `\bp_*` SynthDefs (`synthdefs_play.scd`)

All stereo via `Pan2.ar`, `LeakDC.ar` after any feedback, `clip` on freq,
`tanh` saturation where it helps, `doneAction: 2` on every one-shot envelope.

- `\bp_lead` — right-hand lead. `|out, freq, amp, dur=0.5, cutoff=2000, pan, rev|`
  Saw+detune through resonant LPF, pluck env; `cutoff` driven by `ropen`.
- `\bp_arp` — left-hand arpeggio voice. `|out, freq, amp, dur=0.25, pan, rev|`
  Soft triangle/FM pluck, short env.
- `\bp_pad` — sustained harmonic bed per mode. `|out, freq, amp, cutoff, gate=1, rev|`
  Saw cluster + slow LFO on cutoff; gated (`EnvGen.kr(Env.asr, gate, doneAction:2)`)
  so it can be cross-faded.
- `\bp_bass` — chord root. `|out, freq, amp, dur, pan, rev|` Sub sine + filtered saw.
- `\bp_kick` — `|out, amp, dur=0.3|` pitched sine drop.
- `\bp_hat` — `|out, amp, pan, dur=0.05|` filtered noise.

Per-mode timbre variation is achieved by parameterisation (cutoff/dur/amp/rev),
not by separate SynthDefs per mode.

## Modes (`~bpModes`)

Cross-faded ~2 s on a stable action change. Roots/tempos are starting points,
tunable in `~bpModes`.

| Mode | label | scale (semitone degrees) | root | tempo bpm | active | character |
|------|-------|--------------------------|------|-----------|--------|-----------|
| **Ambient** | 1 sitting | aeolian `[0,2,3,5,7,8,10]` | A2 (45) | 56–80 | pad, arp, bass — **no kick** | sparse, slow |
| **Pulse** | 0 standing | major penta `[0,2,4,7,9]` | A3 (57) | 88–120 | pad, lead, arp, bass, kick, hat | medium |
| **Drive** | 2 dancing | dorian `[0,2,3,5,7,9,10]` | G3 (55) | 118–150 | all + dense hats | energetic |

Diatonic chords I/IV/V/vi are built from each mode's scale for the left-hand
arpeggio.

## Mapping (`~bpMap`, pure functions)

- **mode** = `f(poseState.labelIdx)` with stability guard: only switch when the
  label is stable for ≥ N control ticks (default N ≈ 5, ~0.5 s at the engine's
  control rate) and/or its prob > threshold, to avoid cross-fade chatter from
  action-head jitter.
- **lead (right hand)**: pitch = `quantizeToScale(ry → degree)`; **trigger** when
  `rspeed` crosses a threshold (with a refractory window to avoid machine-gunning);
  velocity = `rspeed`; brightness `cutoff` = `ropen`.
- **chord (left hand)**: `ly → chordIndex` selects one of I/IV/V/vi; the arpeggio
  plays that chord's notes at tempo; `lopen → octave span`.
- **tempo**: `poseKin.speed → tempo`, `.lag(~2 s)` and clipped to the mode's bpm
  range (direct-but-smoothed, per the approved choice).
- **rhythm density**: `speed →` number of hat subdivisions / probability.
- **stereo**: `dist → stereo width + global octave`; `symmetry → lead/arp L–R
  balance`.

## Engine (`~bpEngine`)

- A dedicated `TempoClock` whose `.tempo` is set from the smoothed body speed
  each control tick.
- **Rhythm routine**: per beat, plays kick/bass and `density` hats per the mode.
- **Arp routine**: per subdivision, plays the next note of the current left-hand
  chord on `\bp_arp`.
- **Lead trigger**: the pose-read routine watches `rspeed`; on threshold cross
  (outside the refractory window) it fires `Synth(\bp_lead, [\freq, ...])`.
- **Pad voice**: one gated `\bp_pad` Synth per active mode; on mode change the old
  pad gates off while the new one fades in (the cross-fade), and tempo/scale swap.
- **Idle**: when no body is detected (n=0 / empty `~handFeat`), keep only a quiet
  pad of the last mode; suspend lead/arp/rhythm rather than cutting to silence.

## Technical considerations

- **Tempo smoothing**: `speed → tempo` is reactive but the detector is noisy, so
  it is smoothed (~2 s lag) and bounded per mode. Lag is a tunable in `~bpModes`.
- **Quantization**: lead/arp notes are always snapped to the active scale → never
  out of key.
- **Label stability**: guard mode switches against action-head jitter (see mapping).
- **Reuse**: build on existing helpers (engine FX rack, `~doScene` registrar,
  `s.bind`); FX from `scene_pose_action.scd` still apply to these voices.
- **Port/boot**: `boot.scd` loads `synthdefs_play.scd` after `synthdefs.scd`, and
  `scene_pose_play.scd` after `scene_pose_action.scd`. The scene is registered as
  `~doScene.(\play)` and started **explicitly** — it is NOT added to the `\all`
  aggregate by default, to keep the body-instrument separate from the data-feeds
  scenes (the performer turns it on with `~doScene.(\play)`).

## Validation

- `validating-scd-files`: P:0 B:0 and TLB:1 for both new `.load` files.
- SynthDef compile check (e2e_04-style) for all `\bp_*`.
- Headless isolation repro (as used for the 480aa79 bug): inject test
  `~handFeat`/`~poseKin`/`~poseState`, run `~bpMap` + one engine tick under
  `try`, assert no error and that notes/tempo are produced.
- Live: move in front of the camera and hear lead/arp/rhythm respond; switch
  posture to hear the mode cross-fade.

## Out of scope (future)

- Per-finger control (HaMeR) — only the global hand features are used.
- Multi-person polyphony — one body plays; pid selection is single-body for now.
- Recording/looping/quantized capture.
- New per-mode SynthDef *variants* beyond parameterisation.
