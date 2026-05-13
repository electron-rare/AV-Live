"""Worker Multi-HMR : capture webcam Mac, inference forward unique
SMPL-X (multi-personne natif), extraction vertices v3d, ecriture State.

Le repo Multi-HMR n'est pas pip-installable — on injecte le clone dans
sys.path au runtime. Chaque humain renvoye contient deja les vertices
SMPL-X decodes (cle `v3d`, shape (10475, 3)) ; pas besoin du decoder
SMPL-X separe en hot path (il reste utile pour les tests).

Cadence cible : 8-12 fps sur M5 (ViT-S). Lissage One Euro sur les
shapes/expression pour limiter le jitter trame-a-trame.
"""
from __future__ import annotations

import logging
import os
import sys
import threading
import time
from pathlib import Path

import numpy as np

from .euro_filter import OneEuroFilter
from .state import PoseKp, SMPLXPerson, State
from .tracker import IoUTracker

LOG = logging.getLogger("multi_hmr")

CACHE = Path.home() / ".cache" / "av-live-multihmr"
CKPT = CACHE / "checkpoints" / "multiHMR_672_S.pt"
SMPLX_PATH = CACHE / "models" / "smplx" / "SMPLX_NEUTRAL.npz"
MULTIHMR_REPO = CACHE / "multi-hmr"

IMG_SIZE = 672
N_VERTS = 10475


class MultiHMRWorker:
    def __init__(self, state: State, num_persons: int = 4,
                 target_fps: float = 10.0, device: str = "mps",
                 det_thresh: float = 0.3,
                 nms_kernel_size: int = 5,
                 camera_index: int = -1) -> None:
        self.state = state
        self.num_persons = num_persons
        self.period = 1.0 / max(1.0, target_fps)
        self.device = device
        self.det_thresh = det_thresh
        self.nms_kernel_size = nms_kernel_size
        # -1 = auto-select Mac BuiltInWideAngleCamera (cf _camera_select)
        self.camera_index = camera_index
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._smooth_shape = [
            [OneEuroFilter(0.8, 0.05) for _ in range(10)]
            for _ in range(num_persons)
        ]
        self._smooth_expr = [
            [OneEuroFilter(1.0, 0.08) for _ in range(10)]
            for _ in range(num_persons)
        ]
        # iou_threshold bas + max_miss eleve + prediction velocity
        # (cf tracker.py) pour resister aux occlusions et au mouvement
        # rapide. Multi-HMR a 3 fps -> 30 frames = 10s de survie.
        self._tracker = IoUTracker(iou_threshold=0.15, max_miss=30)

    @staticmethod
    def is_available() -> bool:
        return CKPT.exists() and SMPLX_PATH.exists() and MULTIHMR_REPO.exists()

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="multi_hmr", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _run(self) -> None:
        if str(MULTIHMR_REPO) not in sys.path:
            sys.path.insert(0, str(MULTIHMR_REPO))
        # Multi-HMR demo.py tire pyrender / pyvista (OpenGL offscreen) et
        # multi_hmr_anny (anny package non public). Aucun n'est necessaire
        # pour l'inference brute : on stubbe.
        import types as _t
        for mod in ("pyrender", "pyvista", "anny"):
            if mod not in sys.modules:
                sys.modules[mod] = _t.ModuleType(mod)
        try:
            import torch
            import cv2
            # Import direct du Model (sans passer par demo.load_model qui
            # depend de multi_hmr_anny).
            from model import Model  # type: ignore
        except ImportError as e:
            LOG.error("deps manquantes : %s — uv sync --extra multihmr "
                      "et bash scripts/setup_multihmr.sh", e)
            return

        if self.device == "mps" and not torch.backends.mps.is_available():
            LOG.warning("MPS unavailable, falling back to cpu")
            device = "cpu"
        else:
            device = self.device

        ckpt_name = CKPT.stem
        # SMPLX_DIR='models' et MEAN_PARAMS='models/smpl_mean_params.npz'
        # sont relatifs au cwd. On bascule dans le repo Multi-HMR pour la
        # construction du modele puis on revient.
        prev_cwd = os.getcwd()
        try:
            os.chdir(MULTIHMR_REPO)
            torch_device = torch.device(device)
            ckpt = torch.load(str(CKPT), map_location=torch_device,
                              weights_only=False)
            kwargs = {k: v for k, v in vars(ckpt["args"]).items()}
            kwargs["type"] = ckpt["args"].train_return_type
            kwargs["img_size"] = ckpt["args"].img_size[0]
            model = Model(**kwargs).to(torch_device)
            model.load_state_dict(ckpt["model_state_dict"], strict=False)
            model.eval()
        except Exception as e:
            LOG.error("Multi-HMR load failed: %s", e)
            os.chdir(prev_cwd)
            return
        finally:
            os.chdir(prev_cwd)
        LOG.info("Multi-HMR loaded (%s) on %s", ckpt_name, device)

        # Camera intrinsics (focale = img_size par defaut). batch dim 1.
        focal = float(IMG_SIZE)
        K = torch.tensor([[[focal, 0.0, IMG_SIZE / 2.0],
                           [0.0, focal, IMG_SIZE / 2.0],
                           [0.0, 0.0, 1.0]]], device=device)

        # Capture AVFoundation native — selection par device-type, pas
        # par index cv2 (qui ne suit pas l'ordre AVFoundation et finit
        # parfois sur l'iPhone Continuity).
        from ._av_capture import AVCapture, find_builtin_device, enumerate_devices
        if self.camera_index >= 0:
            devs = enumerate_devices()
            if self.camera_index >= len(devs):
                LOG.error("camera_index %d hors de %d devices",
                          self.camera_index, len(devs))
                return
            info = devs[self.camera_index]
        else:
            info = find_builtin_device()
            if info is None:
                LOG.error("aucune BuiltInWideAngleCamera trouvee")
                return
        cap = AVCapture(info)
        if not cap.start():
            LOG.error("AVCapture start failed pour %s", info["name"])
            return
        LOG.info("camera ouverte %s (%s)", info["name"], info["type"])
        frame_count = 0
        persons_count = 0
        next_heartbeat = time.monotonic() + 5.0

        while not self._stop.is_set():
            t_cap_start = time.monotonic()
            ok, frame_bgr = cap.read(timeout_s=0.5)
            if not ok or frame_bgr is None:
                time.sleep(self.period)
                continue

            t_pre_start = time.monotonic()
            # Crop/resize au carre 896 pour matcher Multi-HMR
            h, w = frame_bgr.shape[:2]
            if (h, w) != (IMG_SIZE, IMG_SIZE):
                # Center-crop + resize
                side = min(h, w)
                y0 = (h - side) // 2
                x0 = (w - side) // 2
                frame_bgr = frame_bgr[y0:y0 + side, x0:x0 + side]
                frame_bgr = cv2.resize(frame_bgr, (IMG_SIZE, IMG_SIZE))

            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            tensor = torch.from_numpy(frame_rgb).permute(2, 0, 1).float()
            tensor = (tensor / 255.0).unsqueeze(0).to(device)

            t_inf_start = time.monotonic()
            try:
                with torch.no_grad():
                    humans = model(
                        tensor,
                        is_training=False,
                        nms_kernel_size=self.nms_kernel_size,
                        det_thresh=self.det_thresh,
                        K=K,
                    )
            except Exception as e:
                LOG.warning("inference failed: %s", e)
                time.sleep(self.period)
                continue

            t_post_start = time.monotonic()
            t_now = time.monotonic()
            # Count frame + heartbeat regardless of detection — keeps the
            # FPS metric meaningful when nobody is in the camera view.
            frame_count += 1
            persons_count += len(humans) if humans else 0
            if t_now >= next_heartbeat:
                fps = frame_count / 5.0
                avg = persons_count / max(1, frame_count)
                LOG.info(
                    "hb: %.1f fps, %.2f persons/frame (%d frames)",
                    fps, avg, frame_count)
                frame_count = 0
                persons_count = 0
                next_heartbeat = t_now + 5.0
            if not humans:
                with self.state.lock():
                    self.state.persons_smplx = []
                inf_ms = (t_post_start - t_inf_start) * 1e3
                LOG.debug("frame (no detect): inf=%.1fms", inf_ms)
                time.sleep(self.period)
                continue

            # Dedup intra-frame : Multi-HMR peut retourner plusieurs
            # detections pour la meme personne. On combine bbox 2D IoU
            # ET distance pelvis 3D : drop ssi IoU > 0.4 ET dist < 30 cm.
            # Comme ca deux personnes qui se chevauchent en 2D (une
            # devant l'autre) restent distinctes grace au z.
            cand: list[tuple[
                float, float, float, float, float,
                np.ndarray, int]] = []
            for i, h in enumerate(humans):
                v = h["v3d"].detach().cpu().numpy()
                xmin = float(v[:, 0].min())
                ymin = float(v[:, 1].min())
                xmax = float(v[:, 0].max())
                ymax = float(v[:, 1].max())
                sc_raw = h.get("scores", 1.0)
                score = float(sc_raw.item()) if hasattr(
                    sc_raw, "item") else float(sc_raw)
                transl = h.get("transl_pelvis", h.get("transl"))
                pelv = transl.detach().cpu().numpy().flatten()[:3]
                cand.append((score, xmin, ymin, xmax, ymax, pelv, i))
            cand.sort(key=lambda c: -c[0])
            keep_idx: list[int] = []
            kept: list[tuple[
                float, float, float, float, np.ndarray]] = []
            for sc, x0, y0, x1, y1, pelv, src_i in cand:
                a_area = max(0.0, x1 - x0) * max(0.0, y1 - y0)
                drop = False
                for (kx0, ky0, kx1, ky1, kpelv) in kept:
                    ix0 = max(x0, kx0); iy0 = max(y0, ky0)
                    ix1 = min(x1, kx1); iy1 = min(y1, ky1)
                    iw = max(0.0, ix1 - ix0); ih = max(0.0, iy1 - iy0)
                    inter = iw * ih
                    if a_area <= 0 or inter <= 0:
                        continue
                    k_area = (kx1 - kx0) * (ky1 - ky0)
                    iou = inter / (a_area + k_area - inter + 1e-9)
                    pelv_d = float(np.linalg.norm(pelv - kpelv))
                    # Drop seulement si TRES proches en 3D ET grand
                    # overlap 2D. Seuils volontairement conservateurs
                    # pour ne pas fusionner deux personnes serrees.
                    if iou > 0.55 and pelv_d < 0.20:
                        drop = True
                        break
                if not drop:
                    keep_idx.append(src_i)
                    kept.append((x0, y0, x1, y1, pelv))
                    if len(keep_idx) >= self.num_persons:
                        break
            n_raw = len(humans)
            humans = [humans[i] for i in keep_idx]
            n_keep = len(humans)
            if n_raw != n_keep:
                LOG.debug("dedup: %d -> %d (raw det_thresh=%.2f)",
                          n_raw, n_keep, self.det_thresh)

            # Tracking via bbox approximee depuis verts projetes (xy)
            bboxes = []
            for h in humans:
                v = h["v3d"].detach().cpu().numpy()  # (10475, 3)
                xmin, ymin = float(v[:, 0].min()), float(v[:, 1].min())
                xmax, ymax = float(v[:, 0].max()), float(v[:, 1].max())
                bboxes.append([PoseKp(x=xmin, y=ymin, c=1.0),
                               PoseKp(x=xmax, y=ymax, c=1.0)])
            ids = self._tracker.update(bboxes)

            persons: list[SMPLXPerson] = []
            for i, hh in enumerate(humans[:n_keep]):
                pid = ids[i] if i < len(ids) else i
                if pid < 0:
                    continue

                v3d = hh["v3d"].detach().cpu().numpy()
                transl = hh.get("transl_pelvis", hh.get("transl"))
                transl_np = transl.detach().cpu().numpy().flatten()

                shape_raw = hh["shape"].detach().cpu().numpy().flatten()
                expr_raw = hh["expression"].detach().cpu().numpy().flatten()

                pid_c = pid % self.num_persons
                shape_n = min(10, len(shape_raw))
                expr_n = min(10, len(expr_raw))
                shape_smooth = np.zeros(10, dtype=np.float32)
                expr_smooth = np.zeros(10, dtype=np.float32)
                for k in range(shape_n):
                    shape_smooth[k] = self._smooth_shape[pid_c][k](
                        float(shape_raw[k]), t_now)
                for k in range(expr_n):
                    expr_smooth[k] = self._smooth_expr[pid_c][k](
                        float(expr_raw[k]), t_now)

                persons.append(SMPLXPerson(
                    pid=int(pid),
                    vertices_3d=np.ascontiguousarray(v3d, dtype=np.float32),
                    translation=np.ascontiguousarray(transl_np[:3], dtype=np.float32),
                    confidence=float(hh.get("scores", 1.0)) if not hasattr(
                        hh.get("scores", None), "item") else float(
                        hh["scores"].item()),
                    betas=np.ascontiguousarray(shape_smooth, dtype=np.float32),
                    expression=np.ascontiguousarray(expr_smooth, dtype=np.float32),
                ))

            with self.state.lock():
                self.state.persons_smplx = persons
                self.state.smplx_last_t = t_now

            t_end = time.monotonic()
            dt_total = (t_end - t_cap_start) * 1e3
            if LOG.isEnabledFor(logging.DEBUG) or dt_total > 100.0:
                LOG.log(
                    logging.DEBUG if dt_total <= 100.0 else logging.WARNING,
                    "frame: cap=%.1f pre=%.1f inf=%.1f post=%.1fms total=%.1fms",
                    (t_pre_start - t_cap_start) * 1e3,
                    (t_inf_start - t_pre_start) * 1e3,
                    (t_post_start - t_inf_start) * 1e3,
                    (t_end - t_post_start) * 1e3,
                    dt_total,
                )

            dt = time.monotonic() - t_cap_start
            if dt < self.period:
                time.sleep(self.period - dt)

        cap.stop()
        LOG.info("multi_hmr worker stopped")
