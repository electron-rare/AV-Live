"""Entry point du visualizer Metal pour le mode data-only.

Lance :
  - Une fenetre AppKit avec une MTKView plein-cadre
  - Un thread OSC en arriere-plan qui ecoute :57123
  - La run loop NSApplication (jamais retournee tant que la window est ouverte)

Usage :
  uv run python -m data_only_viz.main
  uv run python -m data_only_viz.main --port 57123 --fullscreen

Le main thread DOIT etre la run loop AppKit (regle macOS). Le listener
OSC tourne dans un thread daemon.
"""
from __future__ import annotations

import argparse
import logging
import os
import signal
import sys

import objc
from AppKit import (
    NSApp,
    NSApplication,
    NSApplicationActivationPolicyRegular,
    NSBackingStoreBuffered,
    NSColor,
    NSEvent,
    NSEventMaskKeyDown,
    NSData,
    NSFont,
    NSImage,
    NSImageScaleProportionallyUpOrDown,
    NSImageView,
    NSMakeRect,
    NSObject,
    NSScreen,
    NSTextView,
    NSTimer,
    NSWindow,
    NSWindowStyleMaskClosable,
    NSWindowStyleMaskMiniaturizable,
    NSWindowStyleMaskResizable,
    NSWindowStyleMaskTitled,
    NSViewWidthSizable,
    NSViewHeightSizable,
)
from MetalKit import MTKView

from pythonosc.udp_client import SimpleUDPClient

from .osc_listener import OscListener
from .renderer import MetalRenderer
from .state import (
    KEYMAP_AUDIO, KEYMAP_SOURCE, KEYMAP_SOURCE_NUM, KEYMAP_VIDEO, State,
)

LOG = logging.getLogger("main")


class AppDelegate(NSObject):
    def initWithOpts_(self, opts):  # noqa: N802
        self = objc.super(AppDelegate, self).init()
        if self is None:
            return None
        self._opts = opts
        self._state = State()
        self._listener = OscListener(self._state, host="127.0.0.1", port=opts.port)
        # Sender vers sclang pour les changements de scene depuis le clavier
        self._scClient = SimpleUDPClient("127.0.0.1", opts.sclang_port)
        self._pose_worker = None
        return self

    def applicationDidFinishLaunching_(self, notification):  # noqa: N802
        LOG.info("applicationDidFinishLaunching: start")
        # Mode headless : --multi-hmr cede l'affichage a AV-Live-Body
        # (Swift RealityKit). On garde seulement le worker pose + le
        # sender TCP, donc pas de NSWindow / Metal renderer / HUD.
        if getattr(self._opts, "multi_hmr", False):
            LOG.info("multi-hmr mode: headless (no NSWindow)")
            self._headless = True
            from .multi_hmr_worker import MultiHMRWorker
            if not MultiHMRWorker.is_available():
                LOG.error(
                    "Multi-HMR requested via --multi-hmr but checkpoint is missing. "
                    "Run scripts/setup_multihmr.sh first, or omit --multi-hmr to use MediaPipe."
                )
                sys.exit(2)
            self._listener.start()
            self._start_pose_worker()
            LOG.info("headless ready — OSC :%d, TCP sender :57130",
                     self._opts.port)
            return
        self._headless = False
        # 1) Fenetre
        screen = NSScreen.mainScreen().frame()
        w, h = self._opts.width, self._opts.height
        x = (screen.size.width - w) / 2
        y = (screen.size.height - h) / 2
        style = (NSWindowStyleMaskTitled
                 | NSWindowStyleMaskClosable
                 | NSWindowStyleMaskResizable
                 | NSWindowStyleMaskMiniaturizable)
        self._window = NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
            NSMakeRect(x, y, w, h), style, NSBackingStoreBuffered, False)
        self._window.setTitle_("AV-Live  ·  data-only viz")
        self._window.setBackgroundColor_(NSColor.blackColor())
        LOG.info("window created")

        # 2) Container fullscreen avec 2 couches :
        #   z=0  NSImageView : flux webcam live PLEIN-CADRE (sous le Metal)
        #   z=1  MTKView      : skeleton + viz effects (transparent par-dessus)
        from AppKit import NSView
        self._container = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, w, h))
        self._container.setWantsLayer_(True)
        self._container.layer().setBackgroundColor_(
            NSColor.blackColor().CGColor())

        # 2a) Webcam fond plein-cadre
        self._cam = NSImageView.alloc().initWithFrame_(NSMakeRect(0, 0, w, h))
        self._cam.setImageScaling_(NSImageScaleProportionallyUpOrDown)
        self._cam.setAutoresizingMask_(NSViewWidthSizable | NSViewHeightSizable)
        # Background visible meme sans frame (debug)
        self._cam.setWantsLayer_(True)
        self._cam.layer().setBackgroundColor_(
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0.05, 0.05, 0.1, 1)
                .CGColor())
        self._container.addSubview_(self._cam)

        # 2b) MTKView par-dessus, transparent : on voit la webcam dessous
        self._renderer = MetalRenderer.alloc().initWithState_(self._state)
        LOG.info("renderer created")
        device = self._renderer.device()
        self._mtkview = MTKView.alloc().initWithFrame_device_(
            NSMakeRect(0, 0, w, h), device)
        self._mtkview.setDelegate_(self._renderer)
        self._mtkview.setPreferredFramesPerSecond_(60)
        self._mtkview.setColorPixelFormat_(80)   # BGRA8Unorm
        # Transparence : on rend le MTKView en RGBA et on laisse la
        # CAMetalLayer ne pas etre opaque pour voir le NSImageView dessous.
        layer = self._mtkview.layer()
        if layer is not None:
            layer.setOpaque_(False)
            # MTKView expose framebufferOnly directement
            try: self._mtkview.setFramebufferOnly_(False)
            except Exception: pass
        self._mtkview.setClearColor_((0.0, 0.0, 0.0, 0.0))
        self._mtkview.setAutoresizingMask_(NSViewWidthSizable | NSViewHeightSizable)
        self._container.addSubview_(self._mtkview)
        LOG.info("mtkview configured (transparent overlay)")

        self._window.setContentView_(self._container)
        # Window au premier plan : level = floating, always on top jusqu'a
        # ce qu'on perde le focus. Sinon la fenetre peut etre cachee
        # derriere l'IDE / le terminal.
        self._window.setLevel_(3)   # NSFloatingWindowLevel
        self._window.makeKeyAndOrderFront_(None)
        NSApp().activateIgnoringOtherApps_(True)
        self._window.makeFirstResponder_(self._container)
        LOG.info("window shown + key focus forced + floating level")

        # 2b) HUD : overlay NSTextView semi-transparent au-dessus du MTKView.
        # NSTextView prend en charge le rendu CoreText sans avoir a passer
        # par un MTLBuffer texte. On le pose comme subview du MTKView.
        self._hud = NSTextView.alloc().initWithFrame_(
            NSMakeRect(12, 12, 340, 240))
        self._hud.setEditable_(False)
        self._hud.setSelectable_(False)
        self._hud.setDrawsBackground_(True)
        self._hud.setBackgroundColor_(
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0, 0, 0, 0.45))
        self._hud.setFont_(NSFont.fontWithName_size_("Menlo", 11))
        self._hud.setTextColor_(NSColor.whiteColor())
        self._hud.setAutoresizingMask_(NSViewHeightSizable)
        self._mtkview.addSubview_(self._hud)
        # Timer 10 Hz, rafraichit le texte avec les valeurs du State.
        self._hudTimer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            0.1, self, "refreshHud:", None, True)

        # 2c) Timer webcam update (NSImageView fullscreen deja cree en 2a)
        self._camTimer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            1.0 / 15.0, self, "refreshCam:", None, True)

        # 2d) Auto-engage du mode openpos (#9) quand des personnes sont
        # detectees. Si l'utilisateur a force un mode au clavier dans
        # les 8 dernieres secondes, on n'override pas (lock manuel).
        self._user_viz_lock_t = 0.0   # set par _on_key, lu par autoOpenpos
        self._autoOpenposTimer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            0.5, self, "autoOpenpos:", None, True)

        if self._opts.fullscreen:
            self._window.toggleFullScreen_(None)

        # 3) Listener OSC
        self._listener.start()
        LOG.info("ready — listening OSC :%d (sc -> :%d)",
                 self._opts.port, self._opts.sclang_port)

        # 3b) Pose worker (optionnel, cv2 + YOLOv8-pose -> State)
        if self._opts.pose:
            self._request_camera_and_start_pose()

    def _request_camera_and_start_pose(self):
        """macOS exige que la demande TCC camera (AVCaptureDevice.requestAccess)
        vienne du MAIN THREAD AppKit. OpenCV depuis un worker thread plante
        avec 'can not spin main run loop from other thread'. On demande ici,
        sur le main thread, PUIS on lance le pose worker avec
        OPENCV_AVFOUNDATION_SKIP_AUTH=1 pour qu'il ne tente pas une 2e demande."""
        import os
        os.environ["OPENCV_AVFOUNDATION_SKIP_AUTH"] = "1"
        try:
            from AVFoundation import (
                AVCaptureDevice, AVMediaTypeVideo,
                AVAuthorizationStatusAuthorized,
                AVAuthorizationStatusNotDetermined,
            )
            status = AVCaptureDevice.authorizationStatusForMediaType_(AVMediaTypeVideo)
            LOG.info("camera TCC status: %s", status)
            if status == AVAuthorizationStatusAuthorized:
                self._start_pose_worker()
                return
            if status == AVAuthorizationStatusNotDetermined:
                LOG.info("requesting camera access via AVFoundation...")
                def _handler(granted):
                    LOG.info("camera access granted=%s", granted)
                    if granted:
                        # Le handler tourne sur un thread arbitraire ; on dispatch
                        # vers le main pour creer le worker proprement.
                        from Foundation import NSOperationQueue
                        NSOperationQueue.mainQueue().addOperationWithBlock_(
                            self._start_pose_worker)
                AVCaptureDevice.requestAccessForMediaType_completionHandler_(
                    AVMediaTypeVideo, _handler)
                return
            LOG.warning("camera access denied — Reglages > Confidentialite")
        except Exception as e:  # noqa: BLE001
            LOG.warning("AVFoundation TCC check failed (%s) — tentative directe", e)
            self._start_pose_worker()

    def _start_pose_worker(self):
        # Priorite (user feedback : on veut FACE + HANDS + BODY toujours
        # disponibles pour le mapping sonore + viz openpos, donc MediaPipe
        # Multi devient le default avec ses 33 body + 478 face + 42 hand
        # par personne, plutot qu'Apple Vision body-only 13 joints) :
        # 0. Multi-HMR (opt-in via --multi-hmr flag)
        # 1. MediaPipe Multi (33+478+42 kp × 4 personnes) — DEFAUT
        # 2. Apple Vision body pose (fallback si MediaPipe casse)
        # 3. CoreML pose, DETRPose, Holistic, YOLO — fallbacks
        import os as _os
        # iPhone ARBodyTracker (option 2 LiDAR fusion) : always-on
        # listener on :57128. Harmless if no iPhone is broadcasting ;
        # state.persons_arkit_joints stays empty and the arkit_fuse
        # stage no-ops. Activated via POSE_FILTER=...+arkit_fuse.
        try:
            from .iphone_osc_listener import IphoneOSCListener
            self._iphone_osc = IphoneOSCListener(self._state)
            self._iphone_osc.start()
            LOG.info("worker: + iPhone OSC listener :57128")
        except Exception as e:  # noqa: BLE001
            LOG.warning("iphone OSC listener start failed (%s)", e)
        # ICP LiDAR fusion (opt-in via ICP_FUSION=1). Parallel to the
        # ARKit pelvis fuse: ICP operates on SMPL-X dense vertices, not
        # joints. Requires a calibrated extrinsic on disk (see
        # scripts/calibrate_lidar.py) and an iPhone LiDAR stream
        # broadcasting on ICP_LIDAR_HOST:ICP_LIDAR_PORT.
        if _os.environ.get("ICP_FUSION", "0") == "1":
            host = _os.environ.get("ICP_LIDAR_HOST")
            if not host:
                LOG.warning("ICP_FUSION=1 but ICP_LIDAR_HOST unset — "
                            "fusion disabled")
            else:
                try:
                    from .icp_fusion_worker import IcpFusionThread
                    self._icp_fusion = IcpFusionThread(
                        self._state,
                        host=host,
                        port=int(_os.environ.get("ICP_LIDAR_PORT", "5500")),
                    )
                    self._icp_fusion.start()
                    LOG.info("worker: + ICP LiDAR fusion -> %s:%s", host,
                             _os.environ.get("ICP_LIDAR_PORT", "5500"))
                except Exception as e:  # noqa: BLE001
                    LOG.warning("icp fusion start failed (%s)", e)
        # 0. Multi-HMR (SMPL-X 10475 verts mesh dense) — opt-in via flag
        if getattr(self._opts, "multi_hmr", False):
            try:
                from .multi_hmr_worker import MultiHMRWorker
                from .smplx_osc_sender import SMPLXTCPSender
                if MultiHMRWorker.is_available():
                    self._pose_worker = MultiHMRWorker(
                        self._state, num_persons=4,
                        target_fps=10.0,
                        device=getattr(self._opts, "pose_device", "mps"),
                        det_thresh=getattr(self._opts, "det_thresh", 0.15),
                        nms_kernel_size=getattr(
                            self._opts, "nms_kernel_size", 5),
                        motion_gate=getattr(
                            self._opts, "motion_gate", 5.0),
                        camera_index=getattr(self._opts, "camera_index", -1))
                    self._pose_worker.start()
                    # MESH_RIG=0 disables the 30 fps rigid translation
                    # rigger from mesh_rigger.py (used to debug deformation
                    # issues introduced by the hybrid rigging path).
                    self._smplx_tcp = SMPLXTCPSender(
                        self._state,
                        enable_rigging=os.environ.get("MESH_RIG", "1") != "0",
                    )
                    self._smplx_tcp.start()
                    LOG.info("worker: Multi-HMR + SMPL-X (mesh dense)")
                    # Secondary body-pose worker in parallel: AVLiveBody
                    # gets body keypoints on UDP :57126 alongside the mesh
                    # on TCP :57130. Default: Apple Vision (ANE-accel,
                    # body only 19 joints). Set AV_LIVE_PARALLEL_POSE=
                    # mediapipe to swap to MediaPipe Holistic (CPU
                    # XNNPACK but provides face + hand + 3D world).
                    # Defaut: lance BOTH Apple Vision (body 19 joints sur
                    # ANE, ~30 fps) ET MediaPipe Multi (face 468 + hands 21
                    # + pose 3D world sur CPU XNNPACK). Set
                    # AV_LIVE_PARALLEL_POSE=apple_vision pour ne garder que
                    # le path ANE (face/hand fin disparait), ou =mediapipe
                    # pour ne garder que CPU.
                    parallel = _os.environ.get(
                        "AV_LIVE_PARALLEL_POSE", "both")
                    if parallel in ("apple_vision", "both"):
                        try:
                            from .apple_vision_pose import AppleVisionPoseWorker
                            if AppleVisionPoseWorker.is_available():
                                self._av_worker = AppleVisionPoseWorker(
                                    self._state, target_fps=30.0,
                                    num_persons=4)
                                self._av_worker.start()
                                LOG.info("worker: + Apple Vision body pose "
                                         "(ANE) in parallel")
                            else:
                                raise RuntimeError("apple_vision unavailable")
                        except Exception as e:  # noqa: BLE001
                            LOG.warning("Apple Vision parallel start failed "
                                        "(%s)", e)
                    if parallel in ("mediapipe", "both"):
                        try:
                            from .multi import MultiWorker
                            self._mp_worker = MultiWorker(
                                self._state, num_persons=4)
                            self._mp_worker.start()
                            LOG.info("worker: + MediaPipe Multi (3D pose "
                                     "+ face + hand) in parallel")
                        except Exception as e:  # noqa: BLE001
                            LOG.warning("MediaPipe parallel start failed "
                                        "(%s)", e)
                    return
                LOG.info("Multi-HMR indisponible (checkpoints manquants) "
                         "— voir scripts/setup_multihmr.sh")
            except Exception as e:  # noqa: BLE001
                LOG.warning("Multi-HMR failed (%s) — fallback", e)
        # 1. MediaPipe Multi : DEFAUT pour le mapping sonore + openpos
        # (33 body + 478 face + 21x2 hands × 4 personnes). Skip via
        # AV_LIVE_MEDIAPIPE=0 si on prefere body-only ANE-accelere.
        if _os.environ.get("AV_LIVE_MEDIAPIPE") != "0":
            try:
                from .multi import MultiWorker
                self._pose_worker = MultiWorker(self._state, num_persons=4)
                self._pose_worker.start()
                LOG.info("worker: MediaPipe Multi (Pose+Face+Hand × 4)")
                return
            except Exception as e:  # noqa: BLE001
                LOG.warning("MediaPipe Multi unavailable (%s) — fallback", e)
        # 2. Apple Vision body pose : fallback si MediaPipe casse.
        # Body only, 13 joints, pas de face/hands.
        if _os.environ.get("AV_LIVE_APPLE_VISION") != "0":
            try:
                from .apple_vision_pose import AppleVisionPoseWorker
                if AppleVisionPoseWorker.is_available():
                    self._pose_worker = AppleVisionPoseWorker(
                        self._state, target_fps=30.0, num_persons=4)
                    self._pose_worker.start()
                    LOG.info("worker: Apple Vision body pose "
                             "(ANE natif, body only, multi-personne)")
                    return
                LOG.info("Apple Vision body pose indisponible "
                         "(macOS < 11 ?) — fallback")
            except Exception as e:  # noqa: BLE001
                LOG.warning("Apple Vision pose indisponible (%s) — fallback", e)
        if _os.environ.get("AV_LIVE_COREML") != "0":
            try:
                from .coreml_pose import CoreMLPoseWorker
                if CoreMLPoseWorker.is_available():
                    self._pose_worker = CoreMLPoseWorker(
                        self._state, target_fps=30.0, num_persons=4)
                    self._pose_worker.start()
                    LOG.info("worker: CoreML pose natif "
                             "(AVFoundation + YOLO11n-pose ANE)")
                    return
                LOG.info("CoreML pose .mlpackage absent — "
                         "lancer 'uv run python -m data_only_viz.scripts.convert_coreml' "
                         "puis relancer pour activer le pipeline ANE")
            except Exception as e:  # noqa: BLE001
                LOG.warning("CoreML pose indisponible (%s) — fallback", e)
        if _os.environ.get("AV_LIVE_DETRPOSE") == "1":
            try:
                from .detrpose import DETRPoseWorker, is_available
                if is_available():
                    self._pose_worker = DETRPoseWorker(
                        self._state, num_persons=4,
                        model_size=getattr(self._opts, "detrpose_model_size", "n"))
                    self._pose_worker.start()
                    LOG.info("worker: DETRPose (transformer, body 17 kp × 4)")
                    return
                LOG.info("DETRPose pas installe — fallback MediaPipe Multi "
                         "(voir data_only_viz/detrpose.py pour install)")
            except Exception as e:  # noqa: BLE001
                LOG.warning("detrpose indisponible (%s) — fallback multi", e)
        # MediaPipe Multi deja tente en priorite 1 ; on saute direct
        # au fallback holistic puis YOLO.
        try:
            from .holistic import HolisticWorker
            self._pose_worker = HolisticWorker(self._state)
            self._pose_worker.start()
            LOG.info("worker: MediaPipe Holistic (mono-personne ~553 lm)")
            return
        except Exception as e:  # noqa: BLE001
            LOG.warning("holistic unavailable (%s) — fallback YOLO", e)
        from .pose import PoseWorker
        self._pose_worker = PoseWorker(
            self._state, device=self._opts.pose_device)
        self._pose_worker.start()

        # 4) Hook clavier : local (app au focus) + global (app au fond).
        # Le global monitor est read-only mais permet de garder le pilotage
        # quand l'utilisateur a une autre app au premier plan (IDE,
        # browser). On ignore le retour pour le global (sinon double-trigger).
        self._kb_monitor = NSEvent.addLocalMonitorForEventsMatchingMask_handler_(
            NSEventMaskKeyDown, self._on_key)
        self._kb_global = NSEvent.addGlobalMonitorForEventsMatchingMask_handler_(
            NSEventMaskKeyDown, self._on_key_global)
        # Force le focus initial pour que le local monitor reçoive
        # tout de suite les touches sans nécessiter un clic.
        NSApp().activateIgnoringOtherApps_(True)
        self._window.makeKeyAndOrderFront_(None)
        self._window.makeFirstResponder_(self._container)

    _cam_log_count = 0

    def refreshCam_(self, _timer):  # noqa: N802
        """Lit la derniere frame JPEG du pose worker et l'affiche en fond."""
        with self._state.lock():
            jpg = self._state.last_webcam_jpeg
        if not jpg:
            return
        try:
            # NSData : on essaye 2 APIs ; la deuxieme est plus robuste
            # avec pyobjc 12 pour les Python bytes.
            data = NSData.dataWithBytes_length_(jpg, len(jpg))
        except Exception:
            data = NSData.alloc().initWithBytes_length_(jpg, len(jpg))
        img = NSImage.alloc().initWithData_(data)
        if img is not None and img.isValid():
            self._cam.setImage_(img)
            self.__class__._cam_log_count += 1
            if self.__class__._cam_log_count in (1, 30, 150):
                LOG.info("cam frame #%d displayed (size %dx%d)",
                         self.__class__._cam_log_count,
                         int(img.size().width), int(img.size().height))
        elif self.__class__._cam_log_count == 0:
            LOG.warning("cam: NSImage init failed (jpg %d bytes)", len(jpg))
            self.__class__._cam_log_count = -1

    def refreshHud_(self, _timer):  # noqa: N802
        """Format le HUD avec la valeur courante des flux + correspondance
        avec le rendu visuel. Appele a 10 Hz par NSTimer."""
        s = self._state
        with s.lock():
            mode = s.viz_mode
            mode_name = s.viz_mode_names[mode]
            preset = s.active_preset
            scene = s.active_scene
            kp = s.swpc_kp
            flare = s.swpc_flare_norm
            wind = s.swpc_wind_speed
            bz = s.swpc_bz
            netz = s.netz_dev
            lr = s.lightning_rate_min
            quake = s.usgs_last_mag
            planes = s.aviation_count
            social = s.social_rate
            pose_n = s.pose_count
            pose_live = s.pose_alive()
            rms = s.rms
            bpm = s.bpm
            beat = s.beat
            bridge_age = 0.0
            if s.last_heartbeat:
                import time as _t
                bridge_age = _t.monotonic() - s.last_heartbeat
        # Marqueurs : ce que chaque donnee fait dans le rendu courant
        kp_norm   = min(1.0, kp / 9.0)
        wind_norm = max(0.0, min(1.0, (wind - 280.0) / 600.0))
        bz_norm   = max(-1.0, min(1.0, bz / 15.0))
        bridge_ok = "OK" if bridge_age < 15 else "DOWN"
        bar = lambda v, w=14: "█" * int(max(0.0, min(1.0, v)) * w) + \
                              "·" * (w - int(max(0.0, min(1.0, v)) * w))
        bits = []
        if preset: bits.append(f"source:{preset}")
        if scene:  bits.append(f"scène:{scene}")
        active_line = ("  " + " · ".join(bits)) if bits else ""
        bridge_label = "OK" if bridge_age < 15 else "ARRÊTÉ"
        pose_label = "OUI" if pose_live else "non"
        txt = (
            f"AV-Live data-only · vidéo:[{mode}]{mode_name}{active_line}\n"
            f"────────────────────────────────────────\n"
            f" Touches  vidéo:azertyuiop  audio:qsdfghjklm  source:wxcvbn 0-9\n"
            f"────────────────────────────────────────\n"
            f" Audio     rms {rms:5.2f}  bpm {bpm:5.1f}  beat {beat:>4}\n"
            f" Pont      {bridge_label}  ({bridge_age:4.1f}s)\n"
            f"────────────────────────────────────────\n"
            f" Soleil  Kp      {kp:4.1f}  {bar(kp_norm)}     → palette orage\n"
            f"        éruption {flare:4.2f}  {bar(flare)}     → flash orange\n"
            f"        vent     {wind:4.0f}  {bar(wind_norm)}     → vitesse fond\n"
            f"        Bz       {bz:+5.1f}  {bar((bz_norm+1)/2)}     → reverb\n"
            f" Réseau  Δf       {netz:+.3f}Hz  {bar(abs(netz)*10)}     → vibrato\n"
            f" Foudre  {lr:4.1f}/min               → percussions\n"
            f" Séisme  M  {quake:4.1f}              → sub-bass\n"
            f" Avions  {planes:>4}                 → voix FM\n"
            f" Social  {social:4.1f}/s              → kick\n"
            f" Pose    n={pose_n:>2}  live={pose_label}  → squelette\n"
        )
        self._hud.setString_(txt)

    def autoOpenpos_(self, _timer):  # noqa: N802
        """Si des personnes sont detectees ET l'utilisateur n'a pas pose
        un mode au clavier dans les 8 dernieres secondes, on passe
        automatiquement en mode openpos (#9) pour mettre la pose en
        valeur. Lache la main si lock recent ou si plus personne."""
        import time as _t
        s = self._state
        with s.lock():
            has_persons = bool(s.persons_body)
            mode = s.viz_mode
        now = _t.monotonic()
        if (now - self._user_viz_lock_t) < 8.0:
            return  # lock utilisateur recent
        if has_persons and mode != 9:
            with s.lock():
                s.viz_mode = 9
            LOG.info("[auto] openpos engaged (persons detectees)")
        elif not has_persons and mode == 9:
            # plus de personne, on revient au mode storm par defaut
            with s.lock():
                s.viz_mode = 0
            LOG.info("[auto] storm engaged (plus de pose)")

    def _on_key_global(self, ev):
        # Global monitor : read-only, on appelle _on_key mais on ne
        # retourne pas l'event (interdit par AppKit pour les globaux).
        try:
            self._on_key(ev)
        except Exception as e:  # noqa: BLE001
            LOG.warning("global key handler failed: %s", e)

    def _on_key(self, ev):
        key = ev.charactersIgnoringModifiers()
        if not key:
            return ev
        k = key.lower()
        # Debug : log toutes les touches recues pour diagnostic
        LOG.debug("[key] raw=%r lower=%r", key, k)
        if key == "\x1b":
            NSApp().terminate_(self); return None
        if key == " ":
            self._scClient.send_message("/control/doScene", ["stop"])
            return None
        # Cmd+F geree par macOS pour fullscreen ; on garde shift+F en raccourci
        if key == "F":
            self._window.toggleFullScreen_(None); return None
        if key == "H":
            self._hud.setHidden_(not self._hud.isHidden()); return None
        if key == "C":  # Shift+C : toggle webcam overlay
            self._cam.setHidden_(not self._cam.isHidden()); return None
        # azertyuiop -> video (viz mode)
        for kk, name in KEYMAP_VIDEO:
            if k == kk:
                names = list(self._state.viz_mode_names)
                if name in names:
                    idx = names.index(name)
                    with self._state.lock():
                        self._state.viz_mode = idx
                    # Lock l'auto-openpos pendant 8s : l'utilisateur a
                    # explicitement choisi un mode, on respecte.
                    import time as _t
                    self._user_viz_lock_t = _t.monotonic()
                    LOG.info("[video] viz -> %s (%d) (lock 8s)", name, idx)
                return None
        # qsdfghjklm -> audio (scene SC)
        for kk, scene in KEYMAP_AUDIO:
            if k == kk:
                self._scClient.send_message("/control/doScene", [scene])
                with self._state.lock():
                    self._state.active_scene = scene
                LOG.info("[audio] scene -> %s", scene)
                return None
        # wxcvbn + 0-9 -> preset bundle (source + scene audio + viz video)
        for kk, source, scene, viz in (*KEYMAP_SOURCE, *KEYMAP_SOURCE_NUM):
            if key == kk or k == kk:
                # Audio : envoie a sclang
                self._scClient.send_message("/control/doScene", [scene])
                # Video : applique le viz mode
                names = list(self._state.viz_mode_names)
                idx = names.index(viz) if viz in names else 0
                with self._state.lock():
                    self._state.viz_mode = idx
                    self._state.active_preset = source
                    self._state.active_scene = scene
                LOG.info("[preset] %s : scene=%s viz=%s", source, scene, viz)
                return None
        return ev

    def applicationWillTerminate_(self, _):  # noqa: N802
        self._listener.stop()
        if self._pose_worker is not None:
            self._pose_worker.stop()
        icp = getattr(self, "_icp_fusion", None)
        if icp is not None:
            try:
                icp.stop()
            except Exception as e:  # noqa: BLE001
                LOG.warning("icp fusion stop failed (%s)", e)
        LOG.info("bye")


def main() -> int:
    p = argparse.ArgumentParser(prog="data_only_viz")
    p.add_argument("--port", type=int, default=57123,
                   help="UDP port OSC entrant (default 57123)")
    p.add_argument("--sclang-port", type=int, default=57121,
                   help="UDP port SC sortant pour /control/doScene (default 57121)")
    p.add_argument("--width", type=int, default=1280)
    p.add_argument("--height", type=int, default=720)
    p.add_argument("--fullscreen", action="store_true")
    p.add_argument("--pose", action="store_true",
                   help="Active la captation pose YOLO (cv2 + ultralytics)")
    p.add_argument("--multi-hmr", dest="multi_hmr", action="store_true",
                   help="Active Multi-HMR worker pour mesh SMPL-X dense "
                        "(necessite setup_multihmr.sh + SMPLX_NEUTRAL.npz)")
    p.add_argument("--camera-index", dest="camera_index", type=int,
                   default=-1,
                   help="Index camera OpenCV (-1 = auto built-in Mac)")
    p.add_argument("--pose-device", default="mps",
                   choices=("cpu", "mps", "cuda:0"),
                   help="Device YOLO inference (default mps)")
    p.add_argument("--det-thresh", dest="det_thresh", type=float,
                   default=0.15,
                   help="Multi-HMR detection threshold (default 0.15)")
    p.add_argument("--nms-kernel-size", dest="nms_kernel_size", type=int,
                   default=5,
                   help="Multi-HMR NMS kernel (odd, >=3; default 5)")
    p.add_argument("--motion-gate", dest="motion_gate", type=float,
                   default=5.0,
                   help="Skip Multi-HMR si diff caméra <X (0-255 ; "
                        "0=desactive ; default 5.0)")
    p.add_argument("--detrpose-model-size",
                   choices=["n", "s", "l"],
                   default="n",
                   help="DETRPose model size (default: n)")
    p.add_argument("-v", "--verbose", action="store_true")
    opts = p.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if opts.verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s — %(message)s",
        datefmt="%H:%M:%S",
    )

    app = NSApplication.sharedApplication()
    app.setActivationPolicy_(NSApplicationActivationPolicyRegular)
    delegate = AppDelegate.alloc().initWithOpts_(opts)
    app.setDelegate_(delegate)

    # Ctrl-C en console termine proprement
    signal.signal(signal.SIGINT, lambda *_: app.terminate_(None))

    app.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
