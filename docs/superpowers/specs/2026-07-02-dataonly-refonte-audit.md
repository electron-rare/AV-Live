# data_only_viz refactor audit — reference for chantiers 1-6

**Date:** 2026-07-02 (architect analysis, validated file:line)
**Status:** approved by user ("enchaine 1 a 6"), execution order 1 -> 2 -> 5 -> 3 -> 4 -> 6

## Live bugs found

- **B1 ARKit skeleton freeze**: `renderer.py:323-325` enables `use_arkit` on
  `bool(s.persons_arkit_2d)` with no freshness test and bypasses
  `pose_alive()`. `persons_arkit_2d_t` is written (`iphone_usb_source.py`)
  but never read. USB/app drop during a show = skeleton frozen on screen.
- **B2 unreachable keyboard**: NSEvent monitors (ESC, space=concertNext,
  keymaps) are installed at `main.py:448-460` AFTER the YOLO fallback in
  `_start_pose_worker` — all normal paths `return` before (l.369, 384,
  399, 413, 440), and without `--pose` the function is never called.
  Move the hooks into `applicationDidFinishLaunching_`.
- **B3 persons_smplx contract broken**: `action_head_pub._read_sources`
  reads dicts (`p.get("pid")`, `p.get("v3d")`, `action_head_pub.py:277-278`)
  but `multi_hmr_worker.py:790-802` writes `SMPLXPerson` dataclasses
  (field `vertices_3d`, no `.get`). Under `--multi-hmr`: AttributeError
  every tick, swallowed by `LOG.exception` at 30 Hz. Tests mask it
  (`tests/test_action_head_pub.py:32` builds dicts). Latent in concert
  mode (iphone-usb).
- **B4 tearing race**: `iphone_usb_source.py:163-169` mutates
  `persons_arkit_joints[pid]` IN PLACE under lock, but `multi.py:471-474`
  shallow-copies the dict then reads the array outside the lock, and
  `ArkitFuse.apply` (`pose_filter.py:685-699`) reads `arr[i,:]` outside
  the lock -> joints mixing two frames. Fix: write a NEW array each frame
  (same pattern as the 2D path, `iphone_usb_source.py:174-179`).
- **Hot-lock staging**: `renderer._update_uniforms` calls
  `_update_skeleton` + `_update_mesh` INSIDE `with s.lock():`
  (`renderer.py:260-301`). At 60 fps, per-segment Python loops (up to
  ~2700 face tessellation segs/person) block MultiWorker, IphoneUSBSource
  and ActionHeadPublisher on the same RLock. Dominant jitter source.
  Pattern fix: snapshot refs under lock, build buffers outside.
- Hot-loop logs: `renderer.py:309-314` (INFO every 120 frames, reads
  persons_* OUTSIDE the lock), `multi.py:521-522`.
- **4x hand-ordering duplication**: `finger_strike.order_hands_by_cx`
  (l.27-41) == `FingerStrikeDetector._slot_hands` (l.73-87, verbatim
  copy); `hand_features.py:94` (cx sort); `renderer.py` panels
  (mirror-aware). Renderer routes by chirality; gesture detectors do NOT
  (L/R swap when hands cross).
- Per-frame allocations: new PoseKp per keypoint per smoothing stage
  (`multi.py:71-79`, `pose_filter.py:833,893`); `frame.copy()` per read
  (`iphone_usb_source.py:238`, ~0.9 MB/tick); `pts_xy` 478-tuple list per
  face per frame.
- **pose_bridge sends 1 UDP datagram per keypoint**: 68 face + 42 hands
  + 33 body3d > 4000 sendto/s at 30 Hz (`pose_bridge.py:249-260,
  282-291, 318-326`). OSC bundles would divide syscalls by ~50.
- **iphone-usb still loads MediaPipe**: `multi.py:323-368` loads the 3
  landmarkers (+ network `_ensure_model` l.82-90) even though inference
  is skipped (`multi.py:416-418`) in the default concert mode.
- **Env sprawl**: 56 `os.environ` reads across 12 files (main.py 13,
  action_head_pub 13, multi 7...). Proposal: single frozen-dataclass
  `config.py` read at boot, injected.
- Dead/near-dead code: YOLO/COCO fallback (`renderer.py:64-70, 452-456`;
  `state.pose_kp`; `pose.py`), `holistic.py`, `detrpose.py`,
  `coreml_pose.py`, `nlf_worker.py`, 3 scaffold .md. Backend cascade in
  `main.py:374-446` only serves 2 real paths (MediaPipe Multi,
  iphone-usb). KEEP the Mac-webcam MediaPipe fallback (only plan B if
  the iPhone dies in a show).
- Missing tests: action_head_pub <-> real SMPLXPerson contract; ARKit
  freshness in renderer; multi.py tick integration in iphone-usb mode.

## Chantiers (execution order 1 -> 2 -> 5 -> 3 -> 4 -> 6)

1. **Correctifs live** (S): (a) ARKit 2D freshness gate in renderer via
   `persons_arkit_2d_t` (<1 s); (b) adapt `action_head_pub.py:276-309`
   to SMPLXPerson + test with the real dataclass; (c) move keyboard
   hooks into `applicationDidFinishLaunching_`.
2. **No in-place mutations** (S): `iphone_usb_source.py:163-169` writes
   a fresh array (copy the 2D pattern); kills the tearing race.
3. **HandRouter** (M): module `hand_slots.py` (iPhone chirality first,
   cx fallback) consumed by finger_strike, hand_features, renderer
   panels; removes 4 duplications and L/R swap. Re-test gestures live.
4. **Renderer snapshot-out-of-lock** (M): `_update_uniforms` copies refs
   under lock, builds segs/tris outside; move the l.309-314 log behind
   `isEnabledFor(DEBUG)` and inside the lock or on snapshotted data.
5. **Central config.py** (M) + gate MediaPipe loading under iphone-usb
   (`multi.py:341-368` conditional on `not iphone_usb`).
6. **Degraissage** (L, 4 independent parts): (a) extract backend factory
   from main.py; (b) move ActionHeadPublisher out of
   MultiWorker.__init__; (c) delete YOLO/COCO/holistic/detrpose dead
   paths (KEEP webcam MediaPipe); (d) OSC bundles in pose_bridge.

## Non-negotiable invariants (all chantiers)

- Concert mode (`--pose --iphone-usb`) must keep working end-to-end:
  video + ARKit skeleton overlay + hand panels + /pose/* OSC to SC.
- Gesture semantics (pinch gates, strikes) unchanged unless the chantier
  says otherwise (chantier 3 changes SLOTTING only, not detection).
- Keep Mac-webcam MediaPipe fallback path alive.
- All existing test suites stay green:
  `uv run pytest tests/ -v` from data_only_viz/.
- Commit style: subject <= 50 chars, no AI attribution, no underscore in
  scope, one commit per coherent step.
