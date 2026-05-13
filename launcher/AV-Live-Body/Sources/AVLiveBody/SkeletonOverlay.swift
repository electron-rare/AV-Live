import AppKit
import RealityKit
import simd

/// Rendu skeleton openpos : pour chaque personne detectee, on dessine
/// une sphere a chaque keypoint et un cylindre entre chaque paire de
/// joints connectee. Couleur dependante du pid.
@MainActor
final class SkeletonOverlay {
    // MediaPipe BlazePose 33 BODY_LANDMARKS connections (bones)
    static let bones: [(Int, Int)] = [
        // Face
        (0, 1), (1, 2), (2, 3), (3, 7),
        (0, 4), (4, 5), (5, 6), (6, 8),
        (9, 10),
        // Torso
        (11, 12), (11, 23), (12, 24), (23, 24),
        // Left arm
        (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
        // Right arm
        (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
        // Left leg
        (23, 25), (25, 27), (27, 29), (27, 31), (29, 31),
        // Right leg
        (24, 26), (26, 28), (28, 30), (28, 32), (30, 32),
    ]

    private let anchor: AnchorEntity
    private var personRoots: [Int: Entity] = [:]
    private var jointMeshes: [Int: [ModelEntity]] = [:]
    private var boneMeshes: [Int: [ModelEntity]] = [:]

    init(parent: AnchorEntity) {
        self.anchor = parent
    }

    /// Couleur par pid (palette 6 entrees)
    private static let palette: [SIMD3<Float>] = [
        SIMD3(0.0, 1.0, 0.85),    // turquoise
        SIMD3(1.0, 0.3, 0.7),     // magenta
        SIMD3(1.0, 0.9, 0.2),     // jaune
        SIMD3(1.0, 0.55, 0.1),    // ambre
        SIMD3(0.7, 0.5, 1.0),     // lilas
        SIMD3(0.4, 1.0, 0.3),     // vert
    ]

    /// Met a jour le rendu skeleton pour toutes les personnes du
    /// PoseOSCListener. Cree / recycle les entites a la demande.
    func update(persons: [Int: PoseOSCListener.PoseFrame],
                visible: Bool) {
        if !visible {
            // Cache tout sans detruire
            for root in personRoots.values { root.isEnabled = false }
            return
        }
        let receivedPids = Set(persons.keys)

        // Cleanup personnes disparues
        for pid in personRoots.keys where !receivedPids.contains(pid) {
            personRoots[pid]?.removeFromParent()
            personRoots[pid] = nil
            jointMeshes[pid] = nil
            boneMeshes[pid] = nil
        }

        for (pid, frame) in persons {
            let skel = frame.skeleton
            guard skel.count >= 33 else { continue }
            let color = Self.palette[((pid % 6) + 6) % 6]

            // Cree le root + meshes la premiere fois
            if personRoots[pid] == nil {
                let root = Entity()
                anchor.addChild(root)
                personRoots[pid] = root
                let nsCol = NSColor(red: CGFloat(color.x),
                                    green: CGFloat(color.y),
                                    blue: CGFloat(color.z),
                                    alpha: 1.0)
                let mat = UnlitMaterial(color: nsCol)
                let sphereMesh = MeshResource.generateSphere(radius: 0.035)
                var joints: [ModelEntity] = []
                for _ in 0..<33 {
                    let je = ModelEntity(
                        mesh: sphereMesh, materials: [mat])
                    root.addChild(je)
                    joints.append(je)
                }
                jointMeshes[pid] = joints
                // Bones : on cree un cylindre par bone, mesh partagee
                let boneMesh = MeshResource.generateBox(
                    width: 0.015, height: 1.0, depth: 0.015,
                    cornerRadius: 0.005)
                var bones: [ModelEntity] = []
                for _ in Self.bones {
                    let be = ModelEntity(
                        mesh: boneMesh, materials: [mat])
                    root.addChild(be)
                    bones.append(be)
                }
                boneMeshes[pid] = bones
            }

            guard let joints = jointMeshes[pid],
                  let bones = boneMeshes[pid] else { continue }
            personRoots[pid]?.isEnabled = true

            // Update joints : coords image (x 0..1 droite, y 0..1 bas)
            // -> RealityKit (x droite, y haut, z negatif vers cam).
            // On projete sur un plan a z = -2.5 et on echelle 2x pour
            // remplir la fenetre.
            let scale: Float = 2.0
            let z: Float = -2.5
            var worldPos: [SIMD3<Float>] = []
            worldPos.reserveCapacity(33)
            for i in 0..<33 {
                let kp = skel[i]
                let wx = (kp.x - 0.5) * scale
                let wy = -(kp.y - 0.5) * scale   // flip y
                let pos = SIMD3<Float>(wx, wy, z)
                worldPos.append(pos)
                if i < joints.count {
                    joints[i].transform.translation = pos
                    joints[i].isEnabled = kp.z > 0.3
                }
            }

            // Update bones : positionne chaque cylindre entre 2 joints
            for (idx, (a, b)) in Self.bones.enumerated() {
                guard idx < bones.count,
                      a < worldPos.count, b < worldPos.count else { continue }
                let pa = worldPos[a]
                let pb = worldPos[b]
                let mid = (pa + pb) * 0.5
                let dir = pb - pa
                let len = simd_length(dir)
                bones[idx].transform.translation = mid
                // Orient cylinder Y axis along dir
                if len > 1e-4 {
                    let up = SIMD3<Float>(0, 1, 0)
                    let axis = simd_normalize(dir)
                    let rot = simd_quatf(from: up, to: axis)
                    bones[idx].transform.rotation = rot
                    bones[idx].transform.scale = SIMD3(1, len, 1)
                    let confA = idx < Self.bones.count
                        ? skel[a].z : 0
                    let confB = idx < Self.bones.count
                        ? skel[b].z : 0
                    bones[idx].isEnabled = min(confA, confB) > 0.3
                } else {
                    bones[idx].isEnabled = false
                }
            }
        }
    }
}
