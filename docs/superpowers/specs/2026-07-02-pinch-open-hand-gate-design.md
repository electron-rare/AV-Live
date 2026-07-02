# Pinch open-hand gate + debounce — design

**Date:** 2026-07-02
**Status:** approved (option A)
**Scope:** `data_only_viz/finger_strike.py`, `data_only_viz/action_head_pub.py`, tests, launcher docs

## Problem

Finger pinch drives the matrix global actions (8 hold-to-fire slots) and
per-voice pinch bindings, but it was disabled by default (`1491aef`,
`PINCH_ENABLE=0`) because it fired accidentally during full-body play.

Root cause: `PinchDetector` only tests "thumb tip near a fingertip". A
relaxed hand or a fist during play naturally has the thumb close to the
index/middle tip, so the ratio drops below `ratio_on` (0.45) and a false
engage fires. The closest-wins margin (`16cd6a3`) rejects ambiguity
*between* fingers but not the fist itself. At full-body distance the
hand is small in frame, so Vision landmark jitter adds spurious
threshold crossings.

Goal: pinch usable at any distance during the set, without false
positives from relaxed hands/fists.

## Design

Two new gates inside `PinchDetector.step()`, keeping the existing
ratio_on/ratio_off/margin logic unchanged.

### 1. Open-hand extension gate

A deliberate pinch is performed with an open hand: thumb + target
finger touch, the other fingers stay extended. A fist or relaxed hand
has everything curled.

- Per finger, compute an extension ratio: `dist(tip, wrist) / size`
  where `size` is the existing wrist→middle-MCP hand size.
- A finger counts as *extended* when its extension ratio exceeds
  `ext_ratio` (default **1.35**; extended fingers measure ~1.6–1.9,
  curled ~0.8–1.1).
- The winner finger may engage only if at least `ext_min` (default
  **2**) of the 3 non-pinching fingers (thumb and winner excluded) are
  extended.

This kills the fist/relaxed-hand false positive — the dominant failure
mode — without touching detection sensitivity for the pinch itself.

### 2. Engage debounce

- The winner must satisfy all conditions (ratio_on, margin, extension
  gate, refractory) for `debounce_frames` consecutive `step()` calls
  (default **3**, ~100 ms at 30 Hz) before the engage event is emitted.
- A counter per (slot, finger) increments on qualifying frames and
  resets to zero on any non-qualifying frame or when another finger is
  the winner.
- **Release stays immediate** (unchanged): the SC hold-to-fire progress
  (`/matrix/pinchprogress`) depends on prompt release edges. The
  debounce delays engage by ~100 ms, which only shifts the hold window,
  it does not break it.

### Parameters / env vars

Read in `action_head_pub.py` next to the existing pinch env vars:

| Env | Default | Meaning |
|-----|---------|---------|
| `PINCH_EXT_RATIO` | `1.35` | tip↔wrist / hand-size above which a finger is extended |
| `PINCH_EXT_MIN` | `2` | min extended non-pinching fingers required to engage |
| `PINCH_DEBOUNCE_FRAMES` | `3` | consecutive qualifying frames before engage |

`PINCH_EXT_MIN=0` disables the extension gate; `PINCH_DEBOUNCE_FRAMES=1`
disables the debounce — both gates are individually defeatable for
live tuning without code changes.

Constructor: `PinchDetector(__init__)` gains `ext_ratio`, `ext_min`,
`debounce_frames` keyword args with the defaults above, so existing
tests and call sites stay valid.

## Out of scope

- Wrist-velocity stability gate (option C) — add later only if false
  positives survive in live testing.
- Threshold changes to `ratio_on`/`ratio_off`/`margin`.
- FINGER_PIANO strike detector — untouched.

## Rollout

1. Implement + unit tests green.
2. Live validation on macm1 with `PINCH_ENABLE=1` (manual gate, user
   confirms no false engages during full-body play and deliberate
   pinches still fire).
3. Only after live validation: flip `PINCH_ENABLE` default back to `1`
   in `launcher/concert/launch_concert.sh` (separate commit) and
   document the new env vars in the root `CLAUDE.md` env table.

## Testing

Extend `data_only_viz/tests/test_finger_strike.py`:

- **Fist rejection**: all fingertips near wrist and thumb near index →
  no engage ever, even after many frames.
- **Open-hand pinch**: thumb touches index, middle/ring/pinky extended
  → engage fires exactly once after `debounce_frames` frames.
- **Jitter rejection**: qualifying pose for 2 frames, then open → no
  engage (below debounce).
- **Immediate release**: after engage, opening the pinch emits release
  on the very next frame.
- **Gate defeat**: `ext_min=0, debounce_frames=1` reproduces current
  behavior (regression guard for existing tests).
