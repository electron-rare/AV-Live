// avlivebody-mac/Sources/AVLiveBody/LayeredSceneView.swift
import AppKit
import MetalKit
import RealityKit
import SwiftUI

/// Layered container: MTKView (Metal shader bg, transparent) behind the
/// SceneController's transparent ARView. The owner holds the SceneRenderer
/// so it can push uniforms each frame.
struct LayeredSceneView: NSViewRepresentable {
    let controller: SceneController
    let renderer: SceneRenderer?

    func makeNSView(context: Context) -> NSView {
        controller.setUp()
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor

        if let renderer {
            let mtk = MTKView(frame: container.bounds,
                              device: MTLCreateSystemDefaultDevice())
            mtk.delegate = renderer
            mtk.colorPixelFormat = .bgra8Unorm
            mtk.framebufferOnly = false
            mtk.layer?.isOpaque = true
            mtk.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            mtk.preferredFramesPerSecond = 60
            mtk.autoresizingMask = [.width, .height]
            container.addSubview(mtk)
            context.coordinator.mtk = mtk
        }

        let arView = controller.arView
        arView.frame = container.bounds
        arView.autoresizingMask = [.width, .height]
        arView.wantsLayer = true
        arView.layer?.isOpaque = false
        arView.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(arView)   // front
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.mtk?.isHidden = false   // visibility via showScene handled by caller setting renderer.uniforms / hidden
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var mtk: MTKView? }
}
