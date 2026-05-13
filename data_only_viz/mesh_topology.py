"""Topologie de triangles pour le rendu mesh face/main/corps.

Trois listes statiques d'indices :
  - FACE_TRIANGLES : visage Apple Vision (~76 landmarks, layout plat dans
    state.persons_face[i]). Generee dynamiquement via scipy.Delaunay au
    premier frame (cache global). Voir build_face_triangles_dynamic().
  - HAND_TRIANGLES : 21 landmarks main (paume fan + strips doigts).
  - BODY_TRIANGLES : 33 landmarks MediaPipe POSE_LANDMARKS (tronc, bras,
    jambes, tete) ; reutilise tel quel pour Apple Vision body 17 kp
    mappes sur les memes 33 indices.

Format : list[tuple[int, int, int]] (a, b, c) indices dans la liste de
keypoints correspondante.

Convention Apple Vision FaceLandmarks2D — offsets par region tels
qu'ecrits par apple_vision_pose._parse_face_observation() :
  contour      :  0..16  (17 pts, faceContour)
  left_eye     : 17..24  (8 pts)
  right_eye    : 25..32  (8 pts)
  left_brow    : 33..38  (6 pts, leftEyebrow)
  right_brow   : 39..44  (6 pts, rightEyebrow)
  outer_lips   : 45..58  (14 pts, outerLips)
  inner_lips   : 59..68  (10 pts, innerLips)
  nose         : 69..74  (6 pts, nose)
  median       : 75..80  (6 pts, medianLine — optionnel)
  pupils       : 81..82  (2 pts, leftPupil rightPupil)

Le total exact varie selon macOS ; on cale 76 indices visibles
generalement, le reste est ignore. La triangulation dynamique
Delaunay s'adapte automatiquement.
"""
from __future__ import annotations

from typing import Sequence

FACE_OFFSETS: dict[str, tuple[int, int]] = {
    "contour":    (0, 17),
    "left_eye":   (17, 25),
    "right_eye":  (25, 33),
    "left_brow":  (33, 39),
    "right_brow": (39, 45),
    "outer_lips": (45, 59),
    "inner_lips": (59, 69),
    "nose":       (69, 75),
    "median":     (75, 81),
    "pupils":     (81, 83),
}
FACE_MAX_LANDMARKS = 83


# ---------------------------------------------------------------------------
# HAND_TRIANGLES — 21 landmarks (standard MediaPipe / Apple Vision)
# ---------------------------------------------------------------------------
# Indices : 0=wrist, 1..4=thumb, 5..8=index, 9..12=middle, 13..16=ring,
#           17..20=little. Chaque doigt : MCP, PIP, DIP, TIP.
HAND_TRIANGLES: list[tuple[int, int, int]] = [
    # Paume : fan depuis le poignet vers les bases des doigts
    (0, 1, 5),
    (0, 5, 9),
    (0, 9, 13),
    (0, 13, 17),
    # Pouce — strip (segments 1-2-3-4)
    (1, 2, 5),    # base pouce -> index
    (2, 3, 5),
    # Index : segments 5->6->7->8 (strip avec voisin middle pour epaisseur)
    (5, 6, 9),
    (6, 7, 9),
    (7, 8, 9),
    # Middle : 9->10->11->12 (strip avec ring)
    (9, 10, 13),
    (10, 11, 13),
    (11, 12, 13),
    # Ring : 13->14->15->16 (strip avec little)
    (13, 14, 17),
    (14, 15, 17),
    (15, 16, 17),
    # Little : 17->18->19->20 — degenere en triangle avec le poignet
    (17, 18, 0),
    (18, 19, 17),
    (19, 20, 17),
]


# ---------------------------------------------------------------------------
# BODY_TRIANGLES — 33 landmarks MediaPipe POSE_LANDMARKS
# ---------------------------------------------------------------------------
# Indices cles (MediaPipe) :
#   0  nose
#   7  left_ear           8  right_ear
#   11 left_shoulder      12 right_shoulder
#   13 left_elbow         14 right_elbow
#   15 left_wrist         16 right_wrist
#   23 left_hip           24 right_hip
#   25 left_knee          26 right_knee
#   27 left_ankle         28 right_ankle
BODY_TRIANGLES: list[tuple[int, int, int]] = [
    # Cou + tete : nez + epaules
    (0, 11, 12),
    # Tronc QUAD divise en 4 triangles (mesh plus dense)
    (11, 12, 24),
    (11, 24, 23),
    (11, 12, 23),
    (12, 23, 24),
    # Bras gauche : triangles avant + face inverse (double face = visible cote-cote)
    (11, 13, 15),
    (11, 15, 13),
    # Bras droit
    (12, 14, 16),
    (12, 16, 14),
    # Jambe gauche : hip-knee-ankle + inverse
    (23, 25, 27),
    (23, 27, 25),
    # Jambe droite
    (24, 26, 28),
    (24, 28, 26),
    # Mailler le tronc avec les bras/jambes pour relier
    (11, 23, 13),    # epaule-hanche-coude G
    (12, 24, 14),    # epaule-hanche-coude D
    (23, 13, 25),    # cuisse-haut au coude (croise)
    (24, 14, 26),
]


# ---------------------------------------------------------------------------
# FACE_TRIANGLES — triangulation Delaunay dynamique cachee
# ---------------------------------------------------------------------------
# On ne hardcode pas car le nombre de landmarks Apple Vision face varie
# entre versions macOS. Au premier frame, on calcule la triangulation 2D
# Delaunay sur la liste plate des landmarks valides, puis on cache la
# liste d'indices tant que la cardinalite ne change pas.

_FACE_TRI_CACHE: dict[int, list[tuple[int, int, int]]] = {}


def build_face_triangles_dynamic(
    points_xy: Sequence[tuple[float, float]],
) -> list[tuple[int, int, int]]:
    """Triangulation Delaunay 2D des landmarks face. Cachee par cardinalite.

    points_xy : liste plate de (x, y) normalises (longueur = N landmarks).
    Retourne : list[(i, j, k)] indices dans la liste d'entree.

    Si scipy indisponible ou triangulation echoue, retourne [].
    """
    n = len(points_xy)
    if n < 4:
        return []
    if n in _FACE_TRI_CACHE:
        return _FACE_TRI_CACHE[n]
    try:
        import numpy as np
        from scipy.spatial import Delaunay
        pts = np.asarray(points_xy, dtype=np.float32)
        # Filtre les points invalides (0,0) si presents
        valid = (pts[:, 0] > 0.0) | (pts[:, 1] > 0.0)
        if valid.sum() < 4:
            return []
        # On triangule sur tous les points (l'indice reste valide) mais on
        # filtre les triangles qui touchent un point invalide en aval.
        tri = Delaunay(pts).simplices
        triangles = [tuple(int(v) for v in t) for t in tri]
    except Exception:
        triangles = []
    _FACE_TRI_CACHE[n] = triangles
    return triangles


# Triangulation par defaut : conservee comme fallback si Delaunay echoue.
# Quelques triangles symboliques sur le visage minimum (contour + nez +
# bouche) qui couvrent les regions critiques.
FACE_TRIANGLES: list[tuple[int, int, int]] = [
    # Fan partiel sur le contour (8 triangles : 0..16 -> centre approx = 71 nose)
    (0, 1, 71), (1, 2, 71), (2, 3, 71), (3, 4, 71),
    (4, 5, 71), (5, 6, 71), (6, 7, 71), (7, 8, 71),
    (8, 9, 71), (9, 10, 71), (10, 11, 71), (11, 12, 71),
    (12, 13, 71), (13, 14, 71), (14, 15, 71), (15, 16, 71),
    # outerLips fan (45..58 -> centre 60)
    (45, 46, 60), (46, 47, 60), (47, 48, 60), (48, 49, 60),
    (49, 50, 60), (50, 51, 60), (51, 52, 60), (52, 53, 60),
    (53, 54, 60), (54, 55, 60), (55, 56, 60), (56, 57, 60),
    (57, 58, 60),
    # innerLips fan (59..68 -> centre 64)
    (59, 60, 64), (60, 61, 64), (61, 62, 64), (62, 63, 64),
    (65, 66, 64), (66, 67, 64), (67, 68, 64),
]


__all__ = [
    "FACE_OFFSETS",
    "FACE_MAX_LANDMARKS",
    "FACE_TRIANGLES",
    "HAND_TRIANGLES",
    "BODY_TRIANGLES",
    "build_face_triangles_dynamic",
]
