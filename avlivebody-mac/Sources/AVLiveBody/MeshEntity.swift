import AppKit
import Foundation
import RealityKit
import simd

/// Renders SMPL-X dense body meshes (10475 vertices) from Multi-HMR.
/// Triangle indices come from the bundled `smplx_faces.bin`
/// (flat UInt32 triplets).
@MainActor
final class MeshEntity {
    let root = Entity()

    private static let vertexCount = 10475
    private let faces: [UInt32]
    private var pools: [Int: ModelEntity] = [:]
    private let material = SimpleMaterial(
        color: NSColor(white: 0.8, alpha: 1.0),
        roughness: 0.5, isMetallic: false)

    init() {
        faces = MeshEntity.loadFaces()
    }

    func update(_ persons: [MultiHMRPerson]) {
        for (idx, person) in persons.enumerated() {
            let entity = pools[idx] ?? {
                let e = ModelEntity()
                root.addChild(e)
                pools[idx] = e
                return e
            }()
            guard let mesh = buildMesh(person.vertices) else { continue }
            entity.model = ModelComponent(mesh: mesh,
                                          materials: [material])
            let t = person.translation
            entity.transform.translation = arkitToRealityKit(t)
            entity.isEnabled = true
        }
        for idx in pools.keys where idx >= persons.count {
            pools[idx]?.isEnabled = false
        }
    }

    private func buildMesh(_ verts: [SIMD3<Float>])
        -> MeshResource? {
        guard verts.count == Self.vertexCount, !faces.isEmpty else {
            NSLog("MeshEntity: vertex count mismatch %d (expected %d), faces=%d",
                  verts.count, Self.vertexCount, faces.count)
            return nil
        }
        var descriptor = MeshDescriptor(name: "smplx")
        descriptor.positions = MeshBuffer(verts.map(arkitToRealityKit))
        descriptor.primitives = .triangles(faces)
        return try? MeshResource.generate(from: [descriptor])
    }

    private static func loadFaces() -> [UInt32] {
        guard let url = Bundle.main.url(
            forResource: "smplx_faces", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else {
            NSLog("MeshEntity: smplx_faces.bin missing")
            return []
        }
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: UInt32.self))
        }
    }
}
