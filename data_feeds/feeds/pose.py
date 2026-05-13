"""Webcam → OpenCV → pose detection (YOLOv8-pose) → OSC.

Pourquoi YOLOv8-pose plutot qu'OpenPose proper ?
  - OpenPose officiel = build CUDA, douloureux sur Mac ARM.
  - YOLOv8-pose : pip install, MPS/Metal accelere, 17 keypoints COCO
    (proche d'OpenPose BODY_25, suffisant pour de l'AV-live).
  - Pour un vrai OpenPose, swap simple : remplacer `Detector` par un
    wrapper autour de pyopenpose ou cmu-openpose et conserver le format
    keypoints (x_norm, y_norm, conf) emis sur OSC.

Sortie OSC :
  /data/pose/count <n>
  /data/pose/person <idx> <cx> <cy> <w> <h> <conf>
  /data/pose/skel   <idx> <conf_avg> <x0 y0 c0 ... x16 y16 c16>
  /data/pose/bone   <idx> <kp_a> <kp_b>           (a la connexion, statique)

Toutes les coordonnees sont normalisees 0..1 (origine top-left).
"""
from __future__ import annotations

import asyncio
import logging
import time

LOG = logging.getLogger("feed.pose")

# Squelette COCO 17 keypoints (paires d'os).
COCO_BONES: list[tuple[int, int]] = [
    (0, 1), (0, 2), (1, 3), (2, 4),         # tete
    (5, 6), (5, 7), (7, 9), (6, 8), (8, 10),# bras
    (5, 11), (6, 12), (11, 12),              # torse
    (11, 13), (13, 15), (12, 14), (14, 16), # jambes
]


class _Lazy:
    """Imports lourds differes pour ne pas casser le pont entier si pose
    n'est pas demande."""
    def __init__(self) -> None:
        self.cv2 = None
        self.YOLO = None
        self.np = None

    def load(self) -> None:
        if self.cv2 is not None:
            return
        import cv2  # type: ignore
        import numpy as np  # type: ignore
        from ultralytics import YOLO  # type: ignore
        self.cv2 = cv2
        self.np = np
        self.YOLO = YOLO


_LAZY = _Lazy()


async def run(ctx) -> None:
    cfg = ctx.cfg
    try:
        _LAZY.load()
    except ModuleNotFoundError as e:
        LOG.error("dependances manquantes : %s — uv sync --extra pose", e)
        await asyncio.Event().wait()
        return

    cv2, np, YOLO = _LAZY.cv2, _LAZY.np, _LAZY.YOLO

    cam_idx     = int(cfg.get("camera", 0))
    width       = int(cfg.get("width", 640))
    height      = int(cfg.get("height", 480))
    target_fps  = float(cfg.get("target_fps", 20))
    conf_thresh = float(cfg.get("conf_thresh", 0.35))
    max_persons = int(cfg.get("max_persons", 4))
    emit_kp     = bool(cfg.get("emit_keypoints", True))
    model_name  = cfg.get("model", "yolov8n-pose.pt")
    device      = cfg.get("device", "mps")

    LOG.info("loading %s on %s", model_name, device)
    model = YOLO(model_name)

    cap = cv2.VideoCapture(cam_idx)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
    if not cap.isOpened():
        LOG.error("camera index %d indisponible", cam_idx)
        await asyncio.Event().wait()
        return

    # Annonce du squelette (statique, une fois)
    for a, b in COCO_BONES:
        ctx.send("bone", float(a), float(b))

    loop = asyncio.get_running_loop()
    period = 1.0 / max(1.0, target_fps)
    LOG.info("pose stream up: %dx%d @ %.1f fps target", width, height, target_fps)

    def _grab():
        ok, frame = cap.read()
        return frame if ok else None

    # ThreadPoolExecutor dedie : empeche l'inference longue (>20ms sur MPS)
    # de monopoliser le pool partage et de bloquer les autres feeds.
    import concurrent.futures
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=1,
                                                 thread_name_prefix="pose")

    def _infer(fr):
        return model.predict(fr, device=device, conf=conf_thresh,
                             verbose=False, max_det=max_persons)

    try:
        while True:
            t0 = time.monotonic()
            frame = await loop.run_in_executor(pool, _grab)
            if frame is None:
                await asyncio.sleep(period)
                continue
            h, w = frame.shape[:2]
            try:
                # Non-bloquant : l'event loop continue de servir les autres
                # feeds pendant les ~20-80 ms d'inference.
                results = await loop.run_in_executor(pool, _infer, frame)
            except Exception as e:  # noqa: BLE001
                LOG.warning("inference failed: %s", e)
                await asyncio.sleep(period)
                continue
            if not results:
                ctx.send("count", 0.0)
                await asyncio.sleep(period)
                continue

            res = results[0]
            kp_xy   = getattr(res.keypoints, "xy", None)
            kp_conf = getattr(res.keypoints, "conf", None)
            boxes   = getattr(res, "boxes", None)
            n = 0 if kp_xy is None else int(len(kp_xy))
            ctx.send("count", float(n))

            for i in range(n):
                # bbox normalisee
                if boxes is not None and i < len(boxes):
                    b = boxes.xywhn[i].cpu().numpy().tolist()  # cx, cy, w, h
                    conf_b = float(boxes.conf[i].item())
                    ctx.send("person", float(i), *b, conf_b)
                if not emit_kp or kp_xy is None:
                    continue
                pts  = kp_xy[i].cpu().numpy()              # (17, 2) px
                cfs  = kp_conf[i].cpu().numpy() if kp_conf is not None \
                       else np.ones(len(pts), dtype=float)
                flat: list[float] = []
                conf_sum = 0.0
                for (x, y), c in zip(pts, cfs):
                    xn = float(x) / max(1.0, w)
                    yn = float(y) / max(1.0, h)
                    cc = float(c)
                    flat.extend([xn, yn, cc])
                    conf_sum += cc
                avg = conf_sum / max(1, len(pts))
                ctx.send("skel", float(i), avg, *flat)

            # cadence
            dt = time.monotonic() - t0
            if dt < period:
                await asyncio.sleep(period - dt)
    finally:
        cap.release()
        pool.shutdown(wait=False, cancel_futures=True)
