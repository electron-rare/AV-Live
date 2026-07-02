# Hand display cleanup + side panels — design

**Date:** 2026-07-02
**Status:** approved
**Scope:** `data_only_viz/iphone_usb_source.py`, `data_only_viz/state.py`, `data_only_viz/renderer.py`, new `data_only_viz/hand_display.py`, tests

## Problem

During the live pinch validation the hand overlay was unusable:
ghost hands (false Vision detections drawn at full confidence), erratic
spike segments from noisy landmarks, and filled mesh triangles cluttering
the hands. Root cause found: the iPhone TAG_HANDS wire carries a real
per-landmark Vision confidence (in the z slot) and a per-hand chirality
byte, but `_decode_hands` discards both — every landmark is stored with
`c=1.0` and chirality is skipped, so nothing downstream can filter.

Goal: keep the skeleton overlay on the video, remove the artifacts, and
add two side panels showing the left hand (left edge) and right hand
(right edge) front-view — a live close-up of exactly what the pinch
detector sees.

## Design

### A. Decode: expose confidence + chirality (`iphone_usb_source.py`, `state.py`)

- `_decode_hands` stores the wire z value (Vision confidence) into
  `PoseKp.c`, clamped to [0, 1]. `.z` keeps the raw wire value
  (back-compat: finger-strike OSC reads z).
- The chirality byte is no longer skipped: `_decode_hands` returns
  `(hands, chirality)` where `chirality[i]` is 0=left, 1=right.
- New state field `persons_hands_chirality: list[int]`, written under
  the same lock wherever TAG_HANDS updates `persons_hands_iphone` /
  `persons_hands`.

### B. Overlay cleanup (`renderer.py` + new `hand_display.py`)

Pure geometry helpers in `hand_display.py` (unit-testable, no Metal):

- `hand_size(kp) -> float` — wrist(0) to middle-MCP(9) distance.
- `hand_plausible(kp, conf_min=0.3, size_min=0.02, size_max=0.5) -> bool`
  — False when size out of range (ghost blobs) or mean landmark
  confidence < conf_min (Vision ghosts). MediaPipe hands keep c=1.0 so
  the confidence part is neutral for them.
- `segment_ok(A, B, size, conf_min=0.3, max_bone_ratio=1.2) -> bool`
  — False when either endpoint confidence < conf_min or the bone is
  longer than max_bone_ratio × hand size (erratic spikes).

Renderer changes:
- `_update_skeleton` hands loop: skip implausible hands entirely; skip
  bad segments; push with real `min(A.c, B.c)` instead of hardcoded 1.0.
- `_update_mesh`: remove the HAND_TRIANGLES block — hands are wireframe
  only. Body and face mesh unchanged.

### C. Side panels front view (`hand_display.py` + `renderer.py`)

- Two square insets, side 30% of view height, vertically centered,
  anchored to the left and right edges (2% margin), with a thin border
  frame.
- Left panel = left hand, right panel = right hand, selected by Vision
  chirality (`persons_hands_chirality`); fallback when chirality is
  missing (MediaPipe path): order by screen cx (mirror-aware).
- Panel content: the hand's 21 landmarks normalized to their bbox
  (aspect preserved, 10% inner margin), drawn as the HAND_CONNECTIONS
  wireframe. X is flipped to match the mirrored video so on-screen
  motion direction is consistent.
- Same plausibility gate as the overlay; a panel goes empty the moment
  its hand is absent or implausible (no freeze).
- Helper `panel_segments(kp, side, bones, mirror) -> list[(ax,ay,bx,by)]`
  returns normalized [0,1] screen-space segments; `panel_frame(side)`
  returns the 4 border segments. The renderer pushes them through a
  screen-space push that does NOT re-apply the video mirror.
- Stable colors: reuse the pid palette with fixed pids (left panel pid 5,
  right panel pid 6), frame at conf 1.0.

## Out of scope

- Fixing the "stale hands" freeze when the iPhone app stops sending
  TAG_HANDS frames (not observed as a problem; app sends count=0).
- Pinch-state visualization inside the panels (engaged finger highlight)
  — possible follow-up.
- MediaPipe hand mesh/topology changes beyond removing HAND_TRIANGLES.

## Testing

- Decode: TAG_HANDS payload with known conf/chirality round-trips into
  `.c` and the chirality list; count=0 yields `([], [])`.
- Helpers: ghost (tiny/huge/low-conf) hands rejected; spike segment
  rejected; plausible hand accepted.
- Panels: bbox normalization preserves aspect; left/right anchoring;
  mirror flip; empty output for implausible hand.
- Renderer paths are exercised live (visual validation on macm1).
