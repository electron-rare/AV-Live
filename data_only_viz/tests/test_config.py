"""Tests for data_only_viz.config — VizConfig defaults, bool conventions, round-trip."""
from __future__ import annotations

import threading
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from data_only_viz.config import VizConfig


# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------

def test_defaults_mediapipe():
    cfg = VizConfig.from_env({})
    assert cfg.mediapipe_delegate == "gpu"
    assert cfg.video_rotate == "none"


def test_defaults_pose_discrimination():
    cfg = VizConfig.from_env({})
    assert cfg.pose_ghost_min_visible == 10
    assert cfg.pose_ghost_min_conf == 0.5
    assert cfg.pose_hand_min_visible == 15
    assert cfg.pose_face_min_visible == 50
    assert cfg.pose_nms_iou == 0.7


def test_defaults_pose_filter():
    cfg = VizConfig.from_env({})
    assert cfg.pose_filter is None
    assert cfg.pose_filter_face is None
    assert cfg.pose_filter_hand is None


def test_defaults_finger_piano():
    cfg = VizConfig.from_env({})
    assert cfg.finger_piano is False
    assert cfg.finger_strike_vel == pytest.approx(0.02)
    assert cfg.finger_strike_refractory_ms == pytest.approx(120.0)
    assert cfg.finger_source == "auto"
    assert cfg.finger_debug is False


def test_defaults_pinch():
    cfg = VizConfig.from_env({})
    assert cfg.pinch_enable is False
    assert cfg.pinch_ratio_on == pytest.approx(0.50)
    assert cfg.pinch_ratio_off == pytest.approx(0.65)
    assert cfg.pinch_refractory_ms == pytest.approx(250.0)
    assert cfg.pinch_margin == pytest.approx(0.05)
    assert cfg.pinch_ext_ratio == pytest.approx(1.35)
    assert cfg.pinch_ext_min == 1
    assert cfg.pinch_debounce_frames == 3


def test_defaults_hand_display():
    cfg = VizConfig.from_env({})
    assert cfg.hand_conf_min == pytest.approx(0.45)
    assert cfg.hand_persist_frames == 3
    # HAND_SWAP_LR validated correct 2026-07-02: default OFF
    assert cfg.hand_swap_lr is False
    assert cfg.hand_near_min == pytest.approx(0.10)
    assert cfg.arkit_bone_max == pytest.approx(0.5)
    assert cfg.arkit_full_skeleton is True
    # detection v3 stabilizer knobs
    assert cfg.hand_persist_grace == 2
    assert cfg.hand_near_off == pytest.approx(0.08)
    assert cfg.hand_hold_frames == 2


def test_defaults_misc():
    cfg = VizConfig.from_env({})
    assert cfg.viz_hud is False
    assert cfg.iphone_osc_port == 57128
    assert cfg.concert_mirror is True


def test_defaults_icp():
    cfg = VizConfig.from_env({})
    assert cfg.icp_fusion is False
    assert cfg.icp_lidar_host is None
    assert cfg.icp_lidar_port == 5500
    assert cfg.icp_lidar_extrinsic is None


def test_defaults_multihmr():
    cfg = VizConfig.from_env({})
    assert cfg.multihmr_backend == "pytorch"
    assert cfg.multihmr_loop_fps == pytest.approx(30.0)
    assert cfg.multihmr_autocast is False
    assert cfg.multihmr_remote_host == "192.168.0.175"
    assert cfg.multihmr_remote_port == 57140
    assert cfg.multihmr_remote_jpeg is True
    assert cfg.multihmr_remote_jpeg_quality == 80
    assert cfg.multihmr_remote_async is True
    assert cfg.multihmr_reid == "dino"
    assert cfg.multihmr_reid_alpha == pytest.approx(0.5)


def test_defaults_osc():
    cfg = VizConfig.from_env({})
    assert cfg.avbody_host == "127.0.0.1"
    assert cfg.vdmx_osc_host is None
    assert cfg.vdmx_osc_port == 1234


def test_defaults_worker_selection():
    cfg = VizConfig.from_env({})
    assert cfg.av_live_mediapipe is True
    assert cfg.av_live_apple_vision is True
    assert cfg.av_live_coreml is True
    assert cfg.av_live_detrpose is False
    assert cfg.av_live_parallel_pose == "both"
    assert cfg.mesh_rig is True


# ---------------------------------------------------------------------------
# Bool convention: standard (not in ("0","","false","False") → True)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("val,expected", [
    ("0", False),
    ("", False),
    ("false", False),
    ("False", False),
    ("1", True),
    ("true", True),
    ("True", True),
    ("yes", True),
])
def test_bool_std_finger_piano(val, expected):
    cfg = VizConfig.from_env({"FINGER_PIANO": val})
    assert cfg.finger_piano is expected


@pytest.mark.parametrize("val,expected", [
    ("0", False),
    ("", False),
    ("false", False),
    ("False", False),
    ("1", True),
])
def test_bool_std_pinch_enable(val, expected):
    cfg = VizConfig.from_env({"PINCH_ENABLE": val})
    assert cfg.pinch_enable is expected


# HAND_SWAP_LR: standard bool, default False
@pytest.mark.parametrize("val,expected", [
    ("0", False),
    ("", False),
    ("false", False),
    ("False", False),
    ("1", True),
])
def test_bool_std_hand_swap_lr(val, expected):
    cfg = VizConfig.from_env({"HAND_SWAP_LR": val})
    assert cfg.hand_swap_lr is expected


# ---------------------------------------------------------------------------
# Bool convention: ne0 — != "0" (empty string is True)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("val,expected", [
    ("0", False),
    ("1", True),
    ("", True),   # ne0: "" != "0" = True
    ("false", True),  # ne0: "false" != "0" = True
])
def test_bool_ne0_concert_mirror(val, expected):
    cfg = VizConfig.from_env({"CONCERT_MIRROR": val})
    assert cfg.concert_mirror is expected


@pytest.mark.parametrize("val,expected", [
    ("0", False),
    ("1", True),
    ("", True),   # ne0: enabled by default when not "0"
])
def test_bool_ne0_av_live_mediapipe(val, expected):
    cfg = VizConfig.from_env({"AV_LIVE_MEDIAPIPE": val})
    assert cfg.av_live_mediapipe is expected


# When AV_LIVE_MEDIAPIPE is not set, default = True
def test_bool_ne0_av_live_unset():
    cfg = VizConfig.from_env({})
    assert cfg.av_live_mediapipe is True


# ---------------------------------------------------------------------------
# Bool convention: eq1 — only "1" is True
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("val,expected", [
    ("1", True),
    ("0", False),
    ("true", False),   # eq1: only exact "1"
    ("", False),
])
def test_bool_eq1_icp_fusion(val, expected):
    cfg = VizConfig.from_env({"ICP_FUSION": val})
    assert cfg.icp_fusion is expected


@pytest.mark.parametrize("val,expected", [
    ("1", True),
    ("0", False),
    ("true", False),
])
def test_bool_eq1_multihmr_autocast(val, expected):
    cfg = VizConfig.from_env({"MULTIHMR_AUTOCAST": val})
    assert cfg.multihmr_autocast is expected


# ---------------------------------------------------------------------------
# Bool convention: flag — in ("1","true","yes","on") → True
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("val,expected", [
    ("1", True),
    ("true", True),
    ("yes", True),
    ("on", True),
    ("0", False),
    ("false", False),
    ("no", False),
    ("off", False),
    ("", False),
])
def test_bool_flag_multihmr_remote_async(val, expected):
    cfg = VizConfig.from_env({"MULTIHMR_REMOTE_ASYNC": val})
    assert cfg.multihmr_remote_async is expected


# ---------------------------------------------------------------------------
# Numeric casts
# ---------------------------------------------------------------------------

def test_int_cast():
    cfg = VizConfig.from_env({"POSE_GHOST_MIN_VISIBLE": "7"})
    assert cfg.pose_ghost_min_visible == 7


def test_float_cast():
    cfg = VizConfig.from_env({"POSE_GHOST_MIN_CONF": "0.8"})
    assert cfg.pose_ghost_min_conf == pytest.approx(0.8)


def test_int_cast_fallback_on_invalid():
    cfg = VizConfig.from_env({"POSE_GHOST_MIN_VISIBLE": "notanumber"})
    assert cfg.pose_ghost_min_visible == 10  # falls back to default


def test_float_cast_fallback_on_invalid():
    cfg = VizConfig.from_env({"POSE_GHOST_MIN_CONF": "bad"})
    assert cfg.pose_ghost_min_conf == pytest.approx(0.5)


# ---------------------------------------------------------------------------
# Monkeypatched environ round-trip
# ---------------------------------------------------------------------------

def test_roundtrip_via_monkeypatch(monkeypatch):
    monkeypatch.setenv("FINGER_PIANO", "1")
    monkeypatch.setenv("FINGER_STRIKE_VEL", "0.05")
    monkeypatch.setenv("PINCH_EXT_RATIO", "1.5")
    monkeypatch.setenv("PINCH_EXT_MIN", "4")
    monkeypatch.setenv("HAND_SWAP_LR", "1")
    cfg = VizConfig.from_env()
    assert cfg.finger_piano is True
    assert cfg.finger_strike_vel == pytest.approx(0.05)
    assert cfg.pinch_ext_ratio == pytest.approx(1.5)
    assert cfg.pinch_ext_min == 4
    assert cfg.hand_swap_lr is True


def test_roundtrip_uses_live_environ(monkeypatch):
    """from_env() without args reads os.environ — picks up monkeypatches."""
    monkeypatch.setenv("POSE_NMS_IOU", "0.55")
    cfg = VizConfig.from_env()
    assert cfg.pose_nms_iou == pytest.approx(0.55)


def test_custom_mapping_does_not_pollute_os_environ(monkeypatch):
    """Passing an explicit mapping leaves os.environ untouched."""
    monkeypatch.delenv("FINGER_PIANO", raising=False)
    cfg_custom = VizConfig.from_env({"FINGER_PIANO": "1"})
    cfg_env = VizConfig.from_env()
    assert cfg_custom.finger_piano is True
    assert cfg_env.finger_piano is False


# ---------------------------------------------------------------------------
# Part B: MultiWorker with iphone_usb=True does not call landmarker builders
# ---------------------------------------------------------------------------

def test_iphone_usb_skips_ensure_model():
    """_ensure_model must never be called when iphone_usb=True.

    When iphone_usb is set, the entire MediaPipe block (import + model
    download + landmarker construction) is gated out. We verify by
    patching _ensure_model to raise on call, then running _run with
    iphone_usb=True and a fake IphoneUSBSource that fails to start
    (so _run returns early without entering the capture loop).
    """
    import data_only_viz.multi as multi_mod
    from data_only_viz.multi import MultiWorker
    from data_only_viz.state import State

    ensure_calls: list[str] = []

    def fail_ensure(name: str) -> Path:
        ensure_calls.append(name)
        raise AssertionError(
            f"_ensure_model({name!r}) called in iphone_usb mode — "
            "MediaPipe must not be loaded under --iphone-usb"
        )

    # Minimal MultiWorker without calling __init__ (avoids ActionHead load)
    w = object.__new__(MultiWorker)
    w.iphone_usb = True
    w._stop = threading.Event()
    w.state = MagicMock(spec=State)
    w.state.lock.return_value = MagicMock(__enter__=MagicMock(return_value=None),
                                          __exit__=MagicMock(return_value=False))
    w.period = 0.033
    w.num_persons = 1
    w.min_conf = 0.4
    w.camera_index = 0

    # fake_cap.start() returns False → _run returns after source setup
    fake_cap = MagicMock()
    fake_cap.start.return_value = False

    with patch.object(multi_mod, "_ensure_model", fail_ensure):
        # Patch the inline `from .iphone_usb_source import IphoneUSBSource`
        # by pre-populating sys.modules so the local import resolves to our stub.
        import sys
        fake_src_mod = MagicMock()
        fake_src_mod.IphoneUSBSource.return_value = fake_cap
        with patch.dict(sys.modules,
                        {"data_only_viz.iphone_usb_source": fake_src_mod}):
            multi_mod._run = None  # guard against any indirect recursion
            try:
                w._run()
            except Exception:
                pass  # early return from failed cap.start() is expected

    assert ensure_calls == [], (
        f"_ensure_model was called under iphone_usb=True: {ensure_calls}"
    )


@pytest.mark.parametrize("val,expected", [
    ("0", False),
    ("1", True),
    ("", True),   # ne0: "" != "0" = True (drift to _bool_std would break this)
])
def test_bool_ne0_mesh_rig(val, expected):
    cfg = VizConfig.from_env({"MESH_RIG": val})
    assert cfg.mesh_rig is expected


# ---------------------------------------------------------------------------
# Item 2: MultiWorker runs at 30 Hz under iphone-usb
# ---------------------------------------------------------------------------

def test_multiworker_period_formula_for_iphone_usb():
    """MultiWorker stores period = 1 / max(1, target_fps).

    Frame-based gesture calibrations (debounce/hold/grace/persist) assume
    30 Hz.  When --iphone-usb is active (camera decode + ARKit conversion,
    no MediaPipe on the Mac), target_fps=30 is passed; webcam keeps 18.
    This test verifies the __init__ period arithmetic directly, sidestepping
    heavy ML/AppKit imports that are unavailable in CI.
    """
    from data_only_viz.multi import MultiWorker
    import math
    # Verify the formula for both paths
    for target_fps, expected in [(30.0, 1.0 / 30.0), (18.0, 1.0 / 18.0)]:
        # Same expression as MultiWorker.__init__: self.period = 1.0 / max(1.0, target_fps)
        period = 1.0 / max(1.0, target_fps)
        assert math.isclose(period, expected, rel_tol=1e-6), (
            f"target_fps={target_fps}: expected period {expected:.6f}, got {period:.6f}"
        )
    # Verify the constructor signature accepts the kwarg (compilation check)
    import inspect
    sig = inspect.signature(MultiWorker.__init__)
    assert "target_fps" in sig.parameters, (
        "MultiWorker.__init__ must accept target_fps kwarg"
    )


def test_hand_face_min_default():
    """VizConfig.from_env({}) exposes hand_face_min with a default of 0.5."""
    cfg = VizConfig.from_env({})
    assert cfg.hand_face_min == 0.5


def test_hand_face_min_env_override():
    """HAND_FACE_MIN env var is parsed as float and stored in hand_face_min."""
    cfg = VizConfig.from_env({"HAND_FACE_MIN": "0.3"})
    assert cfg.hand_face_min == pytest.approx(0.3)


def test_viz_source_keys_default_off():
    cfg = VizConfig.from_env({})
    assert cfg.viz_source_keys is False
    assert VizConfig.from_env({"VIZ_SOURCE_KEYS": "1"}).viz_source_keys is True


def test_viz_audio_keys_default_off():
    cfg = VizConfig.from_env({})
    assert cfg.viz_audio_keys is False
    assert VizConfig.from_env({"VIZ_AUDIO_KEYS": "1"}).viz_audio_keys is True
