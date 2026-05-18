import ARKit
import AVLiveWire
import Combine
import Foundation
import RealityKit
import SwiftUI

/// Drives the ARKit body-tracking session and broadcasts joints to
/// GrosMac via OSC UDP. Two destinations are supported simultaneously :
/// - Python `IphoneOSCListener` on :57128 (drives ArkitFuse + cam-z lock)
/// - Swift `ArkitOSCListener` on :57129 (diagnostic overlay in AVLiveBody)
///
/// LiDAR (sceneDepth + scene reconstruction mesh) is enabled when the
/// device supports it (iPhone Pro / Pro Max). RGB-only fallback on
/// non-LiDAR devices.
/// Lightweight 2D snapshot of the tracked skeleton, ready for SwiftUI
/// Canvas. Joint indices follow `ARSkeletonDefinition.defaultBody3D`.
struct SkeletonSnapshot: Equatable {
    /// Projected joint positions in viewport coordinates, or nil if the
    /// joint falls outside the view / is not finite.
    let points: [CGPoint?]
    /// Per-joint tracking flag (`ARSkeleton.isJointTracked`).
    let tracked: [Bool]
}

@MainActor
final class ARBodySession: NSObject, ObservableObject, ARSessionDelegate {
    @Published var running: Bool = false
    @Published var status: String = "idle"
    @Published var framesSent: Int = 0
    @Published var jointsPerSec: Double = 0
    @Published var bodyCount: Int = 0
    @Published var skeleton2D: SkeletonSnapshot?
    @Published var usbState: USBServer.State = .idle
    /// Set by the SwiftUI view via GeometryReader so the projection
    /// matches the on-screen ARView size.
    var viewportSize: CGSize = .zero
    private var sendEnvMesh: Bool = false
    private let session = ARSession()
    private let usb = USBServer()
    private let videoEncoder = VideoEncoder()
    private var videoStarted = false
    private var lastFrameTime: TimeInterval = 0
    private var jointsInSecond: Int = 0
    private var lastSecond: TimeInterval = 0
    private let bodyParents: [Int] =
        ARSkeletonDefinition.defaultBody3D.parentIndices

    let arView = ARView(frame: .zero)

    override init() {
        super.init()
        arView.session = session
        arView.session.delegate = self
        arView.environment.background = .color(.black)
        arView.debugOptions = []
        usb.onState = { [weak self] s in
            Task { @MainActor in self?.usbState = s }
        }
        videoEncoder.onPayload = { [weak self] payload in
            Task { @MainActor in
                guard let self, self.usbState == .connected else {
                    return
                }
                self.usb.send(tag: .video, pid: -1,
                              timestamp: self.lastFrameTime,
                              payload: payload.encoded())
            }
        }
    }

    func configure(sendEnvMesh: Bool) {
        self.sendEnvMesh = sendEnvMesh
    }

    func start() {
        guard ARBodyTrackingConfiguration.isSupported else {
            status = "ARBodyTracking unsupported (need A12+, iPhone XR/XS+)"
            return
        }
        let cfg = ARBodyTrackingConfiguration()
        var feats: [String] = []
        // No extra frame semantics: `.sceneDepth` is reserved to
        // ARWorldTracking, and `.personSegmentationWithDepth` is
        // rejected per-frame by ABPKPersonIDTracker in this config
        // (spams the console without producing usable depth).
        // NOTE: ARBodyTrackingConfiguration does not expose
        // sceneReconstruction (that's ARWorldTrackingConfiguration
        // territory). Env mesh capture requires a separate ARSession
        // with body tracking off — out of scope for this scaffold.
        if sendEnvMesh {
            feats.append("env-mesh: requires separate session (TODO)")
        }
        cfg.automaticImageScaleEstimationEnabled = true
        usb.start()
        session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        status = feats.isEmpty
            ? "running (RGB only)"
            : "running (\(feats.joined(separator: ", ")))"
        running = true
    }

    func stop() {
        session.pause()
        usb.stop()
        videoEncoder.stop()
        videoStarted = false
        running = false
        status = "stopped"
    }

    // MARK: - ARSessionDelegate

    nonisolated func session(_ s: ARSession, didUpdate frame: ARFrame) {
        let t = frame.timestamp
        Task { @MainActor in
            // Throttle to 30 fps max.
            if t - self.lastFrameTime < 1.0 / 30.0 { return }
            self.lastFrameTime = t

            // Encode the camera frame to HEVC and stream it over USB.
            let img = frame.capturedImage
            let w = Int32(CVPixelBufferGetWidth(img))
            let h = Int32(CVPixelBufferGetHeight(img))
            if !self.videoStarted, w > 0, h > 0 {
                self.videoEncoder.start(width: w, height: h)
                self.videoStarted = true
            }
            if self.videoStarted {
                self.videoEncoder.encode(img, pts: t)
            }

            var count: Int = 0
            var firstBody: ARBodyAnchor?
            for anchor in frame.anchors {
                guard let body = anchor as? ARBodyAnchor else { continue }
                self.publishUSB(pid: count, timestamp: t, body: body)
                if count == 0 { firstBody = body }
                count += 1
            }
            self.framesSent &+= 1
            self.bodyCount = count
            self.updateSkeleton2D(body: firstBody, camera: frame.camera)

            let now = Date().timeIntervalSinceReferenceDate
            self.jointsInSecond &+= count * 91
            if now - self.lastSecond >= 1.0 {
                self.jointsPerSec = Double(self.jointsInSecond)
                    / max(0.001, now - self.lastSecond)
                self.jointsInSecond = 0
                self.lastSecond = now
            }
        }
    }

    private func currentInterfaceOrientation() -> UIInterfaceOrientation {
        for scene in UIApplication.shared.connectedScenes {
            if let ws = scene as? UIWindowScene {
                return ws.interfaceOrientation
            }
        }
        return .portrait
    }

    private func updateSkeleton2D(body: ARBodyAnchor?, camera: ARCamera) {
        guard let body, viewportSize.width > 1, viewportSize.height > 1
        else {
            if skeleton2D != nil { skeleton2D = nil }
            return
        }
        let xforms = body.skeleton.jointModelTransforms
        let root = body.transform
        let orient = currentInterfaceOrientation()
        var pts: [CGPoint?] = Array(repeating: nil, count: xforms.count)
        var tracked: [Bool] = Array(repeating: false, count: xforms.count)
        for (i, m) in xforms.enumerated() {
            let w = root * m
            let p3 = simd_make_float3(w.columns.3.x,
                                      w.columns.3.y,
                                      w.columns.3.z)
            let p2 = camera.projectPoint(p3,
                                         orientation: orient,
                                         viewportSize: viewportSize)
            if p2.x.isFinite && p2.y.isFinite { pts[i] = p2 }
            tracked[i] = body.skeleton.isJointTracked(i)
        }
        skeleton2D = SkeletonSnapshot(points: pts, tracked: tracked)
    }

    /// Exposed for SwiftUI overlays that need to wire bone parent
    /// indices without re-reading the ARKit skeleton definition.
    var bodyParentIndices: [Int] { bodyParents }

    private func publishUSB(pid: Int, timestamp: TimeInterval,
                             body: ARBodyAnchor) {
        guard usbState == .connected else { return }
        let skeleton = body.skeleton
        let transforms = skeleton.jointModelTransforms
        let root = body.transform
        var payload = SkeletonPayload()
        let n = min(SkeletonPayload.jointCount, transforms.count)
        for i in 0..<n {
            let w = root * transforms[i]
            payload.joints[i] = SIMD3(w.columns.3.x,
                                      w.columns.3.y,
                                      w.columns.3.z)
            payload.valid[i] = skeleton.isJointTracked(i)
        }
        usb.send(tag: .skeleton,
                 pid: Int16(clamping: pid),
                 timestamp: timestamp,
                 payload: payload.encoded())
    }

}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var session: ARBodySession
    func makeUIView(context: Context) -> ARView { session.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
