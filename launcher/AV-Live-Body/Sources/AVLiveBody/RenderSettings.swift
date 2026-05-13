import Cocoa
import SwiftUI

/// Reglages visuels live de AV-Live-Body. Publies en SwiftUI ; le
/// BodyView observe et propage les changements vers les layers et
/// l'ARView a chaque updateNSView.
@MainActor
final class RenderSettings: ObservableObject {
    // Camera preview
    @Published var showCamera: Bool = true
    @Published var camOpacity: Double = 0.35

    // Background
    @Published var bgBrightness: Double = 0.08

    // Metal scene background (10 viz modes : storm/tunnel/.../openpos)
    @Published var showScene: Bool = true
    @Published var vizMode: Int = 0   // 0..9
    var vizModeName: String {
        let names = ["storm", "tunnel", "plasma", "kaleido", "voronoi",
                     "metaballs", "starfield", "bars", "hands3d", "openpos"]
        return names.indices.contains(vizMode) ? names[vizMode] : "?"
    }

    // Mesh visibility / style
    @Published var showMesh: Bool = true
    @Published var showWireframe: Bool = false
    @Published var showSkeleton: Bool = false
    @Published var meshMetallic: Bool = false
    @Published var meshRoughness: Double = 0.6

    // Lights
    @Published var keyIntensity: Double = 4000
    @Published var fillIntensity: Double = 1500
    @Published var rimIntensity: Double = 2000

    // Camera RealityKit
    @Published var fieldOfView: Double = 60

    // Settings panel visibility
    @Published var showPanel: Bool = false
}
