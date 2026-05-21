import RealityKit
import SwiftUI

/// SwiftUI bridge that hands the SceneController's ARView to the
/// window and runs `setUp()` once.
struct SceneView: NSViewRepresentable {
    let controller: SceneController

    func makeNSView(context: Context) -> ARView {
        controller.setUp()
        return controller.arView
    }

    func updateNSView(_ view: ARView, context: Context) {}
}
