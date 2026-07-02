"""Central configuration for data_only_viz — single source of truth for env vars.

All os.environ reads for data_only_viz belong here.
Consumers call ``VizConfig.from_env()`` inside their ``__init__`` or the
consuming method — never at module import time so that test monkeypatching
of os.environ is picked up correctly.

Env var reference table
-----------------------
Name                        Default   Type   Effect
MEDIAPIPE_DELEGATE          "gpu"     str    "gpu" (Metal) or "cpu"
VIDEO_ROTATE                "none"    str    none/ccw/cw/180 — rotate frame before MP+JPEG
POSE_GHOST_MIN_VISIBLE      10        int    min visible kps to accept a body detection
POSE_GHOST_MIN_CONF         0.5       float  min mean confidence to keep a detection
POSE_HAND_MIN_VISIBLE       15        int    visibility gate for hand kps
POSE_FACE_MIN_VISIBLE       50        int    visibility gate for face kps
POSE_NMS_IOU                0.7       float  IoU threshold for body NMS
POSE_FILTER                 None      str    filter stage list (+/-sep); None=defaults
POSE_FILTER_FACE            None      str    filter stages for face; None=defaults
POSE_FILTER_HAND            None      str    filter stages for hands; None=defaults
FINGER_PIANO                "0"       bool   enable air-piano finger-strike emission
FINGER_STRIKE_VEL           0.02      float  downward relative-velocity threshold
FINGER_STRIKE_REFRACTORY_MS 120       float  min ms between strikes per finger
FINGER_SOURCE               "auto"    str    "auto"/"iphone"/"mediapipe"
FINGER_DEBUG                "0"       bool   log each detected strike/pinch
PINCH_ENABLE                "0"       bool   enable pinch gesture detection
PINCH_RATIO_ON              0.45      float  thumb-to-finger dist/hand-size to engage
PINCH_RATIO_OFF             0.65      float  dist/size above which pinch re-arms
PINCH_REFRACTORY_MS         250       float  min ms between pinches per finger
PINCH_MARGIN                0.20      float  extra margin added to pinch zone
PINCH_EXT_RATIO             1.35      float  extended-pinch activation ratio
PINCH_EXT_MIN               2         int    min extended fingers for a pinch to fire; 0 disables open-hand gate
PINCH_DEBOUNCE_FRAMES       3         int    debounce frames for pinch state machine
HAND_CONF_MIN               0.45      float  min hand landmark confidence to render
HAND_PERSIST_FRAMES         3         int    consecutive frames before a hand track is drawn; 1=off
HAND_SWAP_LR                "0"       bool   Safety knob: invert Vision chirality (validated correct live 2026-07-02; keep 0 unless a future iPhone app build flips it)
HAND_NEAR_MIN               0.10      float  min hand size (norm) to consider "near"
HAND_FACE_MIN               0.5       float  palm-spread ratio threshold: slot activates gestures only when facing >= this (side-on < 0.4, facing ~0.7-1.0)
HAND_PERSIST_GRACE          2         int    grace frames before dropping a hand track on Vision miss (0 = strict)
HAND_NEAR_OFF               0.08      float  hand size below which near gate deactivates (hysteresis off-threshold)
HAND_HOLD_FRAMES            2         int    gesture slot hold: frames to carry last hand on Vision miss
ARKIT_BONE_MAX              0.5       float  max bone length (norm) for ARKit skeleton
ARKIT_FULL_SKELETON         "1"       bool   draw full 91-joint ARKit body (!=0 = True)
VIZ_HUD                     "0"       bool   show debug HUD overlay
VIZ_SOURCE_KEYS             "0"       bool   wxcvbn + 0-9 source-bundle shortcuts (off: perf safety)
VIZ_AUDIO_KEYS              "0"       bool   qsdfghjkl audio-scene shortcuts (off: perf safety; m stays)
IPHONE_OSC_PORT             57128     int    UDP port for iPhone ARBodyTracker /body3d/kp
CONCERT_MIRROR              "1"       bool   mirror video horizontally (!=0 = True)
ICP_FUSION                  "0"       bool   enable ICP LiDAR fusion (only "1" = True)
ICP_LIDAR_HOST              None      str    iPhone LiDAR stream host when ICP_FUSION=1
ICP_LIDAR_PORT              5500      int    iPhone LiDAR stream port
ICP_LIDAR_EXTRINSIC         None      str    path to extrinsic JSON for ICP
MULTIHMR_BACKEND            "pytorch" str    "pytorch"/"coreml"/"remote"
MULTIHMR_LOOP_FPS           30.0      float  Multi-HMR worker loop target fps
MULTIHMR_AUTOCAST           "0"       bool   MPS fp16 autocast for Multi-HMR (only "1")
MULTIHMR_REMOTE_HOST        "192.168.0.175" str  remote Multi-HMR server host
MULTIHMR_REMOTE_PORT        57140     int    remote Multi-HMR server port
MULTIHMR_REMOTE_JPEG        True      bool   send JPEG-compressed frames to remote
MULTIHMR_REMOTE_JPEG_QUALITY 80       int    JPEG quality for remote frames
MULTIHMR_REMOTE_ASYNC       True      bool   async pipeline for remote backend
MULTIHMR_REID               "dino"    str    reid mode: "dino" or "iou"
MULTIHMR_REID_ALPHA         0.5       float  DINOv2 weight in hybrid reid score
COREML_MLPACKAGE            None      str    path to .mlpackage (None=default cache path)
COREML_COMPUTE_UNITS        ""        str    "cpu_only"/"cpu_and_gpu"/"all"/"cpu_and_ne"
AVBODY_HOST                 "127.0.0.1" str  host for AVLiveBody skeleton UDP/TCP
VDMX_OSC_HOST               None      str    VDMX VJ OSC host (None=disabled)
VDMX_OSC_PORT               1234      int    VDMX VJ OSC port
AV_LIVE_MEDIAPIPE           True      bool   enable MediaPipe Multi worker (!=0 = True)
AV_LIVE_APPLE_VISION        True      bool   enable Apple Vision fallback (!=0 = True)
AV_LIVE_COREML              True      bool   enable CoreML pose fallback (!=0 = True)
AV_LIVE_DETRPOSE            False     bool   enable DETRPose fallback (only "1" = True)
AV_LIVE_PARALLEL_POSE       "both"    str    parallel pose backend in multi-hmr mode
MESH_RIG                    "1"       bool   enable SMPL-X mesh rigger (!=0 = True)
"""
from __future__ import annotations

import dataclasses
import os
from typing import Mapping


@dataclasses.dataclass(frozen=True)
class VizConfig:
    """Frozen snapshot of all data_only_viz environment configuration.

    Construct with ``VizConfig.from_env()`` inside ``__init__`` or the
    consuming method — never at module import time.
    """

    # ---- MediaPipe / video -----------------------------------------------
    mediapipe_delegate: str = "gpu"
    video_rotate: str = "none"

    # ---- Pose discrimination thresholds ----------------------------------
    pose_ghost_min_visible: int = 10
    pose_ghost_min_conf: float = 0.5
    pose_hand_min_visible: int = 15
    pose_face_min_visible: int = 50
    pose_nms_iou: float = 0.7

    # ---- Pose filter chain -----------------------------------------------
    pose_filter: str | None = None
    pose_filter_face: str | None = None
    pose_filter_hand: str | None = None

    # ---- Finger piano / strike -------------------------------------------
    finger_piano: bool = False
    finger_strike_vel: float = 0.02
    finger_strike_refractory_ms: float = 120.0
    finger_source: str = "auto"
    finger_debug: bool = False

    # ---- Pinch detection -------------------------------------------------
    pinch_enable: bool = False
    pinch_ratio_on: float = 0.50
    pinch_ratio_off: float = 0.65
    pinch_refractory_ms: float = 250.0
    pinch_margin: float = 0.05
    pinch_ext_ratio: float = 1.35
    pinch_ext_min: int = 1
    pinch_debounce_frames: int = 3

    # ---- Hand display / gesture ------------------------------------------
    hand_conf_min: float = 0.45
    hand_persist_frames: int = 3
    hand_persist_grace: int = 2
    hand_swap_lr: bool = False
    hand_near_min: float = 0.10
    hand_near_off: float = 0.08
    hand_hold_frames: int = 2
    hand_face_min: float = 0.5
    arkit_bone_max: float = 0.5
    arkit_full_skeleton: bool = True

    # ---- HUD -------------------------------------------------------------
    viz_hud: bool = False
    # Source-bundle keyboard shortcuts (wxcvbn): OFF by default — a stray
    # keypress during a matrix performance switches the audio scene
    # (user-disabled live 2026-07-02). VIZ_SOURCE_KEYS=1 re-enables.
    viz_source_keys: bool = False
    # Audio-scene row (qsdfghjkl): same perf-safety gate, same date. The
    # special m key (matrix mode: scene stop + openpos viz) stays active.
    viz_audio_keys: bool = False

    # ---- iPhone OSC ------------------------------------------------------
    iphone_osc_port: int = 57128

    # ---- Concert / ARKit -------------------------------------------------
    concert_mirror: bool = True

    # ---- ICP LiDAR fusion ------------------------------------------------
    icp_fusion: bool = False
    icp_lidar_host: str | None = None
    icp_lidar_port: int = 5500
    icp_lidar_extrinsic: str | None = None

    # ---- Multi-HMR -------------------------------------------------------
    multihmr_backend: str = "pytorch"
    multihmr_loop_fps: float = 30.0
    multihmr_autocast: bool = False
    multihmr_remote_host: str = "192.168.0.175"
    multihmr_remote_port: int = 57140
    multihmr_remote_jpeg: bool = True
    multihmr_remote_jpeg_quality: int = 80
    multihmr_remote_async: bool = True
    multihmr_reid: str = "dino"
    multihmr_reid_alpha: float = 0.5

    # ---- CoreML ----------------------------------------------------------
    coreml_mlpackage: str | None = None
    coreml_compute_units: str = ""

    # ---- OSC destinations ------------------------------------------------
    avbody_host: str = "127.0.0.1"
    vdmx_osc_host: str | None = None
    vdmx_osc_port: int = 1234

    # ---- main.py worker selection ----------------------------------------
    av_live_mediapipe: bool = True
    av_live_apple_vision: bool = True
    av_live_coreml: bool = True
    av_live_detrpose: bool = False
    av_live_parallel_pose: str = "both"
    mesh_rig: bool = True

    # ------------------------------------------------------------------
    # Factory
    # ------------------------------------------------------------------

    @classmethod
    def from_env(cls, environ: Mapping[str, str] | None = None) -> "VizConfig":
        """Build a VizConfig by reading the given mapping (default: os.environ).

        Numeric conversion errors fall back to the field default silently.
        Bool conventions vary by field to match existing code exactly:
        - _bool_std:  not in ("0","","false","False") → True  (standard)
        - _bool_ne0:  != "0" → True  (empty string is True; None uses default)
        - _bool_eq1:  == "1" only (all other values → False)
        - _bool_flag: in ("1","true","yes","on") → True  (multihmr_remote style)
        """
        env: Mapping[str, str] = environ if environ is not None else os.environ

        _FALSE_STD = frozenset(("0", "", "false", "False"))

        def _bool_std(name: str, default: bool) -> bool:
            v = env.get(name)
            if v is None:
                return default
            return v not in _FALSE_STD

        def _bool_ne0(name: str, default: bool) -> bool:
            """Matches `env.get(name, "1") != "0"` style."""
            v = env.get(name)
            if v is None:
                return default
            return v != "0"

        def _bool_eq1(name: str) -> bool:
            """Matches `env.get(name, "0") == "1"` style — only "1" is True."""
            return env.get(name, "") == "1"

        def _bool_flag(name: str, default: bool) -> bool:
            """Matches multihmr_remote _env_flag: in ("1","true","yes","on")."""
            v = env.get(name)
            if v is None:
                return default
            return v.strip().lower() in ("1", "true", "yes", "on")

        def _int(name: str, default: int) -> int:
            v = env.get(name)
            if v is None:
                return default
            try:
                return int(v)
            except (ValueError, TypeError):
                return default

        def _float(name: str, default: float) -> float:
            v = env.get(name)
            if v is None:
                return default
            try:
                return float(v)
            except (ValueError, TypeError):
                return default

        def _str(name: str, default: str | None = None) -> str | None:
            v = env.get(name)
            return v if v is not None else default

        def _str_lower(name: str, default: str) -> str:
            v = env.get(name)
            return v.lower() if v is not None else default

        return cls(
            mediapipe_delegate=_str_lower("MEDIAPIPE_DELEGATE", "gpu"),
            video_rotate=_str_lower("VIDEO_ROTATE", "none"),
            pose_ghost_min_visible=_int("POSE_GHOST_MIN_VISIBLE", 10),
            pose_ghost_min_conf=_float("POSE_GHOST_MIN_CONF", 0.5),
            pose_hand_min_visible=_int("POSE_HAND_MIN_VISIBLE", 15),
            pose_face_min_visible=_int("POSE_FACE_MIN_VISIBLE", 50),
            pose_nms_iou=_float("POSE_NMS_IOU", 0.7),
            pose_filter=_str("POSE_FILTER"),
            pose_filter_face=_str("POSE_FILTER_FACE"),
            pose_filter_hand=_str("POSE_FILTER_HAND"),
            finger_piano=_bool_std("FINGER_PIANO", False),
            finger_strike_vel=_float("FINGER_STRIKE_VEL", 0.02),
            finger_strike_refractory_ms=_float("FINGER_STRIKE_REFRACTORY_MS", 120.0),
            finger_source=_str_lower("FINGER_SOURCE", "auto"),
            finger_debug=_bool_std("FINGER_DEBUG", False),
            pinch_enable=_bool_std("PINCH_ENABLE", False),
            pinch_ratio_on=_float("PINCH_RATIO_ON", 0.50),
            pinch_ratio_off=_float("PINCH_RATIO_OFF", 0.65),
            pinch_refractory_ms=_float("PINCH_REFRACTORY_MS", 250.0),
            pinch_margin=_float("PINCH_MARGIN", 0.05),
            pinch_ext_ratio=_float("PINCH_EXT_RATIO", 1.35),
            pinch_ext_min=_int("PINCH_EXT_MIN", 1),
            pinch_debounce_frames=_int("PINCH_DEBOUNCE_FRAMES", 3),
            hand_conf_min=_float("HAND_CONF_MIN", 0.45),
            hand_persist_frames=_int("HAND_PERSIST_FRAMES", 3),
            hand_persist_grace=_int("HAND_PERSIST_GRACE", 2),
            hand_swap_lr=_bool_std("HAND_SWAP_LR", False),
            hand_near_min=_float("HAND_NEAR_MIN", 0.10),
            hand_near_off=_float("HAND_NEAR_OFF", 0.08),
            hand_hold_frames=_int("HAND_HOLD_FRAMES", 2),
            hand_face_min=_float("HAND_FACE_MIN", 0.5),
            arkit_bone_max=_float("ARKIT_BONE_MAX", 0.5),
            # ARKIT_FULL_SKELETON uses != "0" convention (empty = True)
            arkit_full_skeleton=_bool_ne0("ARKIT_FULL_SKELETON", True),
            viz_hud=_bool_std("VIZ_HUD", False),
            viz_source_keys=_bool_std("VIZ_SOURCE_KEYS", False),
            viz_audio_keys=_bool_std("VIZ_AUDIO_KEYS", False),
            iphone_osc_port=_int("IPHONE_OSC_PORT", 57128),
            concert_mirror=_bool_ne0("CONCERT_MIRROR", True),
            # ICP_FUSION / MULTIHMR_AUTOCAST use strict "1" convention
            icp_fusion=_bool_eq1("ICP_FUSION"),
            icp_lidar_host=_str("ICP_LIDAR_HOST"),
            icp_lidar_port=_int("ICP_LIDAR_PORT", 5500),
            icp_lidar_extrinsic=_str("ICP_LIDAR_EXTRINSIC"),
            multihmr_backend=(_str("MULTIHMR_BACKEND", "pytorch") or "pytorch").strip().lower(),
            multihmr_loop_fps=_float("MULTIHMR_LOOP_FPS", 30.0),
            multihmr_autocast=_bool_eq1("MULTIHMR_AUTOCAST"),
            multihmr_remote_host=_str("MULTIHMR_REMOTE_HOST", "192.168.0.175") or "192.168.0.175",
            multihmr_remote_port=_int("MULTIHMR_REMOTE_PORT", 57140),
            # MULTIHMR_REMOTE_JPEG/ASYNC use _env_flag convention
            multihmr_remote_jpeg=_bool_flag("MULTIHMR_REMOTE_JPEG", True),
            multihmr_remote_jpeg_quality=_int("MULTIHMR_REMOTE_JPEG_QUALITY", 80),
            multihmr_remote_async=_bool_flag("MULTIHMR_REMOTE_ASYNC", True),
            multihmr_reid=_str_lower("MULTIHMR_REID", "dino"),
            multihmr_reid_alpha=_float("MULTIHMR_REID_ALPHA", 0.5),
            coreml_mlpackage=_str("COREML_MLPACKAGE"),
            coreml_compute_units=(_str("COREML_COMPUTE_UNITS", "") or "").strip().lower(),
            avbody_host=_str("AVBODY_HOST", "127.0.0.1") or "127.0.0.1",
            vdmx_osc_host=_str("VDMX_OSC_HOST"),
            vdmx_osc_port=_int("VDMX_OSC_PORT", 1234),
            # AV_LIVE_* use != "0" convention (enabled by default when unset)
            av_live_mediapipe=_bool_ne0("AV_LIVE_MEDIAPIPE", True),
            av_live_apple_vision=_bool_ne0("AV_LIVE_APPLE_VISION", True),
            av_live_coreml=_bool_ne0("AV_LIVE_COREML", True),
            av_live_detrpose=_bool_eq1("AV_LIVE_DETRPOSE"),
            av_live_parallel_pose=_str("AV_LIVE_PARALLEL_POSE", "both") or "both",
            mesh_rig=_bool_ne0("MESH_RIG", True),
        )
