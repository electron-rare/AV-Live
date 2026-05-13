"""Tracker multi-personne — assignation Hungarian (linear_sum_assignment)
sur cost = 1 - IoU + 0.5 * center_distance.

But : maintenir des IDs persistants entre frames pour que la palette
de couleur ne saute pas et que les filtres One Euro accumulent
correctement leur etat. Style ByteTrack simplifie : pas de Kalman, pas
de second pass low-conf, juste assignation directe.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

try:
    from scipy.optimize import linear_sum_assignment
    _HAVE_SCIPY = True
except ImportError:
    _HAVE_SCIPY = False


@dataclass
class _Track:
    track_id: int
    bbox: tuple[float, float, float, float]   # xmin, ymin, xmax, ymax (normalises)
    miss_count: int = 0
    last_seen: int = 0


def _bbox_from_kps(kps) -> tuple[float, float, float, float]:
    """Bounding box minimal entourant les keypoints visibles (c > 0.2)."""
    xs = [k.x for k in kps if k.c > 0.2]
    ys = [k.y for k in kps if k.c > 0.2]
    if not xs:
        return (0.0, 0.0, 0.0, 0.0)
    return (min(xs), min(ys), max(xs), max(ys))


def _iou(a: tuple, b: tuple) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    inter_x1 = max(ax1, bx1); inter_y1 = max(ay1, by1)
    inter_x2 = min(ax2, bx2); inter_y2 = min(ay2, by2)
    iw = max(0.0, inter_x2 - inter_x1); ih = max(0.0, inter_y2 - inter_y1)
    inter = iw * ih
    area_a = max(0.0, (ax2 - ax1) * (ay2 - ay1))
    area_b = max(0.0, (bx2 - bx1) * (by2 - by1))
    union = area_a + area_b - inter
    return inter / max(1e-6, union)


def _center_dist(a: tuple, b: tuple) -> float:
    ax = (a[0] + a[2]) * 0.5; ay = (a[1] + a[3]) * 0.5
    bx = (b[0] + b[2]) * 0.5; by = (b[1] + b[3]) * 0.5
    return math.hypot(ax - bx, ay - by)


class IoUTracker:
    """Tracker multi-personne avec assignation Hungarian et survie limitee."""

    def __init__(self, iou_threshold: float = 0.25,
                 max_miss: int = 8) -> None:
        self.iou_threshold = iou_threshold
        self.max_miss = max_miss
        self._tracks: list[_Track] = []
        self._next_id = 0
        self._frame_idx = 0

    def update(self, detections_kps: list[list]) -> list[int]:
        """Assigne un track_id stable a chaque detection. Retourne une
        liste d'IDs de meme longueur que `detections_kps`.

        detections_kps : list[list[PoseKp]] — un sous-tableau par sujet.
        """
        self._frame_idx += 1
        det_bboxes = [_bbox_from_kps(kps) for kps in detections_kps]
        n_det = len(det_bboxes)
        n_trk = len(self._tracks)
        ids: list[int] = [-1] * n_det

        if n_det == 0:
            # Tous les tracks sont missed cette frame
            kept = []
            for t in self._tracks:
                t.miss_count += 1
                if t.miss_count <= self.max_miss:
                    kept.append(t)
            self._tracks = kept
            return ids

        if n_trk == 0:
            for i in range(n_det):
                self._tracks.append(_Track(
                    track_id=self._next_id, bbox=det_bboxes[i],
                    last_seen=self._frame_idx))
                ids[i] = self._next_id
                self._next_id += 1
            return ids

        # Cost matrix : 1 - IoU + 0.5 * center_dist (pour briser les egalites)
        cost = [[1.0] * n_trk for _ in range(n_det)]
        for i, db in enumerate(det_bboxes):
            for j, t in enumerate(self._tracks):
                iou = _iou(db, t.bbox)
                cd = _center_dist(db, t.bbox)
                cost[i][j] = (1.0 - iou) + 0.5 * cd

        # Hungarian (scipy) ou greedy fallback
        pairs = []
        if _HAVE_SCIPY:
            try:
                import numpy as np
                C = np.array(cost, dtype=float)
                rr, cc = linear_sum_assignment(C)
                pairs = list(zip(rr.tolist(), cc.tolist()))
            except Exception:
                pairs = _greedy_assign(cost)
        else:
            pairs = _greedy_assign(cost)

        used_dets: set[int] = set()
        used_trks: set[int] = set()
        for i, j in pairs:
            # rejette si IoU < seuil
            iou_ij = _iou(det_bboxes[i], self._tracks[j].bbox)
            if iou_ij < self.iou_threshold:
                continue
            self._tracks[j].bbox = det_bboxes[i]
            self._tracks[j].miss_count = 0
            self._tracks[j].last_seen = self._frame_idx
            ids[i] = self._tracks[j].track_id
            used_dets.add(i); used_trks.add(j)

        # Nouvelles detections non matchees -> nouveaux tracks
        for i in range(n_det):
            if i in used_dets:
                continue
            self._tracks.append(_Track(
                track_id=self._next_id, bbox=det_bboxes[i],
                last_seen=self._frame_idx))
            ids[i] = self._next_id
            self._next_id += 1

        # Tracks non matches -> incrementer miss_count, drop si trop vieux
        kept: list[_Track] = []
        for j, t in enumerate(self._tracks):
            if j not in used_trks and t.last_seen != self._frame_idx:
                t.miss_count += 1
            if t.miss_count <= self.max_miss:
                kept.append(t)
        self._tracks = kept

        return ids

    def all_ids(self) -> set[int]:
        return {t.track_id for t in self._tracks}


def _greedy_assign(cost: list[list[float]]) -> list[tuple[int, int]]:
    """Fallback Hungarian si scipy absent : greedy par cout croissant."""
    triples = [(c, i, j) for i, row in enumerate(cost)
               for j, c in enumerate(row)]
    triples.sort(key=lambda t: t[0])
    used_i, used_j, pairs = set(), set(), []
    for c, i, j in triples:
        if i in used_i or j in used_j:
            continue
        used_i.add(i); used_j.add(j)
        pairs.append((i, j))
    return pairs
