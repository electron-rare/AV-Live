#!/usr/bin/env python3
"""Conversion des modeles pose vers CoreML .mlpackage pour ANE/M5.

Pipeline cible :
  1. YOLO11n-pose (ultralytics) — detection + pose 17 kp COCO en
     un seul modele top-down "tout-en-un". C'est notre baseline
     prefere : install simple, export CoreML natif via ultralytics,
     fonctionne sur ANE en INT8/FP16.
  2. (Optionnel) RTMPose-m via mmpose — pose top-down plus precise,
     necessite des bboxes en entree (paire avec un detecteur). Skip
     si mmpose n'est pas installe.
  3. (Optionnel) DWPose-m via mmpose — 133 kp body+face+hands, le
     plus complet. Souvent difficile a exporter en CoreML (operateurs
     custom). Si l'export echoue, on retombe sur YOLO11n-pose seul.

Usage :
    uv run python -m data_only_viz.scripts.convert_coreml
    uv run python -m data_only_viz.scripts.convert_coreml --force

Sortie :
    ~/.cache/av-live-coreml/yolo11n-pose.mlpackage
    ~/.cache/av-live-coreml/rtmpose-m.mlpackage     (si possible)
    ~/.cache/av-live-coreml/dwpose-m.mlpackage      (si possible)
"""
from __future__ import annotations

import argparse
import logging
import shutil
import subprocess
import sys
from pathlib import Path

LOG = logging.getLogger("convert_coreml")

CACHE_DIR = Path.home() / ".cache" / "av-live-coreml"
YOLO_NAME = "yolo11n-pose"
YOLO_MLPACKAGE = CACHE_DIR / f"{YOLO_NAME}.mlpackage"


def _du_mb(path: Path) -> float:
    """Taille (MB) d'un dossier ou d'un fichier."""
    if not path.exists():
        return 0.0
    if path.is_file():
        return path.stat().st_size / (1024 * 1024)
    total = 0
    for p in path.rglob("*"):
        if p.is_file():
            total += p.stat().st_size
    return total / (1024 * 1024)


# ---------------------------------------------------------------------------
# 1. YOLO11n-pose : export tout-en-un via ultralytics
# ---------------------------------------------------------------------------
def convert_yolo11n_pose(force: bool = False) -> Path | None:
    """Telecharge YOLO11n-pose .pt et l'exporte en CoreML .mlpackage."""
    if YOLO_MLPACKAGE.exists() and not force:
        LOG.info("[yolo11n-pose] deja present : %s (%.1f MB)",
                 YOLO_MLPACKAGE, _du_mb(YOLO_MLPACKAGE))
        return YOLO_MLPACKAGE
    try:
        from ultralytics import YOLO
    except ImportError:
        LOG.error("[yolo11n-pose] ultralytics manquant — "
                  "uv pip install ultralytics coremltools")
        return None

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    LOG.info("[yolo11n-pose] telechargement du checkpoint .pt ...")
    # ultralytics resout 'yolo11n-pose.pt' automatiquement depuis ses
    # assets GitHub. Le fichier atterit dans CWD ; on chdir dans cache.
    cwd_before = Path.cwd()
    try:
        import os
        os.chdir(CACHE_DIR)
        model = YOLO(f"{YOLO_NAME}.pt")
        LOG.info("[yolo11n-pose] export CoreML (ANE/FP16) ...")
        # nms=True : le modele inclut deja le NMS, simplifie le post-process
        # int8=False : on garde FP16, plus sur pour la pose (precision sub-pix)
        out = model.export(format="coreml", nms=True, half=True, imgsz=640)
        out_path = Path(out)
        # ultralytics nomme le fichier 'yolo11n-pose.mlpackage'
        if out_path.exists() and out_path != YOLO_MLPACKAGE:
            if YOLO_MLPACKAGE.exists():
                shutil.rmtree(YOLO_MLPACKAGE)
            shutil.move(str(out_path), str(YOLO_MLPACKAGE))
        LOG.info("[yolo11n-pose] export OK : %s (%.1f MB)",
                 YOLO_MLPACKAGE, _du_mb(YOLO_MLPACKAGE))
        return YOLO_MLPACKAGE
    except Exception as e:  # noqa: BLE001
        LOG.error("[yolo11n-pose] export echoue : %s", e)
        return None
    finally:
        import os
        os.chdir(cwd_before)


# ---------------------------------------------------------------------------
# 2. RTMPose-m (top-down, 17 kp) — via mmpose si dispo
# ---------------------------------------------------------------------------
def convert_rtmpose_m(force: bool = False) -> Path | None:
    """Stub : mmpose n'a pas d'export CoreML natif. Skip pour l'instant.

    NOTE : la voie pratique serait de passer par ONNX puis coremltools.
    On laisse le scaffold ici mais on ne tente pas la conversion par defaut
    car la chaine PyTorch -> ONNX -> CoreML pour RTMPose demande des patches
    sur les ops Argmax + heatmap decoding.
    """
    out = CACHE_DIR / "rtmpose-m.mlpackage"
    if out.exists() and not force:
        LOG.info("[rtmpose-m] deja present : %s", out)
        return out
    LOG.info("[rtmpose-m] skip (export ONNX->CoreML non implemente — "
             "voir https://github.com/open-mmlab/mmdeploy)")
    return None


# ---------------------------------------------------------------------------
# 3. DWPose-m (133 kp body+face+hands)
# ---------------------------------------------------------------------------
def convert_dwpose_m(force: bool = False) -> Path | None:
    """Stub : DWPose utilise les memes ops que RTMPose + un distillation
    head. Conversion CoreML tres flaky en pratique. Skip et fallback YOLO.
    """
    out = CACHE_DIR / "dwpose-m.mlpackage"
    if out.exists() and not force:
        LOG.info("[dwpose-m] deja present : %s", out)
        return out
    LOG.info("[dwpose-m] skip (export instable — fallback YOLO11n-pose)")
    return None


# ---------------------------------------------------------------------------
# Rapport final
# ---------------------------------------------------------------------------
def report(models: dict[str, Path | None]) -> None:
    print()
    print("=" * 68)
    print(" CoreML pose models — rapport")
    print("=" * 68)
    print(f" Cache dir : {CACHE_DIR}")
    print()
    for name, p in models.items():
        if p is None or not p.exists():
            print(f"  [-] {name:20s}  ABSENT")
            continue
        size_mb = _du_mb(p)
        print(f"  [+] {name:20s}  {size_mb:6.1f} MB  {p.name}")
    print()
    print(" I/O attendu YOLO11n-pose CoreML :")
    print("   input : image 640x640 BGR (pixel buffer accepte via Vision)")
    print("   output: var-shape 'output0' (1, N, 56) = [box(4)+conf(1)+kp(17*3)]")
    print("   ou 'var_xxx' tenseur post-NMS (depend de la version ultralytics)")
    print()
    print(" Pour ANE compatibility : verifier dans Xcode Quick Look")
    print("   - ouvrir le .mlpackage")
    print("   - onglet Performance → 'Compute units: Neural Engine'")
    print("   - latency cible M5 : <8 ms par frame")
    print()


def main() -> int:
    parser = argparse.ArgumentParser(prog="convert_coreml")
    parser.add_argument("--force", action="store_true",
                        help="re-export meme si .mlpackage deja present")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s — %(message)s",
        datefmt="%H:%M:%S",
    )

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    LOG.info("cache dir : %s", CACHE_DIR)

    results = {
        "yolo11n-pose": convert_yolo11n_pose(force=args.force),
        "rtmpose-m":    convert_rtmpose_m(force=args.force),
        "dwpose-m":     convert_dwpose_m(force=args.force),
    }
    report(results)
    # Exit code : 0 si au moins YOLO11n-pose est dispo (cas nominal).
    return 0 if results["yolo11n-pose"] is not None else 1


if __name__ == "__main__":
    sys.exit(main())
