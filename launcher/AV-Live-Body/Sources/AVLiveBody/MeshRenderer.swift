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
        self.faces = arr
        print("Loaded \(n) face indices (\(n / 3) triangles)")
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
        }
        for p in persons {
            let entity = personEntities[p.pid] ?? makeEntity(pid: p.pid)
            updateMeshVertices(entity, vertices: p.vertices)
            entity.transform.translation = p.translation
            personEntities[p.pid] = entity
        }
    }

    private func makeEntity(pid: Int) -> ModelEntity {
        let material = SimpleMaterial(color: colorForPid(pid),
                                      isMetallic: false)
        let entity = ModelEntity()
        let initial = Array(repeating: SIMD3<Float>(0, 0, 0), count: 10475)
        entity.model = ModelComponent(
            mesh: makeMesh(vertices: initial),
            materials: [material]
        )
        return entity
    }

    private func makeMesh(vertices: [SIMD3<Float>]) -> MeshResource {
        var desc = MeshDescriptor(name: "smplx")
        desc.positions = MeshBuffer(vertices)
        desc.primitives = .triangles(faces)
        if let mesh = try? MeshResource.generate(from: [desc]) {
            return mesh
        }
        return MeshResource.generateBox(size: 0.1)
    }

    private func updateMeshVertices(_ entity: ModelEntity,
                                    vertices: [SIMD3<Float>]) {
        entity.model?.mesh = makeMesh(vertices: vertices)
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
