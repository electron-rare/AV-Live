// avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift
import SwiftUI

/// Live visual settings for AVLiveBody. ContentView observes this and
/// pushes changes to SceneController. Defaults chosen so the scene is
/// lit and everything visible out of the box.
@MainActor
final class RenderSettings: ObservableObject {
    // Layer visibility
    @Published var showSkeleton: Bool = true
    @Published var showMesh: Bool = true
    @Published var showVideo: Bool = true

    // Mesh material
    @Published var meshMetallic: Bool = false
    @Published var meshRoughness: Double = 0.6

    // Video quad
    @Published var videoOpacity: Double = 1.0

    // Lights (RealityKit DirectionalLight intensities)
    @Published var keyIntensity: Double = 4000
    @Published var fillIntensity: Double = 1500
    @Published var rimIntensity: Double = 2000

    // Camera
    @Published var fieldOfView: Double = 55

    // Panel visibility
    @Published var showPanel: Bool = false

    // Metal shader background (Phase 2)
    @Published var showScene: Bool = true
    @Published var vizMode: Int = 0   // 0..9
}
