import RealityKit
import SwiftUI

/// Wrapper SwiftUI autour de ARView contenant les meshes SMPL-X.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer

    func makeNSView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.environment.background = .color(.black)
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 60
        let camAnchor = AnchorEntity(world: SIMD3(0, 0, 2))
        camAnchor.addChild(cam)
        view.scene.addAnchor(camAnchor)
        let bodyAnchor = AnchorEntity(world: .zero)
        view.scene.addAnchor(bodyAnchor)
        context.coordinator.bodyAnchor = bodyAnchor
        context.coordinator.renderer = renderer
        return view
    }

    func updateNSView(_ view: ARView, context: Context) {
        guard let anchor = context.coordinator.bodyAnchor else { return }
        anchor.children.removeAll()
        for entity in renderer.personEntities.values {
            anchor.addChild(entity)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var bodyAnchor: AnchorEntity?
        var renderer: MeshRenderer?
    }
}
