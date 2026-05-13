"""Renderer Metal natif via pyobjc.

Architecture :
  - MTKView         : NSView Metal-managee, callback drawInMTKView
  - MTLDevice       : GPU par defaut
  - MTLCommandQueue : queue de submission
  - 2 pipelines :
      bg_pipeline   : fullscreen tri + fbm fragment shader (1 draw call)
      skel_pipeline : lignes pour le squelette pose (max 16 segments)
  - Uniforms buffer 56 octets (14 floats) cf scene.metal::SceneUniforms

Le renderer ne possede PAS de state thread : il lit le State partage
sous lock a chaque frame (60 fps).
"""
from __future__ import annotations

import logging
import struct
import time
from pathlib import Path

import numpy as np

import objc
from Cocoa import NSObject, NSColor, NSMakeRect
from Metal import (
    MTLCreateSystemDefaultDevice,
    MTLCompileOptions,
    MTLPrimitiveTypeTriangle,
    MTLPrimitiveTypeLine,
    MTLRenderPipelineDescriptor,
    MTLResourceStorageModeShared,
    MTLVertexAttributeDescriptor,
    MTLVertexBufferLayoutDescriptor,
    MTLVertexDescriptor,
    MTLVertexFormatFloat,
    MTLVertexFormatFloat2,
    MTLVertexFormatFloat3,
    MTLVertexStepFunctionPerVertex,
)
# MTKViewDelegate est un @protocol Obj-C ; pas besoin d'import Python.
# pyobjc detecte automatiquement l'implementation par signature.
from MetalKit import MTKView  # noqa: F401  (utilise par d'autres modules)

from .mesh_topology import (
    BODY_TRIANGLES,
    FACE_TRIANGLES,
    HAND_TRIANGLES,
    build_face_triangles_dynamic,
)
from .state import State

LOG = logging.getLogger("renderer")

# Triangle primitive constant (Metal MTLPrimitiveType.triangle = 3)
MTL_PRIMITIVE_TRIANGLE = 3

# 17 keypoints COCO bones (16 paires) — legacy YOLO fallback
COCO_BONES: list[tuple[int, int]] = [
    (0, 1), (0, 2), (1, 3), (2, 4),
    (5, 6), (5, 7), (7, 9), (6, 8), (8, 10),
    (5, 11), (6, 12), (11, 12),
    (11, 13), (13, 15), (12, 14), (14, 16),
]


def _mediapipe_bones():
    """Charge les connexions MediaPipe (body+face+hands) au runtime.
    Retourne 4 listes : (body_bones, face_bones, lhand_bones, rhand_bones)
    avec chaque bone = (idx_a, idx_b).
    Retourne None si mediapipe absent (fallback COCO)."""
    try:
        from mediapipe.tasks.python.vision import (
            FaceLandmarksConnections as F,
            HandLandmarksConnections as H,
            PoseLandmarksConnections as P,
        )
    except ImportError:
        return None

    def to_pairs(cs):
        return [(c.start, c.end) for c in cs]

    # 35 body
    body = to_pairs(P.POSE_LANDMARKS)
    # Visage HAUTE DENSITE : tesselation complete (2556) + contours +
    # iris + nez. Donne ~2700 segments rien que pour le visage.
    face = (
        to_pairs(F.FACE_LANDMARKS_TESSELATION)   # 2556 segs (mesh dense)
        + to_pairs(F.FACE_LANDMARKS_FACE_OVAL)
        + to_pairs(F.FACE_LANDMARKS_LIPS)
        + to_pairs(F.FACE_LANDMARKS_LEFT_EYE)
        + to_pairs(F.FACE_LANDMARKS_RIGHT_EYE)
        + to_pairs(F.FACE_LANDMARKS_LEFT_EYEBROW)
        + to_pairs(F.FACE_LANDMARKS_RIGHT_EYEBROW)
        + to_pairs(F.FACE_LANDMARKS_LEFT_IRIS)
        + to_pairs(F.FACE_LANDMARKS_RIGHT_IRIS)
        + to_pairs(F.FACE_LANDMARKS_NOSE)
    )
    # 21 mains (chacune)
    hand = to_pairs(H.HAND_CONNECTIONS)
    return body, face, hand, hand   # left+right partagent les connexions


# Capacite max du vertex buffer skeleton.
# 16384 segs * 2 verts * 5 floats (xyz + conf + pid) * 4 bytes = 640 KB
# Couvre 4 personnes : 4×35 body + 4×2700 face + 8×21 hand = ~11000 segs.
SKEL_MAX_SEGS = 16384
SKEL_VERT_FLOATS = 5    # x, y, z, conf, person_id

# Mesh : ~8192 triangles × 3 verts × 5 floats × 4 = 480 KB.
# Couvre 4 personnes : 4×~80 face + 4×~16 body + 8×~18 hand ≈ 600 triangles
# pour le hardcode, ou ~4×~150 face Delaunay = ~600 triangles. Marge large.
MESH_MAX_TRIS = 8192
MESH_VERT_FLOATS = 5    # identique au skel
MESH_MAX_VERTS = 10475  # SMPL-X is the larger family; SMPL (6890) fits inside

# struct SceneUniforms : 17 floats packs = 68 octets, padding a 80 (multiple
# de 16, regle Metal). On y stocke (time, rms, kp_norm, netz_dev,
# lightning_flash, flare, wind_norm, bz_norm, social_rate, pose_alive,
# pose_count, width, height, viz_mode, _pad0, _pad1).
UNIFORM_FLOATS = 20   # +4 floats : hand_l_x/y, hand_r_x/y
UNIFORM_SIZE = UNIFORM_FLOATS * 4   # 80 octets, aligne 16


class MetalRenderer(NSObject):
    """Delegate de MTKView, drive l'integralite du rendu."""

    def initWithState_(self, state: State):  # noqa: N802
        self = objc.super(MetalRenderer, self).init()
        if self is None:
            return None
        self._state = state
        self._device = MTLCreateSystemDefaultDevice()
        if self._device is None:
            raise RuntimeError("Metal non disponible sur ce systeme")
        LOG.info("device: %s", self._device.name())
        self._queue = self._device.newCommandQueue()
        self._uniforms_buf = self._device.newBufferWithLength_options_(
            UNIFORM_SIZE, MTLResourceStorageModeShared)
        # Skeleton : N segs × 2 verts × 5 floats (xyz + conf + pid)
        self._skel_buf = self._device.newBufferWithLength_options_(
            SKEL_MAX_SEGS * 2 * SKEL_VERT_FLOATS * 4, MTLResourceStorageModeShared)
        # Mesh buffer : triangles face/hand/body
        self._mesh_buf = self._device.newBufferWithLength_options_(
            MESH_MAX_TRIS * 3 * MESH_VERT_FLOATS * 4, MTLResourceStorageModeShared)
        self._mp_bones = _mediapipe_bones()  # None si pas dispo
        self._init_skel_cpu_buffer()
        self._init_mesh_cpu_buffer()
        self._build_pipelines()
        self._last_lightning_emit = 0.0
        return self

    # ---- Pipelines -------------------------------------------------
    def _build_pipelines(self):
        src_path = Path(__file__).parent / "shaders" / "scene.metal"
        source = src_path.read_text()
        opts = MTLCompileOptions.alloc().init()
        lib, err = self._device.newLibraryWithSource_options_error_(
            source, opts, None)
        if lib is None:
            raise RuntimeError(f"shader compile failed: {err}")
        self._lib = lib

        # --- Background pipeline (no vertex buffer) ---
        bg = MTLRenderPipelineDescriptor.alloc().init()
        bg.setVertexFunction_(lib.newFunctionWithName_("bg_vertex"))
        bg.setFragmentFunction_(lib.newFunctionWithName_("bg_fragment"))
        bg.colorAttachments().objectAtIndexedSubscript_(0).setPixelFormat_(80)  # BGRA8Unorm
        p, err = self._device.newRenderPipelineStateWithDescriptor_error_(bg, None)
        if p is None:
            raise RuntimeError(f"bg pipeline failed: {err}")
        self._bg_pipe = p

        # --- Skeleton pipeline (vertex buffer pos+conf) ---
        # Skeleton vertex layout : pos (float3) + conf (float) + pid (float)
        # Stride = 5 floats × 4 bytes = 20 bytes
        vd = MTLVertexDescriptor.vertexDescriptor()
        a0 = vd.attributes().objectAtIndexedSubscript_(0)
        a0.setFormat_(MTLVertexFormatFloat3); a0.setOffset_(0); a0.setBufferIndex_(0)
        a1 = vd.attributes().objectAtIndexedSubscript_(1)
        a1.setFormat_(MTLVertexFormatFloat); a1.setOffset_(12); a1.setBufferIndex_(0)
        a2 = vd.attributes().objectAtIndexedSubscript_(2)
        a2.setFormat_(MTLVertexFormatFloat); a2.setOffset_(16); a2.setBufferIndex_(0)
        ld = vd.layouts().objectAtIndexedSubscript_(0)
        ld.setStride_(20); ld.setStepFunction_(MTLVertexStepFunctionPerVertex)

        sk = MTLRenderPipelineDescriptor.alloc().init()
        sk.setVertexFunction_(lib.newFunctionWithName_("skel_vertex"))
        sk.setFragmentFunction_(lib.newFunctionWithName_("skel_fragment"))
        sk.setVertexDescriptor_(vd)
        ca = sk.colorAttachments().objectAtIndexedSubscript_(0)
        ca.setPixelFormat_(80)  # BGRA8Unorm
        ca.setBlendingEnabled_(True)
        # SrcAlpha, OneMinusSrcAlpha (= 4, 5 dans MTLBlendFactor)
        ca.setSourceRGBBlendFactor_(4)
        ca.setDestinationRGBBlendFactor_(5)
        ca.setSourceAlphaBlendFactor_(4)
        ca.setDestinationAlphaBlendFactor_(5)
        p, err = self._device.newRenderPipelineStateWithDescriptor_error_(sk, None)
        if p is None:
            raise RuntimeError(f"skel pipeline failed: {err}")
        self._skel_pipe = p

        # --- Mesh pipeline (triangles face/hand/body) ---
        # Vertex layout strictement identique au skel (reutilise vd).
        vd_mesh = MTLVertexDescriptor.vertexDescriptor()
        a0 = vd_mesh.attributes().objectAtIndexedSubscript_(0)
        a0.setFormat_(MTLVertexFormatFloat3); a0.setOffset_(0); a0.setBufferIndex_(0)
        a1 = vd_mesh.attributes().objectAtIndexedSubscript_(1)
        a1.setFormat_(MTLVertexFormatFloat); a1.setOffset_(12); a1.setBufferIndex_(0)
        a2 = vd_mesh.attributes().objectAtIndexedSubscript_(2)
        a2.setFormat_(MTLVertexFormatFloat); a2.setOffset_(16); a2.setBufferIndex_(0)
        ld2 = vd_mesh.layouts().objectAtIndexedSubscript_(0)
        ld2.setStride_(20); ld2.setStepFunction_(MTLVertexStepFunctionPerVertex)

        mp = MTLRenderPipelineDescriptor.alloc().init()
        mp.setVertexFunction_(lib.newFunctionWithName_("mesh_vertex"))
        mp.setFragmentFunction_(lib.newFunctionWithName_("mesh_fragment"))
        mp.setVertexDescriptor_(vd_mesh)
        cm = mp.colorAttachments().objectAtIndexedSubscript_(0)
        cm.setPixelFormat_(80)
        cm.setBlendingEnabled_(True)
        # SrcAlpha, OneMinusSrcAlpha — alpha classique pour voile mesh
        cm.setSourceRGBBlendFactor_(4)
        cm.setDestinationRGBBlendFactor_(5)
        cm.setSourceAlphaBlendFactor_(4)
        cm.setDestinationAlphaBlendFactor_(5)
        p, err = self._device.newRenderPipelineStateWithDescriptor_error_(mp, None)
        if p is None:
            raise RuntimeError(f"mesh pipeline failed: {err}")
        self._mesh_pipe = p

    # ---- CPU staging buffers --------------------------------------
    def _init_skel_cpu_buffer(self) -> None:
        """Preallocate the CPU staging buffer for skeleton segments.

        SKEL_MAX_SEGS * 10 floats : each segment = 2 verts × 5 floats
        (x, y, z, conf, pid).  Idempotent — no-op if already allocated.
        """
        if getattr(self, "_skel_cpu_buf", None) is None:
            self._skel_cpu_buf = np.zeros(SKEL_MAX_SEGS * 10, dtype=np.float32)

    def _init_mesh_cpu_buffer(self) -> None:
        if getattr(self, "_mesh_cpu_buf", None) is None:
            self._mesh_cpu_buf = np.zeros(MESH_MAX_VERTS * 5, dtype=np.float32)

    # ---- Uniforms helpers ------------------------------------------
    def _update_uniforms(self) -> int:
        s = self._state
        now = time.monotonic()
        with s.lock():
            # Flash de foudre : decay exponentiel ~600 ms
            dt_flash = now - s.last_lightning_t
            flash = max(0.0, 1.0 - dt_flash * 1.7) if dt_flash < 1.0 else 0.0
            # Positions des mains (point 0 = poignet) — pour mode hands3d
            lh_wrist = s.left_hand_kp[0] if s.hands_present else None
            rh_wrist = s.right_hand_kp[0] if s.hands_present else None
            hlx = (lh_wrist.x if lh_wrist else 0.5) * 2 - 1
            hly = 1 - (lh_wrist.y if lh_wrist else 0.5) * 2
            hrx = (rh_wrist.x if rh_wrist else 0.5) * 2 - 1
            hry = 1 - (rh_wrist.y if rh_wrist else 0.5) * 2
            uniforms = struct.pack(
                f"{UNIFORM_FLOATS}f",
                s.elapsed(),                                       # 1
                min(1.0, s.rms * 3.0),                             # 2
                min(1.0, s.swpc_kp / 9.0),                         # 3
                max(-0.1, min(0.1, s.netz_dev)),                   # 4
                flash,                                             # 5
                s.swpc_flare_norm,                                 # 6
                max(0.0, min(1.0, (s.swpc_wind_speed - 280.0) / 600.0)),  # 7
                max(-1.0, min(1.0, s.swpc_bz / 15.0)),             # 8
                min(1.0, s.social_rate / 50.0),                    # 9
                1.0 if s.pose_alive() else 0.0,                    # 10
                float(s.pose_count),                               # 11
                float(s.width),                                    # 12
                float(s.height),                                   # 13
                float(s.viz_mode),                                 # 14
                hlx, hly, hrx, hry,                                # 15-18 (mains)
                0.0, 0.0,                                          # 19-20 pad
            )
            n_segs = self._update_skeleton(s)
            n_tris = self._update_mesh(s)
        # Copie via memoryview (pyobjc API : varlist.as_buffer(N))
        mv = self._uniforms_buf.contents().as_buffer(UNIFORM_SIZE)
        mv[:] = uniforms
        # Log debug toutes les 120 frames (~2s) — confirme que mesh draw
        if not hasattr(self, "_dbg_n"):
            self._dbg_n = 0
        self._dbg_n += 1
        if self._dbg_n % 120 == 0:
            LOG.info("render: %d segs, %d tris (face=%d hand=%d body=%d)",
                     n_segs, n_tris,
                     len(self._state.persons_face),
                     len(self._state.persons_hands),
                     len(self._state.persons_body))
        return n_segs, n_tris

    def _update_skeleton(self, s: State) -> int:
        """Remplit self._skel_buf avec les segments visibles. Retourne le
        nombre de segments (2 verts chacun).

        Priorise MediaPipe (body 33 + face 478 + 2 mains 21) si disponible
        et present ; sinon fallback COCO 17 keypoints YOLO."""
        if not s.pose_alive():
            return 0

        buf = self._skel_cpu_buf
        segs = 0

        def push(A, B, conf, pid):
            """Empile un segment (2 verts) dans le buffer CPU prealloque."""
            nonlocal segs
            if segs >= SKEL_MAX_SEGS:
                return False
            ax = A.x * 2.0 - 1.0; ay = 1.0 - A.y * 2.0
            bx = B.x * 2.0 - 1.0; by = 1.0 - B.y * 2.0
            i = segs * 10
            buf[i+0] = ax; buf[i+1] = ay; buf[i+2] = float(A.z); buf[i+3] = conf; buf[i+4] = float(pid)
            buf[i+5] = bx; buf[i+6] = by; buf[i+7] = float(B.z); buf[i+8] = conf; buf[i+9] = float(pid)
            segs += 1
            return True

        if self._mp_bones is not None and (
            s.persons_body or s.persons_face or s.persons_hands or
            s.body_present or s.face_present or s.hands_present
        ):
            body_bones, face_bones, lhand_bones, _ = self._mp_bones
            # ----- MULTI-PERSONNE : pid = ID stable du tracker -----
            # (track_id persiste entre frames, palette se stabilise)
            ids_b = s.persons_body_ids or list(range(len(s.persons_body)))
            ids_f = s.persons_face_ids or list(range(len(s.persons_face)))
            ids_h = s.persons_hands_ids or list(range(len(s.persons_hands)))
            for i, body_kp in enumerate(s.persons_body):
                pid = ids_b[i] if i < len(ids_b) else i
                for a, b in body_bones:
                    if a >= len(body_kp) or b >= len(body_kp): continue
                    A = body_kp[a]; B = body_kp[b]
                    if A.c < 0.15 or B.c < 0.15: continue
                    if not push(A, B, min(A.c, B.c), pid): break
            for i, face_kp in enumerate(s.persons_face):
                pid = ids_f[i] if i < len(ids_f) else i
                for a, b in face_bones:
                    if a >= len(face_kp) or b >= len(face_kp): continue
                    if not push(face_kp[a], face_kp[b], 1.0, pid): break
                if segs >= SKEL_MAX_SEGS: break
            for i, hand_kp in enumerate(s.persons_hands):
                pid = ids_h[i] if i < len(ids_h) else i
                for a, b in lhand_bones:
                    if a >= len(hand_kp) or b >= len(hand_kp): continue
                    # Decalage palette mains (+5) pour les distinguer
                    if not push(hand_kp[a], hand_kp[b], 1.0, pid + 5): break
            # ----- FALLBACK single-person si persons_* vides -----
            if not (s.persons_body or s.persons_face or s.persons_hands):
                if s.body_present:
                    for a, b in body_bones:
                        if a >= len(s.body_kp) or b >= len(s.body_kp): continue
                        A = s.body_kp[a]; B = s.body_kp[b]
                        if A.c < 0.15 or B.c < 0.15: continue
                        if not push(A, B, min(A.c, B.c), 0): break
                if s.face_present:
                    for a, b in face_bones:
                        if a >= len(s.face_kp) or b >= len(s.face_kp): continue
                        if not push(s.face_kp[a], s.face_kp[b], 1.0, 0): break
                if s.hands_present:
                    for kp_list in (s.left_hand_kp, s.right_hand_kp):
                        if not any(p.x != 0.0 or p.y != 0.0 for p in kp_list):
                            continue
                        for a, b in lhand_bones:
                            if a >= len(kp_list) or b >= len(kp_list): continue
                            if not push(kp_list[a], kp_list[b], 1.0, 0): break
        else:
            # Fallback COCO 17 (YOLO legacy)
            for a, b in COCO_BONES:
                A = s.pose_kp[a]; B = s.pose_kp[b]
                if A.c < 0.2 or B.c < 0.2: continue
                if not push(A, B, min(A.c, B.c), 0): break

        if segs == 0:
            return 0
        data = self._skel_cpu_buf[: segs * 10].tobytes()
        mv = self._skel_buf.contents().as_buffer(len(data))
        mv[:] = data
        return segs

    def _update_mesh(self, s: State) -> int:
        """Remplit self._mesh_buf avec des triangles face/hand/body.

        Retourne le nombre de triangles ecrits (chacun = 3 vertices).
        Filtre les triangles dont au moins un sommet a confiance < 0.3.
        """
        if not s.pose_alive():
            return 0
        if not (s.persons_face or s.persons_hands or s.persons_body):
            return 0

        n_verts = 0

        def push_tri(kp_list, i, j, k, pid: int) -> bool:
            """Pousse un triangle (3 verts). Retourne False si buffer plein
            ou triangle invalide (confiance basse)."""
            nonlocal n_verts
            tris = n_verts // 3
            if tris >= MESH_MAX_TRIS:
                return False
            if i >= len(kp_list) or j >= len(kp_list) or k >= len(kp_list):
                return True   # skip mais continue
            A = kp_list[i]; B = kp_list[j]; C = kp_list[k]
            if A.c < 0.15 or B.c < 0.15 or C.c < 0.15:
                return True
            ax = A.x * 2.0 - 1.0; ay = 1.0 - A.y * 2.0
            bx = B.x * 2.0 - 1.0; by = 1.0 - B.y * 2.0
            cx = C.x * 2.0 - 1.0; cy = 1.0 - C.y * 2.0
            conf = min(A.c, B.c, C.c)
            fpid = float(pid)
            base = n_verts * 5
            self._mesh_cpu_buf[base + 0] = ax
            self._mesh_cpu_buf[base + 1] = ay
            self._mesh_cpu_buf[base + 2] = float(A.z)
            self._mesh_cpu_buf[base + 3] = conf
            self._mesh_cpu_buf[base + 4] = fpid
            self._mesh_cpu_buf[base + 5] = bx
            self._mesh_cpu_buf[base + 6] = by
            self._mesh_cpu_buf[base + 7] = float(B.z)
            self._mesh_cpu_buf[base + 8] = conf
            self._mesh_cpu_buf[base + 9] = fpid
            self._mesh_cpu_buf[base + 10] = cx
            self._mesh_cpu_buf[base + 11] = cy
            self._mesh_cpu_buf[base + 12] = float(C.z)
            self._mesh_cpu_buf[base + 13] = conf
            self._mesh_cpu_buf[base + 14] = fpid
            n_verts += 3
            return True

        ids_b = s.persons_body_ids or list(range(len(s.persons_body)))
        ids_f = s.persons_face_ids or list(range(len(s.persons_face)))
        ids_h = s.persons_hands_ids or list(range(len(s.persons_hands)))

        # Body
        for i, body_kp in enumerate(s.persons_body):
            pid = ids_b[i] if i < len(ids_b) else i
            for a, b, c in BODY_TRIANGLES:
                if not push_tri(body_kp, a, b, c, pid):
                    break

        # Face — utilise triangulation Delaunay dynamique sur les XY,
        # fallback sur FACE_TRIANGLES statique si Delaunay echoue.
        for i, face_kp in enumerate(s.persons_face):
            pid = ids_f[i] if i < len(ids_f) else i
            pts_xy = [(kp.x, kp.y) for kp in face_kp]
            tri_list = build_face_triangles_dynamic(pts_xy) or FACE_TRIANGLES
            for a, b, c in tri_list:
                if not push_tri(face_kp, a, b, c, pid):
                    break
            if n_verts // 3 >= MESH_MAX_TRIS:
                break

        # Hands — decalage palette +5 comme dans le skel
        for i, hand_kp in enumerate(s.persons_hands):
            pid = (ids_h[i] if i < len(ids_h) else i) + 5
            for a, b, c in HAND_TRIANGLES:
                if not push_tri(hand_kp, a, b, c, pid):
                    break

        if n_verts == 0:
            return 0
        data = self._mesh_cpu_buf[: n_verts * 5].tobytes()
        mv = self._mesh_buf.contents().as_buffer(len(data))
        mv[:] = data
        return n_verts // 3

    # ---- MTKViewDelegate ------------------------------------------
    def mtkView_drawableSizeWillChange_(self, view, size):  # noqa: N802
        with self._state.lock():
            self._state.width = int(size.width)
            self._state.height = int(size.height)

    def drawInMTKView_(self, view):  # noqa: N802
        n_segs, n_tris = self._update_uniforms()
        rpd = view.currentRenderPassDescriptor()
        drawable = view.currentDrawable()
        if rpd is None or drawable is None:
            return
        cb = self._queue.commandBuffer()
        enc = cb.renderCommandEncoderWithDescriptor_(rpd)

        # 1) background fullscreen tri
        enc.setRenderPipelineState_(self._bg_pipe)
        enc.setFragmentBuffer_offset_atIndex_(self._uniforms_buf, 0, 0)
        enc.drawPrimitives_vertexStart_vertexCount_(MTLPrimitiveTypeTriangle, 0, 3)

        # 2) mesh overlay (triangles face/hand/body) — DESSOUS le skel
        if n_tris > 0:
            enc.setRenderPipelineState_(self._mesh_pipe)
            enc.setVertexBuffer_offset_atIndex_(self._mesh_buf, 0, 0)
            enc.setVertexBuffer_offset_atIndex_(self._uniforms_buf, 0, 1)
            enc.drawPrimitives_vertexStart_vertexCount_(
                MTL_PRIMITIVE_TRIANGLE, 0, n_tris * 3)

        # 3) skeleton overlay (lignes par-dessus le mesh)
        if n_segs > 0:
            enc.setRenderPipelineState_(self._skel_pipe)
            enc.setVertexBuffer_offset_atIndex_(self._skel_buf, 0, 0)
            # SceneUniforms a buffer(1) du vertex pour acceder a U.rms etc
            enc.setVertexBuffer_offset_atIndex_(self._uniforms_buf, 0, 1)
            enc.drawPrimitives_vertexStart_vertexCount_(
                MTLPrimitiveTypeLine, 0, n_segs * 2)

        enc.endEncoding()
        cb.presentDrawable_(drawable)
        cb.commit()

    def device(self):
        return self._device
