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

# (arkit_joint_idx, mediapipe_pose_idx). Match the body slots used
# by the SMPL-X body fusion in multi.py.
ARKIT91_TO_MP33: tuple[tuple[int, int], ...] = (
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
