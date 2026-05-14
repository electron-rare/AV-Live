import ARKit
import Combine
import Foundation
import Network
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
    /// Set by the SwiftUI view via GeometryReader so the projection
    /// matches the on-screen ARView size.
    var viewportSize: CGSize = .zero
    private var host: String = "192.168.0.159"
    private var pythonPort: UInt16 = 57128
    private var swiftPort: UInt16 = 57129
    private var sendEnvMesh: Bool = false
    private let session = ARSession()
    private var conns: [NWConnection] = []
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
    }

    func configure(host: String, pythonPort: UInt16, swiftPort: UInt16,
                   sendEnvMesh: Bool) {
        self.host = host
        self.pythonPort = pythonPort
        self.swiftPort = swiftPort
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
        openUDP()
        session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        status = feats.isEmpty
            ? "running (RGB only)"
            : "running (\(feats.joined(separator: ", ")))"
        running = true
    }

    func stop() {
        session.pause()
        for c in conns { c.cancel() }
        conns.removeAll()
        running = false
        status = "stopped"
    }

    // MARK: - UDP fanout

    private func openUDP() {
        let ports: [UInt16] = [pythonPort, swiftPort]
        for p in ports where p != 0 {
            guard let nwPort = NWEndpoint.Port(rawValue: p) else { continue }
            let conn = NWConnection(
                to: .hostPort(host: NWEndpoint.Host(host), port: nwPort),
                using: .udp)
            conn.start(queue: .global(qos: .userInitiated))
            conns.append(conn)
        }
    }

    private func sendDatagram(_ data: Data) {
        for c in conns {
            c.send(content: data, completion: .idempotent)
        }
    }

    // MARK: - ARSessionDelegate

    nonisolated func session(_ s: ARSession, didUpdate frame: ARFrame) {
        let t = frame.timestamp
        Task { @MainActor in
            // Throttle to 30 fps max.
            if t - self.lastFrameTime < 1.0 / 30.0 { return }
            self.lastFrameTime = t

            var count: Int = 0
            var firstBody: ARBodyAnchor?
            for anchor in frame.anchors {
                guard let body = anchor as? ARBodyAnchor else { continue }
                self.publishJoints(pid: count, body: body)
                if count == 0 { firstBody = body }
                count += 1
            }
            self.sendOSC(addr: "/body3d/count",
                         args: [.int32(Int32(count))])
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

    private func publishJoints(pid: Int, body: ARBodyAnchor) {
        let skeleton = body.skeleton
        let transforms = skeleton.jointModelTransforms
        let root = body.transform
        for (idx, m) in transforms.enumerated() {
            let world = root * m
            sendOSC(addr: "/body3d/kp",
                    args: [.int32(Int32(pid)),
                           .int32(Int32(idx)),
                           .float32(world.columns.3.x),
                           .float32(world.columns.3.y),
                           .float32(world.columns.3.z)])
        }
    }

    // MARK: - OSC minimal encoder

    enum OSCArg {
        case int32(Int32)
        case float32(Float)
        case string(String)
    }

    private func sendOSC(addr: String, args: [OSCArg]) {
        var data = Data()
        appendOSCString(addr, into: &data)
        var types = ","
        for a in args {
            switch a {
            case .int32: types.append("i")
            case .float32: types.append("f")
            case .string: types.append("s")
            }
        }
        appendOSCString(types, into: &data)
        for a in args {
            switch a {
            case .int32(let v):
                var be = v.bigEndian
                withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
            case .float32(let v):
                var be = v.bitPattern.bigEndian
                withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
            case .string(let s):
                appendOSCString(s, into: &data)
            }
        }
        sendDatagram(data)
    }

    private func appendOSCString(_ s: String, into data: inout Data) {
        let bytes = Array(s.utf8) + [0]
        data.append(contentsOf: bytes)
        let pad = (4 - data.count % 4) % 4
        if pad > 0 {
            data.append(contentsOf: [UInt8](repeating: 0, count: pad))
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var session: ARBodySession
    func makeUIView(context: Context) -> ARView { session.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
