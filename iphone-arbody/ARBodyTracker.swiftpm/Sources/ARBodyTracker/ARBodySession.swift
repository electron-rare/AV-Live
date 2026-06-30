import ARKit
import AVLiveWire
import Combine
import Foundation
import RealityKit
import SwiftUI
import Vision

/// Drives the ARKit body-tracking session and streams the 91-joint
/// skeleton plus HEVC-encoded camera video to the tethered Mac over
/// USB (AVLiveWire frames via usbmuxd). No network involved.
///
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
    @Published var arkitFps: Double = 0
    @Published var visionMs: Double = 0
    @Published var visionDropRate: Double = 0
    @Published var thermalLabel: String = "nominal"
    /// Set by the SwiftUI view via GeometryReader so the projection
    /// matches the on-screen ARView size.
    var viewportSize: CGSize = .zero
    private var sendEnvMesh: Bool = false
    private let session = ARSession()
    private let usb = USBServer()
    private let videoEncoder = VideoEncoder()
    private var videoStarted = false
    private var lastFrameTime: TimeInterval = 0
    private let visionQueue = DispatchQueue(
        label: "cc.saillant.arbody.vision", qos: .userInitiated)
    private var visionBusy = false
    private var lastVisionTime: TimeInterval = 0
    private var visionAttempts: Int = 0
    private var visionDrops: Int = 0
    private var jointsInSecond: Int = 0
    private var lastSecond: TimeInterval = 0
    private let bodyParents: [Int] =
        ARSkeletonDefinition.defaultBody3D.parentIndices

    let arView = ARView(frame: .zero)

    nonisolated static func thermalString(
        _ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "?"
        }
    }

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
        thermalLabel = Self.thermalString(
            ProcessInfo.processInfo.thermalState)
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.thermalLabel = Self.thermalString(
                    ProcessInfo.processInfo.thermalState)
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
            let dt = t - self.lastFrameTime
            if dt < 1.0 / 30.0 { return }
            self.lastFrameTime = t
            if dt > 0, dt < 1.0 {
                let inst = 1.0 / dt
                self.arkitFps = self.arkitFps == 0
                    ? inst : self.arkitFps * 0.9 + inst * 0.1
            }

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

            // Vision hands+face at ~15 fps, off-main, drop if busy.
            if t - self.lastVisionTime >= 1.0 / 15.0 {
                self.visionAttempts += 1
                if self.visionBusy {
                    self.visionDrops += 1
                } else {
                    self.lastVisionTime = t
                    self.visionBusy = true
                    let buf = img   // CVPixelBuffer captured for the worker
                    self.visionQueue.async {
                        self.runVision(on: buf, timestamp: t)
                        Task { @MainActor in self.visionBusy = false }
                    }
                }
                if self.visionAttempts >= 60 {
                    self.visionDropRate =
                        Double(self.visionDrops) / Double(self.visionAttempts)
                    self.visionAttempts = 0
                    self.visionDrops = 0
                }
            }

            var count: Int = 0
            var firstBody: ARBodyAnchor?
            for anchor in frame.anchors {
                guard let body = anchor as? ARBodyAnchor else { continue }
                self.publishUSB(pid: count, timestamp: t, body: body,
                                camera: frame.camera)
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

    // MARK: - Vision hand + face capture

    nonisolated func runVision(on pixelBuffer: CVPixelBuffer,
                               timestamp t: TimeInterval) {
        let handReq = VNDetectHumanHandPoseRequest()
        handReq.maximumHandCount = 2
        let faceReq = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        let t0 = Date()
        try? handler.perform([handReq, faceReq])
        let ms = Date().timeIntervalSince(t0) * 1000.0
        Task { @MainActor in
            self.visionMs = self.visionMs == 0
                ? ms : self.visionMs * 0.8 + ms * 0.2
        }

        // ---- hands ----
        // Fixed 21-joint order matching MediaPipe-style indexing.
        let order: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip,
        ]
        var handsOut: [HandsPayload.Hand] = []
        for obs in (handReq.results ?? []).prefix(2) {
            guard let pts = try? obs.recognizedPoints(.all) else { continue }
            let p = order.map { name -> SIMD3<Float> in
                if let rp = pts[name] {
                    // Vision: normalized, bottom-left origin -> flip y.
                    return SIMD3(Float(rp.location.x),
                                 Float(1.0 - rp.location.y),
                                 Float(rp.confidence))
                }
                return .zero
            }
            handsOut.append(HandsPayload.Hand(
                isRight: obs.chirality == .right, points: p))
        }

        // ---- face (most prominent) ----
        var facePayload: FacePayload?
        if let face = (faceReq.results ?? []).first,
           let all = face.landmarks?.allPoints {
            let bb = face.boundingBox
            let pts = all.normalizedPoints.map { np -> SIMD2<Float> in
                // landmark points are relative to the face bbox.
                let x = bb.origin.x + Double(np.x) * bb.size.width
                let y = bb.origin.y + Double(np.y) * bb.size.height
                return SIMD2(Float(x), Float(1.0 - y))
            }
            facePayload = FacePayload(
                confidence: face.confidence, points: pts)
        }

        let handsData = HandsPayload(hands: handsOut).encoded()
        let faceData = facePayload?.encoded()
        Task { @MainActor in
            guard self.usbState == .connected else { return }
            self.usb.send(tag: .hands, pid: -1,
                          timestamp: t, payload: handsData)
            if let faceData {
                self.usb.send(tag: .face, pid: -1,
                              timestamp: t, payload: faceData)
            }
        }
    }

    // MARK: - USB skeleton

    private func publishUSB(pid: Int, timestamp: TimeInterval,
                             body: ARBodyAnchor, camera: ARCamera) {
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

        // 2D projected skeleton: viewport-normalized [0,1] coords per joint.
        var p2 = Skeleton2DPayload()
        let orient = currentInterfaceOrientation()
        for i in 0..<min(Skeleton2DPayload.jointCount, transforms.count) {
            let w = root * transforms[i]
            let p3 = SIMD3<Float>(w.columns.3.x, w.columns.3.y, w.columns.3.z)
            let proj = camera.projectPoint(p3,
                                           orientation: orient,
                                           viewportSize: viewportSize)
            let nx = Float(proj.x / max(viewportSize.width, 1))
            let ny = Float(proj.y / max(viewportSize.height, 1))
            if nx.isFinite && ny.isFinite {
                p2.points[i] = SIMD2<Float>(nx, ny)
                p2.valid[i] = skeleton.isJointTracked(i)
            }
        }
        usb.send(tag: .skeleton2D,
                 pid: Int16(clamping: pid),
                 timestamp: timestamp,
                 payload: p2.encoded())
    }

}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var session: ARBodySession
    func makeUIView(context: Context) -> ARView { session.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
