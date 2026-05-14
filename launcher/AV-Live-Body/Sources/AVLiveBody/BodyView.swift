import AppKit
import AVFoundation
import MetalKit
import RealityKit
import SwiftUI

/// Wrapper SwiftUI : webcam en BACKGROUND LEGER (opacite controlable)
/// + ARView transparent par-dessus avec mesh SMPL-X. Toutes les
/// valeurs visuelles (cam opacity, bg, lights, FOV...) sont pilotees
/// en live par RenderSettings.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer
    @ObservedObject var settings: RenderSettings
    @ObservedObject var poseListener: PoseOSCListener
    @ObservedObject var arkitListener: ArkitOSCListener

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
        skel3d.attach(to: skel3dAnchor, listener: poseListener,
                      arkitListener: arkitListener)
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
