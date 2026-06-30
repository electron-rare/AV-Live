"""ARKit ARSkeleton3D 91-joint indices → MediaPipe Pose 33 indices.

The ARKit ARSkeleton.JointName enum (Apple SDK) orders 91 joints
starting with the root, hips, spine chain, shoulders, etc. We pick
only the joints with a clear 1:1 anatomical correspondence to the
MediaPipe Pose 33 landmark set (which is what AVLiveBody renders).
Face/hand sub-joints (fingers, eyes) are skipped — those keep their
existing data sources (MediaPipe Face/Hand + HaMeR MANO).

Reference for ARKit joint order : Apple developer docs
"ARSkeleton.JointName" — the canonical 91-joint list runs from
root_joint=0 down to right_handThumbEndJoint=90.

The selection here mirrors `multi.py::SMPLX_TO_MP33` so the same 14
body slots are overridden by ARKit when fresh. Confidence comes
from ARKit's tracking state but is not currently fanned out — we
trust ARKit body tracking when its OSC frame is present.
"""
from __future__ import annotations

# MediaPipe Pose 33 cardinality (cf. mediapipe pose_world_landmarks).
MP33_NUM_LANDMARKS = 33

# Pelvis = ARKit hips_joint, slot 1 in the canonical enum order.
# Used by multi_hmr_worker for cam-translation z lock.
ARKIT_PELVIS_IDX = 1

# ARKit head joint index in the 91-joint enum.
# Tentatively mapped to index 51 (head_joint in Apple's canonical ordering).
# VERIFY LIVE (controller will confirm the index on the rig)
ARKIT_HEAD_IDX = 51

# (arkit_joint_idx, mediapipe_pose_idx). Match the body slots used
# by the SMPL-X body fusion in multi.py.
ARKIT91_TO_MP33: tuple[tuple[int, int], ...] = (
    (ARKIT_HEAD_IDX, 0),  # head_joint -> NOSE (anchor; VERIFY LIVE)
    (50, 11),   # left_shoulder_1_joint -> L_SHOULDER
    (32, 12),   # right_shoulder_1_joint -> R_SHOULDER
    (53, 13),   # left_arm_joint -> L_ELBOW
    (35, 14),   # right_arm_joint -> R_ELBOW
    (54, 15),   # left_forearm_joint -> L_WRIST
    (36, 16),   # right_forearm_joint -> R_WRIST
    (62, 23),   # left_upLeg_joint -> L_HIP
    (57, 24),   # right_upLeg_joint -> R_HIP
    (63, 25),   # left_leg_joint -> L_KNEE
    (58, 26),   # right_leg_joint -> R_KNEE
    (64, 27),   # left_foot_joint -> L_ANKLE
    (59, 28),   # right_foot_joint -> R_ANKLE
    (65, 31),   # left_toes_joint -> L_FOOT_INDEX
    (60, 32),   # right_toes_joint -> R_FOOT_INDEX
)


def arkit_body_2d(arr2d) -> list:
    """Map a 91×2 normalized ARKit 2D skeleton to a MediaPipe Pose-33 list.

    Mapped slots get c=1.0; all other slots default to c=0.0 (low confidence).

    Args:
        arr2d: array-like of shape (91, 2), image-normalized coords [0..1].

    Returns:
        list of 33 PoseKp instances.
    """
    from .state import PoseKp  # noqa: PLC0415
    body: list = [PoseKp() for _ in range(MP33_NUM_LANDMARKS)]
    for ai, mp in ARKIT91_TO_MP33:
        if mp < MP33_NUM_LANDMARKS and ai < len(arr2d):
            body[mp] = PoseKp(x=float(arr2d[ai][0]), y=float(arr2d[ai][1]),
                              z=0.0, c=1.0)
    return body


def arkit_body_3d(arr3d) -> list:
    """Map a 91×3 world ARKit skeleton to a MediaPipe Pose-33 Kp3D list.

    Mapped slots get c=1.0; all other slots default to c=0.0 (low confidence).

    Args:
        arr3d: array-like of shape (91, 3), metric world coords (metres).

    Returns:
        list of 33 Kp3D instances.
    """
    from .state import Kp3D  # noqa: PLC0415
    body: list = [Kp3D() for _ in range(MP33_NUM_LANDMARKS)]
    for ai, mp in ARKIT91_TO_MP33:
        if mp < MP33_NUM_LANDMARKS and ai < len(arr3d):
            body[mp] = Kp3D(x=float(arr3d[ai][0]), y=float(arr3d[ai][1]),
                            z=float(arr3d[ai][2]), c=1.0)
    return body
