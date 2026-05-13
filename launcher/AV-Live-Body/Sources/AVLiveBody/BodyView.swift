import AVFoundation
import RealityKit
import SwiftUI

/// Wrapper SwiftUI : webcam en BACKGROUND LEGER (opacite ~0.35) +
/// ARView transparent par-dessus avec mesh SMPL-X. Le mesh reste
/// l'element visuel dominant, la cam donne du contexte sans manger
/// l'attention.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer = CALayer()
        container.layer?.backgroundColor = NSColor(white: 0.08,
                                                    alpha: 1.0).cgColor

        // 1. Camera preview, opacite reduite -> overlay leger
        let camera = CameraPreviewLayer()
        _ = camera.start()
        let preview = camera.previewLayer
        preview.frame = container.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        preview.opacity = 0.35
        container.layer?.addSublayer(preview)
        context.coordinator.camera = camera

        // 2. ARView transparent par-dessus
        let arView = ARView(frame: container.bounds)
        arView.environment.background = .color(.clear)
        arView.autoresizingMask = [.width, .height]
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 60
        let camAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        camAnchor.addChild(cam)
        arView.scene.addAnchor(camAnchor)

        // 3 lumieres + ambient pour le relief du mesh
        let key = DirectionalLight()
        key.light.intensity = 4000
        key.orientation = simd_quatf(angle: .pi / 6, axis: SIMD3(1, 0, 0))
        let keyAnchor = AnchorEntity(world: SIMD3<Float>(1, 2, -1))
        keyAnchor.addChild(key)
        arView.scene.addAnchor(keyAnchor)

        let fill = DirectionalLight()
        fill.light.intensity = 1500
        fill.light.color = NSColor(red: 0.7, green: 0.8, blue: 1.0,
                                    alpha: 1.0)
        let fillAnchor = AnchorEntity(world: SIMD3<Float>(-2, 1, -2))
        fillAnchor.addChild(fill)
        arView.scene.addAnchor(fillAnchor)

        let rim = DirectionalLight()
        rim.light.intensity = 2000
        let rimAnchor = AnchorEntity(world: SIMD3<Float>(0, 1, -5))
        rimAnchor.addChild(rim)
        arView.scene.addAnchor(rimAnchor)

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
