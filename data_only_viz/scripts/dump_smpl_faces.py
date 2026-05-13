"""Extrait les 13776 triangles SMPL (6890 vertices) et les serialise en
binaire little-endian (uint32) pour consommation par l'app Swift RealityKit.

Strategie : tente d'abord d'extraire depuis nlf_data_files.zip si present,
sinon charge le modele TorchScript et tente d'acceder aux faces embarquees,
sinon telecharge le fichier SMPL faces standard depuis un repo open-source.
"""
import struct
import sys
from pathlib import Path

import numpy as np

CACHE = Path.home() / ".cache" / "av-live-nlf"
OUT = (Path(__file__).parent.parent.parent
       / "launcher" / "AV-Live-Body" / "Resources" / "smpl_faces.bin")

# SMPL standard : 13776 triangles, 6890 vertices
EXPECTED_FACES = 13776
EXPECTED_VERTS = 6890


def try_from_data_files() -> np.ndarray | None:
    """Tente d'extraire depuis nlf_data_files.zip."""
    import zipfile
    zf = CACHE / "nlf_data_files.zip"
    if not zf.exists():
        return None
    with zipfile.ZipFile(zf) as z:
        for name in z.namelist():
            if "smpl" in name.lower() and name.endswith(".npy"):
                with z.open(name) as f:
                    arr = np.load(f)
                    if arr.shape == (EXPECTED_FACES, 3):
                        return arr
    return None


def try_from_torchscript() -> np.ndarray | None:
    """Charge le checkpoint et cherche les faces SMPL."""
    try:
        import torch
        import torchvision  # noqa: F401 - register torchvision::nms op for TorchScript
        ckpt = CACHE / "nlf_l_multi.torchscript"
        if not ckpt.exists():
            return None
        model = torch.jit.load(str(ckpt), map_location="cpu")
        for name, buf in model.named_buffers():
            if buf.shape == (EXPECTED_FACES, 3):
                print(f"Found faces in buffer '{name}'")
                return buf.numpy().astype(np.int32)
        for attr in dir(model):
            try:
                val = getattr(model, attr)
                if hasattr(val, 'shape') and val.shape == (EXPECTED_FACES, 3):
                    print(f"Found faces in attr '{attr}'")
                    return val.numpy().astype(np.int32) if hasattr(val, 'numpy') else np.array(val, dtype=np.int32)
            except Exception:
                continue
    except Exception as e:
        print(f"TorchScript extraction failed: {e}")
    return None


def download_smpl_faces() -> np.ndarray:
    """Telecharge les faces SMPL standard depuis un repo open-source.

    Strategie multi-URL : essaie plusieurs sources, la premiere qui repond
    avec le bon shape (13776, 3) gagne. Aucun de ces fichiers ne contient
    de poids SMPL proprietaires, juste la topologie publique du mesh.
    """
    import urllib.request
    import tempfile

    candidates = [
        # HMR (akanazawa) ships the standard SMPL face topology as a public .npy
        # — verified (13776, 3) uint32, max index 6889.
        "https://github.com/akanazawa/hmr/raw/master/src/tf_smpl/smpl_faces.npy",
    ]
    last_err = None
    for url in candidates:
        print(f"Downloading SMPL faces from {url}...")
        try:
            with tempfile.NamedTemporaryFile(suffix=".npy", delete=False) as tmp:
                urllib.request.urlretrieve(url, tmp.name)
                faces = np.load(tmp.name)
            if faces.shape == (EXPECTED_FACES, 3):
                print(f"  -> OK: {faces.shape} {faces.dtype}")
                return faces.astype(np.int32)
            print(f"  -> wrong shape {faces.shape}, skip")
        except Exception as e:
            print(f"  -> failed: {e}")
            last_err = e
    raise RuntimeError(f"All SMPL face download candidates failed: {last_err}")


def main():
    faces = try_from_data_files()
    if faces is None:
        print("nlf_data_files.zip absent ou faces non trouvees, essai TorchScript...")
        faces = try_from_torchscript()
    if faces is None:
        print("TorchScript: faces non trouvees dans les buffers, download fallback...")
        faces = download_smpl_faces()

    print(f"SMPL faces: {faces.shape} dtype={faces.dtype}")
    assert faces.shape == (EXPECTED_FACES, 3), f"shape attendu ({EXPECTED_FACES}, 3), got {faces.shape}"
    assert faces.max() < EXPECTED_VERTS, f"index max {faces.max()} >= {EXPECTED_VERTS}"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "wb") as f:
        for tri in faces:
            for idx in tri:
                f.write(struct.pack("<I", int(idx)))
    size = OUT.stat().st_size
    expected_size = EXPECTED_FACES * 3 * 4
    print(f"Wrote {size} bytes to {OUT} (expected {expected_size})")
    assert size == expected_size


if __name__ == "__main__":
    main()
