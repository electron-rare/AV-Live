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
    private let controller = SceneController()
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
        ZStack(alignment: .top) {
            SceneView(controller: controller)
            StatusBar(consumer: consumer)
        }
        .onAppear { wire() }
        .onDisappear { consumer.stop() }
        .onReceive(consumer.$skeletons) { skeletons in
            controller.updateSkeleton(skeletons)
        }
    }

    private func wire() {
        let controller = self.controller
        let multiHMR = self.multiHMR
        let cameraK = self.cameraK
        consumer.onVideoFrame = { [weak consumer] pixelBuffer in
            MainActor.assumeIsolated {
                controller.updateVideo(pixelBuffer)
                guard let consumer else { return }
                if let hmr = multiHMR {
                    let raw = hmr.infer(
                        pixelBuffer, cameraK: cameraK)
                    let fused = BodyFusion.fuse(
                        persons: raw,
                        skeletons: consumer.skeletons)
                    controller.updateMesh(fused)
                }
            }
        }
        consumer.start()
    }
}
