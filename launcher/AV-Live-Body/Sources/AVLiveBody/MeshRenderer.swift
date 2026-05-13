import Combine
import Foundation
import RealityKit
import SwiftUI

/// Gere les vertices SMPL-X recus par TCP et les pousse dans une
/// MeshResource de RealityKit. Lit smplx_faces.bin une fois au lancement
/// (20908 triangles statiques).
@MainActor
final class MeshRenderer: ObservableObject {
    @Published var personEntities: [Int: ModelEntity] = [:]
    private var faces: [UInt32] = []
    private var oscServer: OSCServer?

    init() {
        loadFaces()
    }

    private func loadFaces() {
        guard let url = Bundle.module.url(forResource: "smplx_faces",
                                          withExtension: "bin") else {
            print("smplx_faces.bin not found in bundle")
            return
        }
        guard let data = try? Data(contentsOf: url) else { return }
        let n = data.count / 4
        var arr = [UInt32](repeating: 0, count: n)
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt32.self)
            for i in 0..<n { arr[i] = src[i] }
        }
        // Le flip y/z (Multi-HMR -> RealityKit) inverse la chiralite
        // donc on inverse aussi le winding des triangles (i0,i1,i2 ->
        // i0,i2,i1) sinon backface cull masque tout le mesh.
        for tri in stride(from: 0, to: n, by: 3) where tri + 2 < n {
            let tmp = arr[tri + 1]
            arr[tri + 1] = arr[tri + 2]
            arr[tri + 2] = tmp
        }
        self.faces = arr
        NSLog("AV-Live-Body: loaded %d face indices (%d triangles)", n, n / 3)
    }

    func startOSCServer() {
        let server = OSCServer(port: 57130) { [weak self] persons in
            Task { @MainActor in
                self?.updatePersons(persons)
            }
        }
        server.start()
        self.oscServer = server
    }

    func updatePersons(_ persons: [SMPLXPersonData]) {
        let receivedPids = Set(persons.map { $0.pid })
        for (pid, _) in personEntities where !receivedPids.contains(pid) {
            personEntities.removeValue(forKey: pid)
            lowLevelMeshes.removeValue(forKey: pid)
        }
        for p in persons {
            let entity: ModelEntity
            if let existing = personEntities[p.pid] {
                entity = existing
            } else {
                entity = makeEntity(pid: p.pid)
                entity.components.set(PidComponent(pid: p.pid))
            }
            // Multi-HMR v3d est en coord camera ABSOLUE (deja inclut la
            // translation). On flip y/z (MH y-down z-forward -> RK
            // y-up z-back) et on laisse l'entity a l'origine.
            let converted = p.vertices.map { v in
                SIMD3<Float>(v.x, -v.y, -v.z)
            }
            updateMeshVertices(entity, vertices: converted)
            entity.transform.translation = SIMD3<Float>.zero
            // Bbox debug : utile une fois par creation
            if personEntities[p.pid] == nil {
                let xs = converted.map(\.x)
                let ys = converted.map(\.y)
                let zs = converted.map(\.z)
                NSLog("AV-Live-Body: pid=%d bbox x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]",
                      p.pid,
                      xs.min() ?? 0, xs.max() ?? 0,
                      ys.min() ?? 0, ys.max() ?? 0,
                      zs.min() ?? 0, zs.max() ?? 0)
            }
            personEntities[p.pid] = entity
        }
    }

    private var lowLevelMeshes: [Int: LowLevelMesh] = [:]

    private func makeEntity(pid: Int) -> ModelEntity {
        let material = SimpleMaterial(color: colorForPid(pid),
                                      isMetallic: false)
        let entity = ModelEntity()
        let initial = Array(repeating: SIMD3<Float>(0, 0, 0), count: 10475)
        if let mesh = createLowLevelMesh(vertices: initial) {
            lowLevelMeshes[pid] = mesh
            if let resource = try? MeshResource(from: mesh) {
                entity.model = ModelComponent(mesh: resource,
                                              materials: [material])
            }
        } else {
            entity.model = ModelComponent(
                mesh: fallbackMesh(vertices: initial),
                materials: [material]
            )
        }
        return entity
    }

    private func fallbackMesh(vertices: [SIMD3<Float>]) -> MeshResource {
        var desc = MeshDescriptor(name: "smplx")
        desc.positions = MeshBuffer(vertices)
        desc.primitives = .triangles(faces)
        if let mesh = try? MeshResource.generate(from: [desc]) {
            return mesh
        }
        return MeshResource.generateBox(size: 0.1)
    }

    /// Update les positions des vertices in-place via LowLevelMesh
    /// (macOS 14+) ; fallback rebuild du MeshResource si indisponible.
    private func updateMeshVertices(_ entity: ModelEntity,
                                    vertices: [SIMD3<Float>]) {
        let pid = entity.components[PidComponent.self]?.pid ?? -1
        if let mesh = lowLevelMeshes[pid] {
            mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawPtr in
                let dst = rawPtr.bindMemory(to: SIMD3<Float>.self)
                let n = min(dst.count, vertices.count)
                for i in 0..<n { dst[i] = vertices[i] }
            }
            return
        }
        entity.model?.mesh = fallbackMesh(vertices: vertices)
    }

    private func createLowLevelMesh(vertices: [SIMD3<Float>]) -> LowLevelMesh? {
        let vertexAttr = LowLevelMesh.Attribute(
            semantic: .position, format: .float3, offset: 0)
        let vertexLayout = LowLevelMesh.Layout(
            bufferIndex: 0,
            bufferStride: MemoryLayout<SIMD3<Float>>.stride)
        let desc = LowLevelMesh.Descriptor(
            vertexCapacity: vertices.count,
            vertexAttributes: [vertexAttr],
            vertexLayouts: [vertexLayout],
            indexCapacity: faces.count,
            indexType: .uint32
        )
        guard let mesh = try? LowLevelMesh(descriptor: desc) else {
            return nil
        }
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { ptr in
            let dst = ptr.bindMemory(to: SIMD3<Float>.self)
            for (i, v) in vertices.enumerated() where i < dst.count {
                dst[i] = v
            }
        }
        mesh.withUnsafeMutableIndices { ptr in
            let dst = ptr.bindMemory(to: UInt32.self)
            for (i, f) in faces.enumerated() where i < dst.count {
                dst[i] = f
            }
        }
        let bounds = BoundingBox(min: SIMD3(-2, -2, -2),
                                 max: SIMD3(2, 2, 2))
        mesh.parts.replaceAll([
            .init(indexCount: faces.count,
                  topology: .triangle,
                  materialIndex: 0,
                  bounds: bounds)
        ])
        return mesh
    }

    private func colorForPid(_ pid: Int) -> NSColor {
        let palette: [NSColor] = [
            .systemTeal, .systemPink, .systemYellow,
            .systemOrange, .systemPurple, .systemGreen,
        ]
        let n = palette.count
        return palette[((pid % n) + n) % n]
    }
}

struct SMPLXPersonData {
    let pid: Int
    let confidence: Float
    let translation: SIMD3<Float>
    let vertices: [SIMD3<Float>]
}

/// Component permettant de retrouver le pid d'une ModelEntity sans
/// passer par un dictionnaire externe.
struct PidComponent: Component {
    let pid: Int
}
