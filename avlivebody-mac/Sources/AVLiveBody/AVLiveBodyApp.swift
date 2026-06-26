import Cocoa
import CoreVideo
import SwiftUI

/// Forces a regular, keyboard-focusable foreground app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
}

@main
struct AVLiveBodyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

@MainActor
struct ContentView: View {
    @StateObject private var consumer = USBSkeletonConsumer()
    @StateObject private var settings = RenderSettings()
    @State private var prevPelvis: SIMD3<Float>?
    private let controller = SceneController()
    private let renderer = SceneRenderer.make()
    /// Multi-HMR mesh inference (CoreML, ~150-300 ms/frame) is OFF by
    /// default: it would saturate the main thread and beachball the UI.
    /// Skeleton-only rendering (iPhone 91-joint ARKit stream) otherwise.
    /// Enable on a capable, properly-threaded host with AVBODY_MULTIHMR=1.
    private let multiHMR: MultiHMRCoreML? = {
        guard ProcessInfo.processInfo.environment["AVBODY_MULTIHMR"] == "1"
        else { return nil }
        return MultiHMRCoreML()
    }()
    /// Placeholder intrinsics until a `.meta` frame supplies real ones.
    private let cameraK: [Float] = [
        672, 0, 336, 0, 672, 336, 0, 0, 1,
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LayeredSceneView(controller: controller, renderer: renderer,
                             showScene: settings.showScene)
            StatusBar(consumer: consumer)
                .frame(maxWidth: .infinity, alignment: .top)
            HStack(alignment: .top) {
                Spacer()
                if settings.showPanel {
                    SettingsPanel(settings: settings)
                        .transition(.move(edge: .trailing))
                }
                Button {
                    withAnimation { settings.showPanel.toggle() }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .padding(8)
            }
        }
        .onAppear { wire(); applyAll() }
        .onDisappear { consumer.stop() }
        .onReceive(consumer.$skeletons) { skeletons in
            controller.updateSkeleton(skeletons)
            pushUniforms()
        }
        .onReceive(consumer.$hands) { _ in pushUniforms() }
        .onReceive(consumer.$face) { _ in pushUniforms() }
        .onReceive(settings.objectWillChange) { _ in
            // objectWillChange fires before the value updates; apply on
            // the next runloop tick so we read the new values.
            DispatchQueue.main.async { applyAll() }
        }
    }

    private func applyAll() {
        controller.setSkeletonVisible(settings.showSkeleton)
        controller.setMeshVisible(settings.showMesh)
        controller.setVideoVisible(settings.showVideo)
        controller.setVideoOpacity(settings.videoOpacity)
        controller.updateMeshMaterial(metallic: settings.meshMetallic,
                                      roughness: settings.meshRoughness)
        controller.setLightIntensities(key: settings.keyIntensity,
                                       fill: settings.fillIntensity,
                                       rim: settings.rimIntensity)
        controller.setFieldOfView(settings.fieldOfView)
        if let r = renderer {
            r.uniforms.viz_mode = Float(settings.vizMode)
        }
    }

    private func pushUniforms() {
        guard let r = renderer else { return }
        r.uniforms.viz_mode = Float(settings.vizMode)
        SceneUniformBuilder.fill(&r.uniforms,
                                 skeletons: consumer.skeletons,
                                 hands: consumer.hands,
                                 face: consumer.face,
                                 prevPelvis: &prevPelvis)
        controller.updateHandFace(hands: consumer.hands, face: consumer.face)
    }

    private func wire() {
        let controller = self.controller
        let multiHMR = self.multiHMR
        let cameraK = self.cameraK
        consumer.onVideoFrame = { [weak consumer] pixelBuffer in
            MainActor.assumeIsolated {
                controller.updateVideo(pixelBuffer)
                guard let consumer, let hmr = multiHMR else { return }
                // Snapshot skeletons on main; run the heavy CoreML
                // prediction off-main (drops frames if busy), then hop
                // back to main for the light fuse + mesh UI update.
                let skeletons = consumer.skeletons
                hmr.inferAsync(pixelBuffer, cameraK: cameraK) { raw in
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            let fused = BodyFusion.fuse(
                                persons: raw,
                                skeletons: skeletons)
                            controller.updateMesh(fused)
                        }
                    }
                }
            }
        }
        consumer.start()
    }
}
