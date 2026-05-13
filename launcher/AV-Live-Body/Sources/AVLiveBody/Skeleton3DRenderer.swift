import Combine
import Foundation
import RealityKit
import SwiftUI
import simd

/// RealityKit renderer for MediaPipe Pose 3D world landmarks (33 joints,
/// metric coords relative to the hip-center). Consumes the `body3d`
/// publisher of `PoseOSCListener` and maintains one entity tree per
/// detected person.
///
/// Coordinate mapping (MediaPipe -> RealityKit):
///   MediaPipe : x = right, y = down,  z = forward (away from cam).
///   RealityKit: x = right, y = up,    z = backward (toward cam).
///   => convert with (x, -y, -z).
@MainActor
final class Skeleton3DRenderer: ObservableObject {
    /// 32 bones connecting MediaPipe Pose 33 landmarks. Indices are
    /// the canonical MediaPipe Pose landmark indices. Source: official
    /// `mp.solutions.pose.POSE_CONNECTIONS` (Holistic / Pose Landmarker
    /// share the same 33-pt schema).
    static let POSE_CONNECTIONS: [(Int, Int, BoneChain)] = [
        // Face (kept light: nose <-> inner eyes <-> outer eyes <-> ears)
        (0, 1, .face), (1, 2, .face), (2, 3, .face), (3, 7, .face),
        (0, 4, .face), (4, 5, .face), (5, 6, .face), (6, 8, .face),
        (9, 10, .face),
        // Torso
        (11, 12, .trunk), (11, 23, .trunk), (12, 24, .trunk),
        (23, 24, .trunk),
        // Left arm
        (11, 13, .arm), (13, 15, .arm),
        (15, 17, .arm), (15, 19, .arm), (15, 21, .arm), (17, 19, .arm),
        // Right arm
        (12, 14, .arm), (14, 16, .arm),
        (16, 18, .arm), (16, 20, .arm), (16, 22, .arm), (18, 20, .arm),
        // Left leg
        (23, 25, .leg), (25, 27, .leg),
        (27, 29, .leg), (27, 31, .leg), (29, 31, .leg),
        // Right leg
        (24, 26, .leg), (26, 28, .leg),
        (28, 30, .leg), (28, 32, .leg), (30, 32, .leg),
    ]

    enum BoneChain {
        case trunk, arm, leg, face
        var color: NSColor {
            switch self {
            case .trunk: return .white
            case .arm:   return .systemTeal
            case .leg:   return .systemPink   // approx magenta
            case .face:  return NSColor(white: 0.7, alpha: 1.0)
            }
        }
    }

    // Wireframe pur : joints micro (1 mm, quasi invisibles), bones
    // 2 mm = lignes fines. radius=0 fait planter MeshResource.generate.
    private static let jointRadius: Float = 0.001   // 1 mm — quasi nul
    private static let boneRadius:  Float = 0.003   // 3 mm — line-like
    private static let faceJointRadius: Float = 0.001
    private static let handJointRadius: Float = 0.001
    private static let handScale3D: Float = 0.18      // typical hand size (m)
    private static let faceForwardOffset: Float = 0.05 // push face in front of nose
    private static let minConfidence: Float = 0.3
    private static let retainSec: TimeInterval = 1.0

    /// Update throttle : tick at most every `updatePeriod` seconds even
    /// if the publisher fires faster (Combine debounce-style on a clock).
    private static let updatePeriod: TimeInterval = 1.0 / 30.0

    private struct PersonEntities {
        var root: Entity
        var joints: [ModelEntity]     // 33 spheres
        var bones: [ModelEntity]      // 32 bone entities, same order as POSE_CONNECTIONS
        var faceJoints: [ModelEntity]      // 68 dlib face landmarks
        var leftHandJoints: [ModelEntity]  // 21 cyan
        var rightHandJoints: [ModelEntity] // 21 magenta
    }

    private var persons: [Int: PersonEntities] = [:]
    private var lastSeenAt: [Int: TimeInterval] = [:]
    private var lastFace: [Int: PoseOSCListener.FaceFrame] = [:]
    private var lastHands: [Int: PoseOSCListener.HandFrame] = [:]
    private weak var rootAnchor: Entity?
    private var poseSub: AnyCancellable?
    private var faceSub: AnyCancellable?
    private var handSub: AnyCancellable?
    private var lastUpdateAt: TimeInterval = 0
    /// Optional per-pid offset to align the skeleton with another
    /// renderer's coordinate space (typically MeshRenderer's pelvis).
    /// When nil for a pid, falls back to the renderer's default anchor.
    private var pelvisOffsets: [Int: SIMD3<Float>] = [:]

    /// External wiring : MeshRenderer or any other source publishes a
    /// pelvis world position per pid. We translate each person's root
    /// entity to that pose so the openpos skeleton co-locates with the
    /// dense SMPL-X mesh.
    func setPelvisOffsets(_ offsets: [Int: SIMD3<Float>]) {
        pelvisOffsets = offsets
        for (pid, entities) in persons {
            if let off = offsets[pid] {
                entities.root.transform.translation = off
            } else {
                entities.root.transform.translation = .zero
            }
        }
    }

    /// Attach to a scene by giving it an AnchorEntity that owns all
    /// skeleton entities, and start observing the listener.
    func attach(to anchor: Entity, listener: PoseOSCListener) {
        rootAnchor = anchor
        poseSub = listener.$body3d
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frames in
                Task { @MainActor in self?.update(frames: frames) }
            }
        faceSub = listener.$faces
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frames in
                Task { @MainActor in self?.lastFace = frames }
            }
        handSub = listener.$hands
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frames in
                Task { @MainActor in self?.lastHands = frames }
            }
    }

    func detach() {
        poseSub?.cancel()
        poseSub = nil
        faceSub?.cancel()
        faceSub = nil
        handSub?.cancel()
        handSub = nil
        for (_, p) in persons { p.root.removeFromParent() }
        persons.removeAll()
        lastSeenAt.removeAll()
        lastFace.removeAll()
        lastHands.removeAll()
    }

    // MARK: - Update

    private func update(frames: [Int: PoseOSCListener.Pose3DFrame]) {
        let now = CACurrentMediaTime()
        if now - lastUpdateAt < Self.updatePeriod { return }
        lastUpdateAt = now

        guard let anchor = rootAnchor else { return }

        // Mark fresh pids
        for pid in frames.keys { lastSeenAt[pid] = now }
        // GC stale persons
        let cutoff = now - Self.retainSec
        for (pid, p) in persons where (lastSeenAt[pid] ?? 0) < cutoff {
            p.root.removeFromParent()
            persons.removeValue(forKey: pid)
            lastSeenAt.removeValue(forKey: pid)
        }

        for (pid, frame) in frames {
            let entities = persons[pid] ?? makePerson(pid: pid, parent: anchor)
            persons[pid] = entities
            apply(frame: frame, pid: pid, to: entities)
        }
    }

    private func apply(frame: PoseOSCListener.Pose3DFrame,
                       pid: Int,
                       to entities: PersonEntities) {
        // Convert all 33 keypoints to RealityKit space once.
        var rk = [SIMD3<Float>](repeating: .zero, count: 33)
        var valid = [Bool](repeating: false, count: 33)
        for i in 0..<33 {
            let k = frame.kps[i]
            let visible = frame.hasPoint[i] && k.w >= Self.minConfidence
            valid[i] = visible
            // Mediapipe (x right, y down, z forward) -> RK (x right, y up, z back)
            rk[i] = SIMD3<Float>(k.x, -k.y, -k.z)
        }

        // Joints: position spheres and toggle visibility.
        for i in 0..<33 {
            let joint = entities.joints[i]
            if valid[i] {
                joint.transform.translation = rk[i]
                joint.isEnabled = true
            } else {
                joint.isEnabled = false
            }
        }

        // Bones: orient + scale length between endpoints.
        for (bIdx, (a, b, _)) in Self.POSE_CONNECTIONS.enumerated() {
            let bone = entities.bones[bIdx]
            if !valid[a] || !valid[b] {
                bone.isEnabled = false
                continue
            }
            let pa = rk[a]
            let pb = rk[b]
            let delta = pb - pa
            let len = simd_length(delta)
            if len < 1e-5 {
                bone.isEnabled = false
                continue
            }
            let mid = (pa + pb) * 0.5
            // Bone mesh is a cylinder of height=1 along +Y. Rotate +Y
            // onto the (b-a) direction.
            let dir = delta / len
            let yAxis = SIMD3<Float>(0, 1, 0)
            let dot = simd_dot(yAxis, dir)
            let rot: simd_quatf
            if dot > 0.9999 {
                rot = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
            } else if dot < -0.9999 {
                rot = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
            } else {
                let axis = simd_normalize(simd_cross(yAxis, dir))
                let angle = acos(dot)
                rot = simd_quatf(angle: angle, axis: axis)
            }
            bone.transform.translation = mid
            bone.transform.rotation = rot
            // Scale length only on Y, keep XZ at 1 to preserve radius.
            bone.transform.scale = SIMD3<Float>(1, len, 1)
            bone.isEnabled = true
        }

        // --- Face landmarks (68) anchored on nose joint rk[0] ---
        applyFace(pid: pid, rk: rk, valid: valid, to: entities)

        // --- Hand landmarks (21 left + 21 right) anchored on wrists ---
        applyHands(rk: rk, valid: valid, to: entities)
    }

    private func applyFace(pid: Int,
                           rk: [SIMD3<Float>],
                           valid: [Bool],
                           to entities: PersonEntities) {
        guard let face = lastFace[pid] else {
            for j in entities.faceJoints { j.isEnabled = false }
            return
        }
        // Head width in 3D : distance between ears (rk[7] left ear,
        // rk[8] right ear). Fall back to a sane default if missing.
        let headWidth3D: Float
        if valid[7] && valid[8] {
            headWidth3D = max(0.10, simd_length(rk[7] - rk[8]))
        } else {
            headWidth3D = 0.18
        }
        // Compute 2D bbox width of face points + centroid.
        var minX: Float =  .infinity, maxX: Float = -.infinity
        var sumX: Float = 0, sumY: Float = 0
        var n: Float = 0
        for i in 0..<68 where face.hasPoint[i] {
            let p = face.points[i]
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            sumX += p.x
            sumY += p.y
            n += 1
        }
        let nose = valid[0] ? rk[0] : SIMD3<Float>(0, 0, 0)
        guard n > 4, maxX > minX else {
            for j in entities.faceJoints { j.isEnabled = false }
            return
        }
        let face2DWidth = max(maxX - minX, 1e-4)
        let scale = headWidth3D / face2DWidth
        let cx = sumX / n
        let cy = sumY / n
        for i in 0..<68 {
            let j = entities.faceJoints[i]
            if face.hasPoint[i] {
                let dx = face.points[i].x - cx
                let dy = face.points[i].y - cy
                // Flip y : image y down -> RK y up. +z to push in front of nose.
                j.transform.translation = nose + SIMD3<Float>(
                    dx * scale, -dy * scale, Self.faceForwardOffset)
                j.isEnabled = true
            } else {
                j.isEnabled = false
            }
        }
    }

    private func applyHands(rk: [SIMD3<Float>],
                            valid: [Bool],
                            to entities: PersonEntities) {
        // Disable by default ; re-enable per side if a matching frame found.
        for j in entities.leftHandJoints  { j.isEnabled = false }
        for j in entities.rightHandJoints { j.isEnabled = false }

        // Iterate cached hand frames (keyed by pid in OSC ; here we route
        // purely by `side` since the python emits side=0/1 explicitly).
        for (_, hand) in lastHands {
            let isLeft = (hand.side == 0)
            let wristIdx = isLeft ? 15 : 16
            guard valid[wristIdx] else { continue }
            let wrist = rk[wristIdx]
            let target = isLeft
                ? entities.leftHandJoints
                : entities.rightHandJoints

            // Centroid of valid hand points.
            var sumX: Float = 0, sumY: Float = 0, n: Float = 0
            for i in 0..<21 where hand.hasPoint[i] {
                sumX += hand.points[i].x
                sumY += hand.points[i].y
                n += 1
            }
            guard n > 2 else { continue }
            let cx = sumX / n
            let cy = sumY / n
            let scale = Self.handScale3D
            for i in 0..<21 {
                let j = target[i]
                if hand.hasPoint[i] {
                    let dx = hand.points[i].x - cx
                    let dy = hand.points[i].y - cy
                    j.transform.translation = wrist + SIMD3<Float>(
                        dx * scale, -dy * scale, 0)
                    j.isEnabled = true
                } else {
                    j.isEnabled = false
                }
            }
        }
    }

    // MARK: - Construction

    private func makePerson(pid: Int, parent: Entity) -> PersonEntities {
        let root = Entity()
        parent.addChild(root)

        // Joint sphere mesh shared across joints (cheap to reuse).
        let sphereMesh = MeshResource.generateSphere(
            radius: Self.jointRadius)
        let jointMat = SimpleMaterial(
            color: .white, roughness: 0.6, isMetallic: false)
        var joints: [ModelEntity] = []
        joints.reserveCapacity(33)
        for _ in 0..<33 {
            let e = ModelEntity(mesh: sphereMesh, materials: [jointMat])
            e.isEnabled = false
            root.addChild(e)
            joints.append(e)
        }

        // One cylinder per bone (height=1, scaled at runtime).
        let cylMesh = MeshResource.generateCylinder(
            height: 1.0, radius: Self.boneRadius)
        var bones: [ModelEntity] = []
        bones.reserveCapacity(Self.POSE_CONNECTIONS.count)
        for (_, _, chain) in Self.POSE_CONNECTIONS {
            let mat = SimpleMaterial(
                color: chain.color, roughness: 0.6, isMetallic: false)
            let e = ModelEntity(mesh: cylMesh, materials: [mat])
            e.isEnabled = false
            root.addChild(e)
            bones.append(e)
        }
        // Face sub-spheres (68 dlib landmarks, neutral light grey).
        let faceMesh = MeshResource.generateSphere(
            radius: Self.faceJointRadius)
        let faceMat = SimpleMaterial(
            color: NSColor(white: 0.85, alpha: 1.0),
            roughness: 0.7, isMetallic: false)
        var faceJoints: [ModelEntity] = []
        faceJoints.reserveCapacity(68)
        for _ in 0..<68 {
            let e = ModelEntity(mesh: faceMesh, materials: [faceMat])
            e.isEnabled = false
            root.addChild(e)
            faceJoints.append(e)
        }

        // Hand sub-spheres : left=cyan, right=magenta, 21 each.
        let handMesh = MeshResource.generateSphere(
            radius: Self.handJointRadius)
        let leftMat = SimpleMaterial(
            color: .systemCyan, roughness: 0.6, isMetallic: false)
        let rightMat = SimpleMaterial(
            color: .systemPink, roughness: 0.6, isMetallic: false)
        var leftHand: [ModelEntity] = []
        var rightHand: [ModelEntity] = []
        leftHand.reserveCapacity(21)
        rightHand.reserveCapacity(21)
        for _ in 0..<21 {
            let el = ModelEntity(mesh: handMesh, materials: [leftMat])
            el.isEnabled = false
            root.addChild(el)
            leftHand.append(el)
            let er = ModelEntity(mesh: handMesh, materials: [rightMat])
            er.isEnabled = false
            root.addChild(er)
            rightHand.append(er)
        }
        NSLog("Skeleton3DRenderer: spawned pid=%d (33 joints, %d bones, 68 face, 21+21 hands)",
              pid, bones.count)
        return PersonEntities(root: root,
                              joints: joints,
                              bones: bones,
                              faceJoints: faceJoints,
                              leftHandJoints: leftHand,
                              rightHandJoints: rightHand)
    }
}
