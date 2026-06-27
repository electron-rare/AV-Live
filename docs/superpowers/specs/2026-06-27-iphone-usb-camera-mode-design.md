# iPhone-USB camera mode for data_only_viz

Date: 2026-06-27
Status: design approved (de-risked), pending spec review
Scope: `data_only_viz/`

## Goal

Drive the whole `data_only_viz` pose pipeline from the iPhone over USB, with
NO Mac webcam: the ARBodyTracker iOS app's HEVC video feeds MediaPipe, its
ARKit skeleton refines the body via `arkit_fuse`, and its Vision hands feed
the hand features. Everything comes from the iPhone. This drives body-play
(the SC instrument) end-to-end from the phone.

## De-risk (done — the hard unknowns are resolved)

- **HEVC decode works.** PyAV 17.1.0 (installed in the venv) decodes the
  iPhone's real access units: 256 frames in ~9 s (~28 fps), shape
  `(1440, 1920, 3)` RGB uint8. The iPhone emits length-prefixed NAL units
  (VPS/SPS/PPS prepended on keyframes); converting each 4-byte length prefix
  to an Annex-B start code (`00 00 00 01`) and feeding `av.Packet` to a
  `hevc` `CodecContext` decodes cleanly (keyframe=1 first, then inter).
- **usbmux tunnel + AVLiveWire demux work** (the committed `iphone_usb_bridge.py`
  already connects to device :7000 and demuxes skeleton frames).
- **The pose worker frame source is pluggable.** `multi.py` reads frames via
  `cap.read() -> (ok, frame_bgr)` (cv2-compatible; `_av_capture.py:14` documents
  the same contract). So a custom source implementing `.read()` substitutes
  cleanly for `cv2.VideoCapture` — no rewrite of the inference loop.

## Architecture

| Component | Responsibility |
|-----------|----------------|
| **`iphone_usb_source.py`** (new) | `IphoneUSBSource` — a cv2-VideoCapture-shaped frame source backed by a USB reader thread |
| **`multi.py`** (modify, ~3 lines) | use `IphoneUSBSource` instead of `cv2.VideoCapture` when in iphone-usb mode |
| **`main.py`** (modify) | `--iphone-usb` flag; pass it to the pose worker; skip the Mac-camera TCC path |
| **`arkit_fuse`** (exists) | refine 14 body slots from ARKit (activated via `POSE_FILTER`) |

### `IphoneUSBSource` (the one substantial new unit)

A class with a cv2-compatible surface so `multi.py` needs almost no change:

```
class IphoneUSBSource:
    def __init__(self, state, target_size=(640, 480)): ...
    def start(self) -> bool          # connect usbmux + start reader thread
    def isOpened(self) -> bool
    def read(self) -> tuple[bool, np.ndarray | None]   # (ok, frame_bgr), latest decoded frame
    def set(self, *a) -> bool        # no-op (cv2 compat for CAP_PROP_*)
    def release(self) -> None        # stop thread, close socket
```

Internals (reader thread):
1. **Connect** to the device's :7000 via usbmux (reuse `iphone_usb_bridge.connect_device`).
2. **Demux** AVLiveWire frames (reuse `iphone_usb_bridge.iter_frames`).
3. Per frame tag:
   - `tag=1 skeleton` → decode `SkeletonPayload` (91 interleaved BE xyz + 91 valid),
     write `state.persons_arkit_joints[pid]` (numpy (91,3)) + `persons_arkit_last_t`
     (the same store `iphone_osc_listener._on_kp` fills — so `arkit_fuse` reads it).
   - `tag=2 video` → convert NAL length-prefix → Annex-B, `codec.decode(av.Packet(...))`;
     keep the latest frame as BGR (`frame.to_ndarray(format='bgr24')`), downscaled to
     `target_size` for MediaPipe perf (1920×1440 is heavy at 28 fps on CPU).
   - `tag=4 hands` → decode `HandsPayload` (count u8; per hand chirality u8 + 21×xyz BE),
     write `state.persons_hands` as the 21-PoseKp-per-hand list the existing
     `HandFeatureExtractor` consumes (normalized xy).
4. `read()` returns the latest decoded video frame (BGR) under a lock; `(False, None)`
   until the first keyframe decodes.

The skeleton + hands are written **straight into `state`** (not over OSC) since
this source runs inside data_only_viz — the existing in-process OSC listener is
bypassed for this mode (no `iphone_usb_bridge.py` process needed in iphone-usb mode).

### `multi.py` change

Where it builds the capture (currently `cap = cv2.VideoCapture(self.camera_index)`):
- if iphone-usb mode: `cap = IphoneUSBSource(self.state); cap.start()`.
- the rest of the loop (`ok, frame_bgr = cap.read()`, MediaPipe, filter chain incl.
  `arkit_fuse`) is unchanged.

### `main.py` change

- Add `--iphone-usb` arg.
- When set: pass it through to the pose worker (so `multi.py` picks `IphoneUSBSource`),
  and do NOT request the Mac camera (`_request_camera_and_start_pose` should start the
  pose worker directly — `IphoneUSBSource` does its own usbmux connect, no TCC).

## Data flow

```
iPhone :7000 (USB)
  ├─ HEVC video  ─ PyAV decode ─→ frame_bgr ─→ MediaPipe (pose+face+hands)
  ├─ ARKit skel  ─────────────→ state.persons_arkit_joints ─→ arkit_fuse (14 body slots)
  └─ Vision hands ───────────→ state.persons_hands ─→ HandFeatureExtractor
            ↓
   persons_body3d (MediaPipe + ARKit) → action_head → /pose/kin, /pose/action
   handFeat → /pose/hands
            ↓
        SuperCollider body-play (~doScene.(\play))
```

## Activation

```
POSE_FILTER=median+kalman+lookahead+ik+arkit_fuse \
  python -m data_only_viz.main --pose --iphone-usb
```
(No Mac webcam, no separate bridge process. The ARBodyTracker app must be running
and the iPhone unlocked.)

## Wire formats (reference for the decoder)

- AVLiveWire frame header (19 B, big-endian): magic `AVL1`, tag u8 (skeleton=1,
  video=2, hands=4, face=5), pid i16, timestamp f64, length u32.
- `SkeletonPayload` (1183 B): 91 × (x,y,z) BE f32 interleaved, then 91 validity bytes.
- `VideoPayload`: 1 byte isKeyframe, then HEVC access unit (4-byte length-prefixed NALs;
  keyframe prepends VPS/SPS/PPS). Convert each length prefix to `00 00 00 01` for PyAV.
- `HandsPayload`: count u8; per hand → chirality u8 (1=right) + 21 × (x,y,z) BE f32
  (normalized image coords; z≈confidence).

## Testing

- HEVC decode: already de-risked (256 frames). A unit-style test can feed a captured
  keyframe+inter AU pair through the converter + decoder and assert a frame shape.
- `IphoneUSBSource.read()`: with the app running, assert it returns `(True, frame)` with
  the expected downscaled shape within a few seconds, and that `state.persons_arkit_joints`
  / `state.persons_hands` get populated.
- Live: run `--pose --iphone-usb`, stand in front of the iPhone, confirm body3d/hands
  drive `/pose/*` and body-play reacts (audible).

## Out of scope

- Vision face (tag=5) — body-play doesn't use it.
- Multi-person (single pid focus, as today).
- Keeping the Mac webcam as a fallback within the same run (the mode is iPhone-only).
- The standalone `iphone_usb_bridge.py` OSC bridge stays as-is for the webcam-fusion
  path; iphone-usb mode bypasses it (in-process state writes).
