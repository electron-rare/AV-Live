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

    // Mesh visibility / style
    @Published var showMesh: Bool = true
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
