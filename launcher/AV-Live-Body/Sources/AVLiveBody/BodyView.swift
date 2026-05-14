import AppKit
import AVFoundation
import MetalKit
import RealityKit
import simd
import SwiftUI

/// Wrapper SwiftUI : webcam en BACKGROUND LEGER (opacite controlable)
/// + ARView transparent par-dessus avec mesh SMPL-X. Toutes les
/// valeurs visuelles (cam opacity, bg, lights, FOV...) sont pilotees
/// en live par RenderSettings.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer
    @ObservedObject var settings: RenderSettings
    @ObservedObject var poseListener: PoseOSCListener

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer = CALayer()
        container.layer?.backgroundColor = NSColor(
            white: CGFloat(settings.bgBrightness), alpha: 1.0).cgColor

        // 1. Camera preview (zPosition -100 = derriere tout subview)
        let camera = CameraPreviewLayer()
        _ = camera.start()
        let preview = camera.previewLayer
        preview.frame = container.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        preview.opacity = Float(settings.camOpacity)
        preview.zPosition = -100
        preview.isHidden = !settings.showCamera
        container.layer?.addSublayer(preview)

        // 1b. MTKView des scenes Metal (storm/tunnel/openpos/...) en
        // couche intermediaire entre la cam et l'ARView. Transparent
        // par-dessus la cam (alpha blending via clearColor).
        let scene = SceneRenderer.make()
        let mtkView = MTKView(frame: container.bounds,
                              device: scene?.uniforms != nil
                                ? MTLCreateSystemDefaultDevice() : nil)
        mtkView.delegate = scene
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.layer?.isOpaque = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0,
                                            alpha: 0)
        mtkView.preferredFramesPerSecond = 60
        mtkView.autoresizingMask = [.width, .height]
        mtkView.isHidden = !settings.showScene
        container.addSubview(mtkView)

        // 2. ARView transparent — isOpaque false sinon le compositeur
        //    OS reecrit l'alpha
        let arView = ARView(frame: container.bounds)
        arView.environment.background = .color(.clear)
        arView.autoresizingMask = [.width, .height]
        arView.wantsLayer = true
        arView.layer?.isOpaque = false
        arView.layer?.backgroundColor = NSColor.clear.cgColor
        arView.layer?.zPosition = 0

        // PerspectiveCamera + 3 lumieres directionnelles
        let camEntity = PerspectiveCamera()
        camEntity.camera.fieldOfViewInDegrees = Float(settings.fieldOfView)
        let camAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        camAnchor.addChild(camEntity)
        arView.scene.addAnchor(camAnchor)

        let key = DirectionalLight()
        key.light.intensity = Float(settings.keyIntensity)
        key.orientation = simd_quatf(angle: .pi / 6, axis: SIMD3(1, 0, 0))
        let keyAnchor = AnchorEntity(world: SIMD3<Float>(1, 2, -1))
        keyAnchor.addChild(key)
        arView.scene.addAnchor(keyAnchor)

        let fill = DirectionalLight()
        fill.light.intensity = Float(settings.fillIntensity)
        fill.light.color = NSColor(red: 0.7, green: 0.8, blue: 1.0,
                                    alpha: 1.0)
        let fillAnchor = AnchorEntity(world: SIMD3<Float>(-2, 1, -2))
        fillAnchor.addChild(fill)
        arView.scene.addAnchor(fillAnchor)

        let rim = DirectionalLight()
        rim.light.intensity = Float(settings.rimIntensity)
        let rimAnchor = AnchorEntity(world: SIMD3<Float>(0, 1, -5))
        rimAnchor.addChild(rim)
        arView.scene.addAnchor(rimAnchor)

        let bodyAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(bodyAnchor)
        container.addSubview(arView)

        // 60 fps mesh interpolation between Multi-HMR frames (Python
        // worker emits ~4 fps). Hook into RealityKit Update event.
        renderer.attachToScene(arView.scene)

        context.coordinator.bodyAnchor = bodyAnchor
        context.coordinator.arView = arView
        context.coordinator.cameraEntity = camEntity
        context.coordinator.sceneRenderer = scene
        context.coordinator.mtkView = mtkView
        context.coordinator.skeletonOverlay = SkeletonOverlay(parent: bodyAnchor)
        // Skeleton 3D RealityKit armature (33 spheres + 32 cylinders bones)
        // driven by /pose3d/* OSC from MediaPipe pose_world_landmarks.
        // Visible quand toggle showSkeleton ou vizMode==9 (openpos).
        let skel3dAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.5))
        arView.scene.addAnchor(skel3dAnchor)
        let skel3d = Skeleton3DRenderer()
        skel3d.attach(to: skel3dAnchor, listener: poseListener)
        context.coordinator.skel3dAnchor = skel3dAnchor
        context.coordinator.skel3d = skel3d
        context.coordinator.keyLight = key
        context.coordinator.fillLight = fill
        context.coordinator.rimLight = rim
        context.coordinator.previewLayer = preview
        context.coordinator.container = container
        context.coordinator.renderer = renderer

        // Hook clavier global : capture les touches au niveau NSEvent
        // pour eviter les beeps systeme quand un .keyboardShortcut SwiftUI
        // ne trouve pas de cible. Touches : S / 0-9 / C V M W.
        if context.coordinator.kbMonitor == nil {
            context.coordinator.kbMonitor =
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                ev in
                guard let chars = ev.charactersIgnoringModifiers else {
                    return ev
                }
                let k = chars.lowercased()
                switch k {
                case "s":
                    NotificationCenter.default.post(
                        name: .toggleSettings, object: nil); return nil
                case "c":
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "camera"); return nil
                case "v":
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "scene"); return nil
                case "m":
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "mesh"); return nil
                case "w":
                    NotificationCenter.default.post(
                        name: .toggleLayer, object: "wireframe"); return nil
                case "0", "1", "2", "3", "4",
                     "5", "6", "7", "8", "9":
                    if let n = Int(k) {
                        NotificationCenter.default.post(
                            name: .setVizMode, object: n)
                    }
                    return nil
                default:
                    return ev
                }
            }
        }
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {
        let c = context.coordinator
        // Apply live settings
        c.previewLayer?.opacity = Float(settings.camOpacity)
        c.previewLayer?.isHidden = !settings.showCamera
        c.mtkView?.isHidden = !settings.showScene
        c.sceneRenderer?.uniforms.viz_mode = Float(settings.vizMode)
        // Skeleton overlay openpos : visible si mode openpos (#9) OU
        // si toggle showSkeleton actif (option manuel).
        let skelVisible = settings.vizMode == 9 || settings.showSkeleton
        c.skeletonOverlay?.update(persons: poseListener.persons,
                                  visible: skelVisible)
        // 3D RealityKit armature : show/hide root anchor in sync with
        // the same skelVisible signal as the 2D overlay. Skeleton keeps
        // its own hip-relative coords (z=-3 anchor), mesh keeps its own
        // world coords — both visible together in mode openpos, no
        // spatial fusion (original design from commit f540158).
        c.skel3dAnchor?.isEnabled = skelVisible
        // Pose -> scene uniforms : drive hands3d (mode 8) et openpos
        // (mode 9) avec la premiere personne detectee. Les wrists pilotent
        // hand_l/r ; pose_count alimente bg_fragment.
        let persons = poseListener.persons
        c.sceneRenderer?.uniforms.pose_count = Float(persons.count)
        c.sceneRenderer?.uniforms.pose_alive = persons.isEmpty ? 0 : 1
        if let first = persons.values.first {
            // Convertit coords ecran (0..1) -> NDC-ish (-1..1)
            c.sceneRenderer?.uniforms.hand_l_x = (first.wristL.x - 0.5) * 2
            c.sceneRenderer?.uniforms.hand_l_y = (first.wristL.y - 0.5) * 2
            c.sceneRenderer?.uniforms.hand_r_x = (first.wristR.x - 0.5) * 2
            c.sceneRenderer?.uniforms.hand_r_y = (first.wristR.y - 0.5) * 2
        } else {
            c.sceneRenderer?.uniforms.hand_l_x = 0
            c.sceneRenderer?.uniforms.hand_l_y = 0
            c.sceneRenderer?.uniforms.hand_r_x = 0
            c.sceneRenderer?.uniforms.hand_r_y = 0
        }
        // ---- 2026-05-14 face/hand/body3d derivatives ----
        // Simple EMA smoother to limit jitter from raw detections.
        func ema(_ key: String, _ raw: Float, alpha: Float = 0.7) -> Float {
            let prev = c.smoothedUniforms[key] ?? raw
            let next = alpha * prev + (1.0 - alpha) * raw
            c.smoothedUniforms[key] = next
            return next
        }

        // --- Face : mouth_open, eye_open_l/r, head_tilt, head_yaw ---
        var rawMouth: Float = 0
        var rawEyeL: Float = 0
        var rawEyeR: Float = 0
        var rawTilt: Float = 0
        var rawYaw: Float = 0
        if let face = poseListener.faces.values.first {
            let pts = face.points
            let has = face.hasPoint
            // dlib 68 : upper inner lip 51, lower inner lip 57
            if has[51] && has[57] {
                rawMouth = abs(pts[51].y - pts[57].y)
            }
            // Eye L : 36..41, Eye R : 42..47
            func eyeRatio(_ a: Int, _ b: Int) -> Float {
                var xs: [Float] = []
                var ys: [Float] = []
                for i in a...b where has[i] {
                    xs.append(pts[i].x)
                    ys.append(pts[i].y)
                }
                guard let mxX = xs.max(), let mnX = xs.min(),
                      let mxY = ys.max(), let mnY = ys.min() else {
                    return 0
                }
                let w = max(mxX - mnX, 1e-4)
                let h = mxY - mnY
                return h / w
            }
            rawEyeL = eyeRatio(36, 41)
            rawEyeR = eyeRatio(42, 47)
            // head_tilt : line eyeL_center -> eyeR_center
            if has[36] && has[45] {
                let dy = pts[45].y - pts[36].y
                let dx = pts[45].x - pts[36].x
                rawTilt = atan2(dy, dx)
            }
            // head_yaw proxy : nose(30) vs eye midpoint y
            if has[30] && has[36] && has[45] {
                let midY = (pts[36].y + pts[45].y) * 0.5
                rawYaw = (pts[30].y - midY) * 4.0  // amplify
            }
        }
        c.sceneRenderer?.uniforms.mouth_open = ema("mouth", rawMouth)
        c.sceneRenderer?.uniforms.eye_open_l = ema("eyeL", rawEyeL)
        c.sceneRenderer?.uniforms.eye_open_r = ema("eyeR", rawEyeR)
        c.sceneRenderer?.uniforms.head_tilt = ema("tilt", rawTilt)
        c.sceneRenderer?.uniforms.head_yaw = ema("yaw", rawYaw)

        // --- Hands : finger_pinch_l, finger_pinch_r ---
        // MediaPipe : 4 = thumb_tip, 8 = index_tip ; side : 0=L, 1=R.
        var rawPinchL: Float = 0
        var rawPinchR: Float = 0
        for h in poseListener.hands.values {
            guard h.hasPoint[4] && h.hasPoint[8] else { continue }
            let d = simd_distance(h.points[4], h.points[8])
            if h.side == 0 { rawPinchL = d } else { rawPinchR = d }
        }
        c.sceneRenderer?.uniforms.finger_pinch_l = ema("pinchL", rawPinchL)
        c.sceneRenderer?.uniforms.finger_pinch_r = ema("pinchR", rawPinchR)

        // --- Body3D : pelvis pos, body_height, arm_spread, velocity ---
        // MediaPipe : 23 left_hip, 24 right_hip ; 0 nose ;
        // 15 left_wrist, 16 right_wrist.
        var rawBX: Float = 0, rawBY: Float = 0, rawBZ: Float = 0
        var rawHeight: Float = 0, rawSpread: Float = 0
        var rawVel: Float = 0
        if let body = poseListener.body3d.values.first {
            let kp = body.kps
            let has = body.hasPoint
            if has[23] && has[24] {
                let pelvis = SIMD3<Float>(
                    (kp[23].x + kp[24].x) * 0.5,
                    (kp[23].y + kp[24].y) * 0.5,
                    (kp[23].z + kp[24].z) * 0.5)
                rawBX = pelvis.x
                rawBY = pelvis.y
                rawBZ = pelvis.z
                // Velocity : EMA of delta magnitude (alpha=0.3)
                if let last = c.lastPelvis {
                    let dist = simd_distance(pelvis, last)
                    c.poseVelocityEMA = 0.3 * c.poseVelocityEMA + 0.7 * dist
                }
                c.lastPelvis = pelvis
                rawVel = c.poseVelocityEMA
                if has[0] {
                    // body_height : pelvis.y - head.y (MP y points down so
                    // head < pelvis ; take abs).
                    rawHeight = abs(pelvis.y - kp[0].y)
                }
            }
            if has[15] && has[16] {
                rawSpread = abs(kp[15].x - kp[16].x)
            }
        } else {
            c.lastPelvis = nil
            c.poseVelocityEMA *= 0.9  // decay
        }
        c.sceneRenderer?.uniforms.body_x = ema("bx", rawBX)
        c.sceneRenderer?.uniforms.body_y = ema("by", rawBY)
        c.sceneRenderer?.uniforms.body_z = ema("bz", rawBZ)
        c.sceneRenderer?.uniforms.body_height = ema("bh", rawHeight)
        c.sceneRenderer?.uniforms.arm_spread = ema("spread", rawSpread)
        c.sceneRenderer?.uniforms.pose_velocity = ema("vel", rawVel, alpha: 0.5)
        c.container?.layer?.backgroundColor = NSColor(
            white: CGFloat(settings.bgBrightness), alpha: 1.0).cgColor
        c.cameraEntity?.camera.fieldOfViewInDegrees =
            Float(settings.fieldOfView)
        c.keyLight?.light.intensity = Float(settings.keyIntensity)
        c.fillLight?.light.intensity = Float(settings.fillIntensity)
        c.rimLight?.light.intensity = Float(settings.rimIntensity)

        // Mesh visibility + material
        guard let anchor = c.bodyAnchor else { return }
        anchor.children.removeAll()
        if settings.showMesh {
            renderer.applyMaterialSettings(
                metallic: settings.meshMetallic,
                roughness: Float(settings.meshRoughness))
            renderer.applyWireframeSetting(settings.showWireframe)
            for entity in renderer.personEntities.values {
                anchor.addChild(entity)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var bodyAnchor: AnchorEntity?
        var arView: ARView?
        var cameraEntity: PerspectiveCamera?
        var sceneRenderer: SceneRenderer?
        var mtkView: MTKView?
        var skeletonOverlay: SkeletonOverlay?
        var skel3dAnchor: AnchorEntity?
        var skel3d: Skeleton3DRenderer?
        var kbMonitor: Any?
        // ---- Pose-derived smoothing state (alpha-beta EMA) ----
        // EMA alpha=0.7, beta=0.05 (velocity correction).
        var smoothedUniforms: [String: Float] = [:]
        var lastPelvis: SIMD3<Float>?
        var poseVelocityEMA: Float = 0

        deinit {
            if let m = kbMonitor {
                NSEvent.removeMonitor(m)
            }
        }
        var keyLight: DirectionalLight?
        var fillLight: DirectionalLight?
        var rimLight: DirectionalLight?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var container: NSView?
        var renderer: MeshRenderer?
    }
}
