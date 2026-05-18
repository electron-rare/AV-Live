import AppKit
import Foundation
import CoreVideo
import RealityKit
import simd
import AVLiveWire

/// Owns the single RealityKit scene: the video quad, the body root,
/// and an orbital camera. The app calls `updateVideo/updateSkeleton/
/// updateMesh` from the main queue.
@MainActor
final class SceneController {
    let arView = ARView(frame: .zero)

    private let cameraAnchor = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let worldAnchor = AnchorEntity(world: .zero)

    private(set) var videoQuad: VideoQuad?
    private(set) var skeleton: SkeletonEntity?
    private(set) var mesh: MeshEntity?

    /// Orbital camera state.
    private var orbitYaw: Float = 0
    private var orbitPitch: Float = 0
    private var orbitRadius: Float = 3.0

    private var didSetUp = false

    func setUp() {
        guard !didSetUp else { return }
        didSetUp = true
        arView.environment.background = .color(.black)
        arView.scene.addAnchor(worldAnchor)

        camera.camera.fieldOfViewInDegrees = 55
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)
        applyCamera()

        let q = VideoQuad()
        worldAnchor.addChild(q.entity)
        videoQuad = q

        let s = SkeletonEntity()
        worldAnchor.addChild(s.root)
        skeleton = s

        let m = MeshEntity()
        worldAnchor.addChild(m.root)
        mesh = m

        installOrbitGestures()
    }

    func updateVideo(_ pixelBuffer: CVPixelBuffer) {
        videoQuad?.update(pixelBuffer)
    }

    func updateSkeleton(_ skeletons: [Int: SkeletonPayload]) {
        skeleton?.update(skeletons)
    }

    func updateMesh(_ persons: [MultiHMRPerson]) {
        mesh?.update(persons)
    }

    // MARK: - Orbital camera

    private func applyCamera() {
        let cy = cos(orbitYaw), sy = sin(orbitYaw)
        let cp = cos(orbitPitch), sp = sin(orbitPitch)
        let pos = SIMD3<Float>(orbitRadius * cp * sy,
                               orbitRadius * sp,
                               orbitRadius * cp * cy)
        cameraAnchor.transform.translation = pos
        camera.look(at: .zero, from: pos, relativeTo: nil)
    }

    private func installOrbitGestures() {
        let pan = NSPanGestureRecognizer(
            target: OrbitTarget.shared, action: #selector(
                OrbitTarget.handlePan(_:)))
        OrbitTarget.shared.controller = self
        arView.addGestureRecognizer(pan)
    }

    fileprivate func orbit(dx: Float, dy: Float) {
        orbitYaw += dx * 0.01
        orbitPitch = max(-1.4, min(1.4, orbitPitch + dy * 0.01))
        applyCamera()
    }
}

/// Bridges the AppKit pan gesture to `SceneController.orbit`.
final class OrbitTarget: NSObject {
    static let shared = OrbitTarget()
    weak var controller: SceneController?
    private var last: CGPoint = .zero

    @objc func handlePan(_ g: NSPanGestureRecognizer) {
        switch g.state {
        case .began:
            last = g.translation(in: g.view)
        case .changed:
            let p = g.translation(in: g.view)
            let dx = Float(p.x - last.x)
            let dy = Float(p.y - last.y)
            last = p
            MainActor.assumeIsolated {
                self.controller?.orbit(dx: dx, dy: -dy)
            }
        default:
            break
        }
    }
}
