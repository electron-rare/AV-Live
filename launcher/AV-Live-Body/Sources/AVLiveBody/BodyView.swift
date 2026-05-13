import AVFoundation
import RealityKit
import SwiftUI

/// Wrapper SwiftUI : NSView container avec AVCaptureVideoPreviewLayer
/// en backing (webcam) et ARView en surcouche pour les meshes SMPL-X.
/// Le background de l'ARView est transparent pour laisser passer la cam.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer = CALayer()
        container.layer?.backgroundColor = NSColor.black.cgColor

        // 1. Camera preview layer en backing
        let camera = CameraPreviewLayer()
        _ = camera.start()
        let preview = camera.previewLayer
        preview.frame = container.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        container.layer?.addSublayer(preview)
        context.coordinator.camera = camera

        // 2. ARView par-dessus, background clear pour voir la cam
        let arView = ARView(frame: container.bounds)
        arView.environment.background = .color(.clear)
        arView.autoresizingMask = [.width, .height]
        let cam = PerspectiveCamera()
        // FOV horizontal ~60deg matche le Multi-HMR fovn=60 ; on
        // place la cam a l'origine (RK regarde naturellement -Z).
        cam.camera.fieldOfViewInDegrees = 60
        let camAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        camAnchor.addChild(cam)
        arView.scene.addAnchor(camAnchor)
        // Lumiere directionnelle pour que le mesh ne soit pas noir
        let light = DirectionalLight()
        light.light.intensity = 5000
        let lightAnchor = AnchorEntity(world: SIMD3<Float>(0, 1, -1))
        lightAnchor.addChild(light)
        arView.scene.addAnchor(lightAnchor)
        let bodyAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(bodyAnchor)
        container.addSubview(arView)

        context.coordinator.bodyAnchor = bodyAnchor
        context.coordinator.arView = arView
        context.coordinator.renderer = renderer
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let anchor = context.coordinator.bodyAnchor else { return }
        anchor.children.removeAll()
        for entity in renderer.personEntities.values {
            anchor.addChild(entity)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var bodyAnchor: AnchorEntity?
        var arView: ARView?
        var renderer: MeshRenderer?
        var camera: CameraPreviewLayer?
    }
}
