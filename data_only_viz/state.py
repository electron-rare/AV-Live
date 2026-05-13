"""Thread-safe state container for the Metal visualizer.

Le listener OSC ecrit ; le renderer Metal lit a 60 fps. Tous les acces
sont proteges par un Lock — la contention est negligeable (lectures
courtes, ecritures rares).
"""
from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field

import numpy as np


@dataclass
class PoseKp:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0   # profondeur (mediapipe world_landmarks, metres ; 0 par defaut)
    c: float = 0.0


@dataclass
class SMPLXPerson:
    """Resultats Multi-HMR pour une personne : params SMPL-X + vertices
    decodes en metres. Vertices en repere camera (z > 0 devant)."""
    pid: int = -1
    vertices_3d: np.ndarray = field(default_factory=lambda: np.empty((0, 3), dtype=np.float32))  # (10475, 3)
    translation: np.ndarray = field(default_factory=lambda: np.zeros(3, dtype=np.float32))       # (3,)
    confidence: float = 0.0
    betas: np.ndarray = field(default_factory=lambda: np.zeros(10, dtype=np.float32))            # (10,)
    expression: np.ndarray = field(default_factory=lambda: np.zeros(10, dtype=np.float32))       # (10,)


@dataclass
class NLFPerson:
    """Resultats NLF pour une personne : vertices 3D SMPL (6890) en metres,
    coordonnees camera (z > 0 devant). Le path nonparametrique fournit les
    vertices directement sans decodage SMPL explicite."""
    pid: int = -1
    vertices_3d: tuple = field(default_factory=tuple)   # ((x,y,z),) x 6890
    joints_3d: tuple = field(default_factory=tuple)      # ((x,y,z),) x 24 (SMPL)
    translation: tuple = (0.0, 0.0, 0.0)
    confidence: float = 0.0


@dataclass
class State:
    # Audio sync
    bpm: float = 120.0
    beat: int = 0
    rms: float = 0.0
    amps: dict[str, float] = field(default_factory=dict)
    album: str = ""

    # Data feeds
    bridge_alive: bool = False
    last_heartbeat: float = 0.0
    swpc_kp: float = 2.0
    swpc_flare_norm: float = 0.0
    swpc_wind_speed: float = 400.0
    swpc_bz: float = 0.0
    netz_dev: float = 0.0
    lightning_rate_min: float = 0.0
    last_lightning: tuple[float, float, float] = (0.0, 0.0, 999.0)  # lat, lon, age
    last_lightning_t: float = 0.0
    usgs_last_mag: float = 0.0
    usgs_last_mag_t: float = 0.0
    aviation_count: int = 0
    social_rate: float = 0.0
    pose_count: int = 0
    pose_kp: list[PoseKp] = field(default_factory=lambda: [PoseKp() for _ in range(17)])  # YOLO COCO legacy
    pose_last_t: float = 0.0
    # MediaPipe : compat single-person (holistic legacy, fallback)
    body_kp: list[PoseKp] = field(
        default_factory=lambda: [PoseKp() for _ in range(33)])
    face_kp: list[PoseKp] = field(
        default_factory=lambda: [PoseKp() for _ in range(478)])
    left_hand_kp: list[PoseKp] = field(
        default_factory=lambda: [PoseKp() for _ in range(21)])
    right_hand_kp: list[PoseKp] = field(
        default_factory=lambda: [PoseKp() for _ in range(21)])
    body_present: bool = False
    face_present: bool = False
    hands_present: bool = False

    # MediaPipe multi-personne : 3 workers paralleles, jusqu'a 4 sujets.
    # Chaque entree = liste de landmarks d'UNE personne. Les listes sont
    # independantes (pas d'association inter-personne — assemblees par
    # proximite si besoin dans le renderer).
    persons_body:  list[list[PoseKp]] = field(default_factory=list)
    persons_face:  list[list[PoseKp]] = field(default_factory=list)
    persons_hands: list[list[PoseKp]] = field(default_factory=list)
    # IDs persistants entre frames (ByteTrack-like via Hungarian IoU).
    # Couleur du skeleton dans le shader Metal = ID % palette_size.
    persons_body_ids:  list[int] = field(default_factory=list)
    persons_face_ids:  list[int] = field(default_factory=list)
    persons_hands_ids: list[int] = field(default_factory=list)

    # NLF (SMPL 6890 verts x N personnes, path nonparametrique)
    persons_nlf: list = field(default_factory=list)   # list[NLFPerson]
    nlf_last_t: float = 0.0

    # Multi-HMR (SMPL-X 10475 verts x N personnes)
    persons_smplx: list = field(default_factory=list)   # list[SMPLXPerson]
    smplx_last_t: float = 0.0

    # Renderer
    width: int = 1280
    height: int = 720
    start_t: float = field(default_factory=time.monotonic)
    # Mode visuel 0..7 (cf scene.metal::bg_fragment dispatcher)
    viz_mode: int = 0
    viz_mode_names: tuple = (
        "storm", "tunnel", "plasma", "kaleido",
        "voronoi", "metaballs", "starfield", "bars",
        "hands3d",   # mode 8 : voyage 3D pilote par les mains
    )
    # Preset open-data actif (USGS, Blitz, Wind, Kp/Bz, X-ray, OpenSky,
    # Bsky, Pose, Cosmos) — affiche dans le HUD.
    active_preset: str = ""
    # Scene audio active (envoyee par le clavier qsdfghjklm).
    active_scene: str = ""
    # Derniere frame webcam au format JPEG bytes (pour NSImageView overlay).
    # Le pose worker la met a jour ; le HUD timer lit et l'affiche.
    last_webcam_jpeg: bytes | None = None

    _lock: threading.RLock = field(default_factory=threading.RLock, repr=False)

    def elapsed(self) -> float:
        return time.monotonic() - self.start_t

    def lock(self):
        return self._lock

    def pose_alive(self, timeout: float = 1.5) -> bool:
        return (time.monotonic() - self.pose_last_t) < timeout


# Mappings clavier AZERTY pour les 3 dimensions :
#   azertyuiop = video (viz mode, 8 + 2 libres)
#   qsdfghjklm = audio (scene SC)
#   wxcvbn     = data source (focus HUD + signal a SC)

KEYMAP_VIDEO: tuple[tuple[str, str], ...] = (
    ("a", "storm"),
    ("z", "tunnel"),
    ("e", "plasma"),
    ("r", "kaleido"),
    ("t", "voronoi"),
    ("y", "metaballs"),
    ("u", "starfield"),
    ("i", "bars"),
    ("o", "hands3d"),   # voyage 3D pilote par les mains MediaPipe
    # p : libre
)

KEYMAP_AUDIO: tuple[tuple[str, str], ...] = (
    ("q", "cavity"),
    ("s", "geo"),
    ("d", "body"),
    ("f", "weather"),
    ("g", "flight"),
    ("h", "pulse"),
    ("j", "quiet"),
    ("k", "all"),
    ("l", "full"),
    ("m", "stop"),
)

# Bundle preset = (source, scene SC, viz mode Metal).
# Selectionner une source applique les 3 dimensions d'un coup : focus HUD,
# scene audio dediee, mode visuel correspondant.
SourceBundle = tuple[str, str, str, str]  # (key, source, scene, viz)

KEYMAP_SOURCE: tuple[SourceBundle, ...] = (
    ("w", "USGS",    "geo",     "voronoi"),
    ("x", "Blitz",   "pulse",   "storm"),
    ("c", "SWPC",    "weather", "tunnel"),
    ("v", "OpenSky", "flight",  "kaleido"),
    ("b", "Bsky",    "pulse",   "bars"),
    ("n", "Pose",    "body",    "metaballs"),
)

# 10 sources distinctes via touches 0-9 (granularite fine sur SWPC).
KEYMAP_SOURCE_NUM: tuple[SourceBundle, ...] = (
    ("0", "Cosmos",  "full",    "starfield"),  # toutes sources
    ("1", "USGS",    "geo",     "voronoi"),    # earthquakes
    ("2", "Blitz",   "pulse",   "storm"),      # lightning
    ("3", "Wind",    "weather", "tunnel"),     # SWPC solar wind speed
    ("4", "Kp/Bz",   "geo",     "plasma"),     # SWPC geomagnetic
    ("5", "X-ray",   "weather", "bars"),       # SWPC solar flare
    ("6", "OpenSky", "flight",  "kaleido"),    # aviation
    ("7", "Bsky",    "pulse",   "bars"),       # social firehose
    ("8", "Pose",    "body",    "metaballs"),  # body YOLO
    ("9", "Grid",    "weather", "plasma"),     # netzfrequenz (futur)
)
