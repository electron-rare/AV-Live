"""Wrapper minimal autour de smplx.SMPLXLayer pour decoder les params
de Multi-HMR (betas + thetas + expression) en vertices 3D."""
from __future__ import annotations

import logging
from pathlib import Path

import numpy as np
import torch

LOG = logging.getLogger("smplx_decoder")


class SMPLXDecoder:
    """Charge SMPL-X NEUTRAL et expose decode(params) -> (verts, joints)."""

    def __init__(self, model_path: str, device: str = "mps") -> None:
        import smplx
        self.device = device
        model_path_p = Path(model_path)
        if model_path_p.is_file():
            # smplx.SMPLXLayer attend le dossier contenant SMPLX_<GENDER>.<ext>
            model_folder = str(model_path_p.parent)
            ext = "npz" if model_path_p.suffix == ".npz" else "pkl"
        else:
            model_folder = str(model_path_p)
            ext = "npz"
        self.layer = smplx.SMPLXLayer(
            model_path=model_folder,
            gender="neutral",
            num_betas=10,
            num_expression_coeffs=10,
            ext=ext,
        ).to(device).eval()
        LOG.info("SMPL-X loaded from %s (device=%s)", model_folder, device)

    @torch.no_grad()
    def decode(
        self,
        betas: torch.Tensor,
        body_pose: torch.Tensor,
        global_orient: torch.Tensor,
        left_hand_pose: torch.Tensor,
        right_hand_pose: torch.Tensor,
        jaw_pose: torch.Tensor,
        expression: torch.Tensor,
        transl: torch.Tensor,
    ) -> tuple[np.ndarray, np.ndarray]:
        out = self.layer(
            betas=betas, body_pose=body_pose, global_orient=global_orient,
            left_hand_pose=left_hand_pose, right_hand_pose=right_hand_pose,
            jaw_pose=jaw_pose, expression=expression, transl=transl,
            return_verts=True,
        )
        return out.vertices.cpu().numpy(), out.joints.cpu().numpy()

    @torch.no_grad()
    def decode_neutral(self) -> tuple[np.ndarray, np.ndarray]:
        """T-pose neutre. Les poses sont des matrices de rotation : on
        utilise l'identite (pas zeros, qui collapserait le mesh)."""
        d = self.device
        B = 1

        def eye(n: int) -> torch.Tensor:
            return torch.eye(3, device=d).expand(B, n, 3, 3).contiguous()

        out = self.layer(
            betas=torch.zeros((B, 10), device=d),
            body_pose=eye(21),
            global_orient=eye(1),
            left_hand_pose=eye(15),
            right_hand_pose=eye(15),
            jaw_pose=eye(1),
            expression=torch.zeros((B, 10), device=d),
            transl=torch.zeros((B, 3), device=d),
        )
        return (out.vertices[0].cpu().numpy(),
                out.joints[0].cpu().numpy())
