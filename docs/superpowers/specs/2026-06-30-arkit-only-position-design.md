# ARKit-only body position (cut Mac MediaPipe pose/face)

**Date**: 2026-06-30
**Status**: design approved (decisions made), pending spec review
**Scope**: `shared/AVLiveWire` (tag), `iphone-arbody` (send 2D skeleton + rebuild),
`data_only_viz/{iphone_usb_source.py, scripts/iphone_usb_bridge.py, multi.py, arkit_joint_map.py}`,
`launcher/concert/launch_concert.sh` (POSE_FILTER). Hands already cut (iPhone Vision).

## Context

Under `--iphone-usb` the matrix's body modulation (`/pose/center`, `/pose/kin`,
`/pose/sho_span`, `/pose/limb_span`, `/pose/head`) is computed from the **Mac
MediaPipe pose** (2D image landmarks), with ARKit only *fused* into the 3D
world body (`arkit_fuse`, 14 joints). The 2D body position the matrix uses is
therefore MediaPipe (CPU, jittery) — the user wants it 100% ARKit.

**The wall:** the iPhone sends the ARKit skeleton in **3D world** coords
(`root * jointModelTransforms`, tag `.skeleton`). The matrix `/pose/center`
needs **2D image-normalized** coords. The iPhone app already computes a 2D
projection (`ARCamera.projectPoint` → `skeleton2D`) for its on-device overlay
but does NOT send it. So ARKit-only 2D position requires the iPhone to send the
2D-projected skeleton.

## Decisions (from brainstorming)

- **Full ARKit body**: under `--iphone-usb`, build the body (2D + 3D) from the
  ARKit skeleton; **cut Mac MediaPipe pose AND face** (hands already cut). Lose
  `/pose/mouth` + the face mesh (accepted — max CPU, position 100% ARKit).
- The iPhone sends the **2D-projected skeleton** (viewport-normalized) over USB,
  in addition to the existing 3D world skeleton.
- `arkit_fuse` is dropped from `POSE_FILTER` (ARKit becomes the source, not a fuse).

## Design

### Wire format (`shared/AVLiveWire`)
- Add a `skeleton2D` tag (e.g. value 5). Payload: 91 × (x, y) Float32
  (viewport-normalized 0..1) + 91 × valid (UInt8). Mirrors `SkeletonPayload`
  but 2 floats/joint instead of 3.

### iPhone app (`iphone-arbody`)
- In `publishUSB` (or alongside `updateSkeleton2D`), build a `Skeleton2DPayload`
  from the already-computed `skeleton2D` points (`projectPoint` viewport coords)
  divided by `viewportSize` → normalized 0..1, with the tracked flags; send via
  `usb.send(tag: .skeleton2D, ...)`. Keep the existing 3D `.skeleton` send (the
  matrix's `/pose/kin` 3D body still uses it).
- **Rebuild + redeploy** on the iPhone (`xcodegen generate` → Xcode → ⌘R). USER
  STEP — cannot be done remotely.

### Mac decode (`data_only_viz`)
- `iphone_usb_source` + `scripts/iphone_usb_bridge.decode_skeleton2D`: decode
  `TAG_SKELETON2D` → `state.persons_arkit_2d[pid]` (91 × (x,y) normalized) +
  `persons_arkit_2d_t`.

### Mac pose loop (`multi.py`, under `--iphone-usb`)
- **Cut MediaPipe pose + face** inference (like hands): `pose_res`/`face_res`
  skipped; `faces=[]`.
- **Build the 2D body** (`bodies`, MP33 image-normalized) from `persons_arkit_2d`
  via the `ARKIT91_TO_MP33` map (extended with head/neck → MP33 slot 0). Missing
  MP33 slots (face/fingers) → low-confidence/clamped defaults.
- **Build `bodies3d`** (MP33 world) from `persons_arkit_joints` (3D world) via the
  same map (this replaces the `arkit_fuse` splice — ARKit is now the source).
- Emit `/pose/*` from the ARKit body. The id/tracking can use a single pid (the
  ARKit body) — the matrix is single-person.

### Mapping (`arkit_joint_map.py`)
- Extend `ARKIT91_TO_MP33` with head/neck → MP33 0 (nose) so `/pose/center` +
  `/pose/head` have a head anchor. (ARKit `head_joint` index — confirm against the
  Apple enum during implementation.)

### Launcher
- Drop `arkit_fuse` from `POSE_FILTER` (no longer fusing): set
  `POSE_FILTER=median+kalman+lookahead+ik` for the body (ARKit is already smooth;
  keep the temporal filters). Verify the matrix mod still feels right.

## Testing

- **AVLiveWire**: `swift test` (the wire round-trip for the new tag, in the
  shared package's loopback tests).
- **Mac decode + body-build**: unit-test `decode_skeleton2D` + the ARKit→MP33
  body builder in isolation (no torch / no mediapipe needed for those pure
  functions) — feed a synthetic 91-joint 2D array, assert the MP33 body + a
  sane `/pose/center` (mean of mapped joints).
- **Live (on the rig, after the iPhone rebuild)**: body position tracks from
  ARKit (stable, no MediaPipe jitter); `/pose/center`/`kin`/`sho_span` respond;
  CPU drops (no MediaPipe inference); the matrix's pose-driven modulation works;
  the face mesh + `/pose/mouth` are gone (accepted).

## Risks / dependencies

- **iPhone rebuild is a manual user step** (Swift, on-device) — each iteration of
  the Swift change needs a rebuild+redeploy. Get the wire format right first time.
- Untestable end-to-end locally (needs the device + ARKit). Mac-side pure
  functions are unit-tested; the integration is verified live.
- Coordinate orientation: `projectPoint` viewport coords depend on the interface
  orientation — normalize consistently (the app already handles orientation for
  its overlay; reuse that).

## Out of scope

- Face/mouth modulation (cut with MediaPipe face).
- Multi-person (ARKit body tracking is single-body; the matrix is single-person).
- Hand position (already iPhone Vision).

## Decided defaults

- Full ARKit body, cut MediaPipe pose+face, send 2D skeleton from the iPhone,
  drop `arkit_fuse`, head/neck added to the mapping.
