import AVFoundation
import RealityKit
import SwiftUI

/// Wrapper SwiftUI : webcam en BACKGROUND LEGER (opacite controlable)
/// + ARView transparent par-dessus avec mesh SMPL-X. Toutes les
/// valeurs visuelles (cam opacity, bg, lights, FOV...) sont pilotees
/// en live par RenderSettings.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer
    @ObservedObject var settings: RenderSettings

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
        context.coordinator.keyLight = key
        context.coordinator.fillLight = fill
        context.coordinator.rimLight = rim
        context.coordinator.previewLayer = preview
        context.coordinator.container = container
        context.coordinator.renderer = renderer
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {
        let c = context.coordinator
        // Apply live settings
        c.previewLayer?.opacity = Float(settings.camOpacity)
        c.previewLayer?.isHidden = !settings.showCamera
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
        var keyLight: DirectionalLight?
        var fillLight: DirectionalLight?
        var rimLight: DirectionalLight?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var container: NSView?
        var renderer: MeshRenderer?
    }
}
