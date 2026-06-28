# Matrix audio-reactive cell glow — design

Date: 2026-06-28
Status: approved (brainstorming), pending implementation plan
Scope: `web_realart/` + `sound_algo/data_only/` (no audio-graph changes)

## Goal

As the matrix arranger playhead sweeps the 16x32 grid, the cell of each voice at
the current bar glows with an intensity proportional to that voice's most recent
note velocity, decaying over ~200 ms. Active voices visibly "fire" in sync with
the music, turning the arrangement grid into a live performance display.

Visual cap (confirmed): only the cell under the playhead, per voice, glows
("glow of the active cell"). Not the whole row, not a separate VU lane.

## Approach

**Approach A — trigger-envelope** (chosen). Each voice emits its per-note
amplitude over OSC; the web client models a fast-attack/exponential-decay
envelope per voice and applies it as a glow on the active cell. No audio-graph
surgery — safe for live, cheap, works immediately.

Rejected/deferred:
- **B — true per-voice RMS via monitor buses**: accurate for sustained voices
  but modifies the audio routing of all 16 voices. Deferred (see Future Work).
- **C — master-tap approximation**: does not deliver per-voice glow. Rejected.

Trade-off accepted: A is an envelope model keyed on note attacks. It is exact
for percussive voices (kick/hats/clap/perc/rim/tom) and visually convincing for
others, but does not capture the true sustained level of pad/sub/reese. Approach
B is the documented upgrade path if that accuracy is ever needed.

## Architecture & data flow

```
[voice lp_* plays a note]            sound_algo/data_only/launchpad.scd
        | ~matEmitTrig.(vi, amp)     shared helper; reads the \amp already
        |                            computed per Pbind event (x ~lpVol)
        v
OSC /matrix/trig <vi:i> <amp:f>      same OSC-out NetAddr that matrix.scd
        |                            already uses for /matrix/playhead -> :9000
        v
server.js                            "/matrix/" is already in FEEDBACK_PREFIXES
        |                            -> auto-relayed to WS clients. NO server change.
        v
WebSocket -> control.js
        | voiceLevel[vi] = max(voiceLevel[vi], amp)   // attack
        v
requestAnimationFrame loop:
        | voiceLevel[vi] *= GLOW_DECAY (~0.88/frame ≈ 200 ms tail)
        | apply --glow to cellRefs[matPlayhead][vi]
        v
CSS: box-shadow (variation hue) + filter:brightness() driven by --glow
     only the cell under the playhead; off-cells (color 0) never glow
```

## Components

### SC emission (`sound_algo/data_only/`)

- New helper `~matEmitTrig = { |vi, amp| ... }`: clamps `amp` to 0..1 and sends
  `/matrix/trig vi amp` via the **existing** OSC-out NetAddr used by `matrix.scd`
  for `/matrix/playhead` (so it lands on server.js:9000 and is relayed by the
  existing `/matrix/` prefix). Single responsibility: emit per-note amp.
- Wire `~matEmitTrig` into the 16 voice Pbinds. Preferred: hook the shared point
  where the `lp_*` Pdefs are defined (a loop/decorator if one exists in
  `launchpad.scd`) so it is one edit, not sixteen. The hook reads the event's
  effective `\amp` and calls `~matEmitTrig.(voiceIndex, amp)` as a side effect,
  passing the event through unchanged.
- Emission is unconditional (cheap); the web only renders it when the matrix tab
  is active. No gating in SC.
- **No changes to audio routing, SynthDefs, or `Out.ar` destinations.**

### Bridge (`web_realart/server.js`)

- No change. `/matrix/trig` matches the existing `/matrix/` feedback prefix and
  is broadcast to WebSocket clients automatically.

### Web rendering (`web_realart/public/control/`)

- New self-contained `MatrixGlow` module in `control.js`, isolated from the grid
  / cell-cycle / playhead logic:
  - `voiceLevel[16]` float state (transient, not persisted).
  - WS handler for `/matrix/trig <vi> <amp>`: `voiceLevel[vi] = max(level, amp)`.
  - `requestAnimationFrame` decay loop: `voiceLevel[vi] = nextGlow(level, dt)`;
    applies `--glow` CSS var to `cellRefs[matPlayhead][vi]`; clears glow on cells
    no longer under the playhead.
  - rAF self-suspends when all levels are ~0 and resumes on the next trig
    (no idle CPU, no leak).
  - Pure helper `nextGlow(level, dt)` (exponential decay) extracted for testing.
- `control.css`: a `.mcell` rule consuming `--glow` for `box-shadow` (hue from
  the active m1–m6 variation class) + slight `filter: brightness()`. GPU-cheap,
  no reflow.

## Error handling / robustness

- `amp` clamped 0..1 in SC; web also clamps defensively.
- Matrix stopped / no trigs: all `voiceLevel` decay to 0, rAF suspends, no glow.
- Playhead absent (`matPlayhead === -1`): no cell is targeted; glow no-ops.
- Unknown/out-of-range `vi`: ignored on the web side.

## Testing

- **SC** (`data_only/test/test_matrix.scd`, existing harness, must keep P:0 B:0):
  assert `~matEmitTrig` is defined; stub the OSC send function and assert a call
  routes `/matrix/trig` with integer `vi` in 0..15 and `amp` in 0..1.
- **Web**: no JS test runner exists in `web_realart` today. Extract `nextGlow`
  as a pure function so it is unit-testable if a micro-runner is added; otherwise
  verify decay behavior in-browser. DOM/rAF wiring is validated manually.
- **Manual**: boot data-only, run the matrix, observe cells pulsing on hits,
  intensity tracking velocity, and the tail fading cleanly on stop.

## Future work — Approach B (true per-voice RMS)

Not implemented. Allocate 16 monitor buses; route each `lp_*` voice to its own
bus (plus the master sum); a probe synth reads all 16 with `Amplitude.kr` and
fires `SendReply.kr(Impulse.kr(20))` -> OSC `/matrix/level vi amp`; the web maps
the level directly (no envelope model). This captures sustained levels
(pad/sub/reese/filter sweeps/FX) accurately. Deferred because it modifies the
audio graph of all 16 voices (`launchpad.scd`), which is unjustified risk while
the trigger-envelope model is visually sufficient. Anchors for the upgrade:
`data_only/engine.scd` (bus alloc after `s.sync`), `data_only/launchpad.scd`
(voice `Out.ar` routing), `data_only/touchosc_feedback.scd:115` (RMS probe
template).

## Out of scope

- Audio-graph / mixer refactoring.
- TouchOSC and Metal-scene glow surfaces (web grid only).
- Persisting glow state.
