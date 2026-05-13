"""Extrait la liste des 20908 triangles du modele SMPL-X NEUTRAL et
les serialise en binaire little-endian (int32) pour consommation par
l'app Swift RealityKit.

Necessite SMPLX_NEUTRAL.npz dans ~/.cache/av-live-multihmr/models/smplx/
(inscription manuelle sur smpl-x.is.tue.mpg.de — licence MPII).
"""
import struct
import sys
from pathlib import Path

import numpy as np

CACHE = Path.home() / ".cache" / "av-live-multihmr"
SMPLX = CACHE / "models" / "smplx" / "SMPLX_NEUTRAL.npz"
OUT = (Path(__file__).parent.parent.parent
       / "launcher" / "AV-Live-Body" / "Resources" / "smplx_faces.bin")

EXPECTED_FACES = 20908


def main() -> int:
    if not SMPLX.exists():
        print(f"SMPL-X manquant : {SMPLX}")
        print("Voir data_only_viz/scripts/setup_multihmr.sh pour la procedure.")
        return 1
    npz = np.load(SMPLX)
    faces = npz["f"]
    print(f"SMPL-X faces : {faces.shape} dtype={faces.dtype}")
    assert faces.shape == (EXPECTED_FACES, 3), (
        f"shape attendu ({EXPECTED_FACES}, 3), got {faces.shape}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "wb") as f:
        for tri in faces:
            for idx in tri:
                f.write(struct.pack("<i", int(idx)))
    size = OUT.stat().st_size
    expected = EXPECTED_FACES * 3 * 4
    print(f"Wrote {size} bytes to {OUT} (expected {expected})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
