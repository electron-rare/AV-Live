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

    // Interpolation 60 fps entre frames Multi-HMR (typ. ~4 fps Python).
    // Lerp exponentiel: displayed = lerp(displayed, target, alpha).
    // alpha=0.3 a 60 fps -> 90% du gap parcouru en ~7 frames (~115 ms).
    private struct InterpState {
        var displayed: [SIMD3<Float>]
        var target: [SIMD3<Float>]
    }
    private var interpStates: [Int: InterpState] = [:]
    private var sceneSub: (any Cancellable)?
    private var interpTickCounter: Int = 0
    // SceneEvents.Update fires ~60 fps ; on lerp 1 tick sur 2 = 30 fps.
    // Alpha re-ajuste pour atteindre ~90% du gap en ~115 ms a 30 Hz
    // (au lieu de 60 Hz precedemment) -> alpha plus eleve.
    private static let interpAlpha: Float = 0.5
    private static let interpStride: Int = 2

    init() {
        loadFaces()
    }

    func attachToScene(_ scene: RealityKit.Scene) {
        sceneSub = scene.subscribe(to: SceneEvents.Update.self) {
            [weak self] _ in
            Task { @MainActor in self?.tickInterp() }
        }
    }

    private func tickInterp() {
        interpTickCounter &+= 1
        if interpTickCounter % Self.interpStride != 0 { return }
        let alpha = Self.interpAlpha
        let oneMinus: Float = 1.0 - alpha
        for (pid, state) in interpStates {
            guard let entity = personEntities[pid] else { continue }
            var displayed = state.displayed
            let n = min(displayed.count, state.target.count)
            for i in 0..<n {
                displayed[i] = state.displayed[i] * oneMinus
                    + state.target[i] * alpha
            }
            interpStates[pid] = InterpState(
                displayed: displayed, target: state.target)
            updateMeshVertices(
                entity, vertices: displayed, updateNormals: false)
        }
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
        // Pre-compute les indices d'aretes pour le wireframe :
        // chaque triangle (a,b,c) -> 3 lignes (a,b)(b,c)(c,a).
        var lines = [UInt32]()
        lines.reserveCapacity(n * 2)
        var i = 0
        while i + 2 < n {
            let a = arr[i], b = arr[i + 1], c = arr[i + 2]
            lines.append(a); lines.append(b)
            lines.append(b); lines.append(c)
            lines.append(c); lines.append(a)
            i += 3
        }
        self.wireframeIndices = lines
        NSLog("AV-Live-Body: loaded %d face indices (%d triangles, %d wireframe edges)",
              n, n / 3, lines.count / 2)
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
            wireframeMeshes.removeValue(forKey: pid)
            wireframeEntities.removeValue(forKey: pid)
            interpStates.removeValue(forKey: pid)
        }
        for p in persons {
            let entity: ModelEntity
            let isFirstFrame: Bool
            if let existing = personEntities[p.pid] {
                entity = existing
                isFirstFrame = false
            } else {
                entity = makeEntity(pid: p.pid)
                entity.components.set(PidComponent(pid: p.pid))
                isFirstFrame = true
            }
            // Multi-HMR v3d est en coord camera ABSOLUE (deja inclut la
            // translation). On flip y/z (MH y-down z-forward -> RK
            // y-up z-back) et on laisse l'entity a l'origine.
            let converted = p.vertices.map { v in
                SIMD3<Float>(v.x, -v.y, -v.z)
            }
            // Update interp target; first frame pushes immediately so
            // mesh apparait sans attendre le premier tick.
            if isFirstFrame {
                interpStates[p.pid] = InterpState(
                    displayed: converted, target: converted)
                updateMeshVertices(entity, vertices: converted)
            } else if let prior = interpStates[p.pid] {
                interpStates[p.pid] = InterpState(
                    displayed: prior.displayed, target: converted)
            } else {
                interpStates[p.pid] = InterpState(
                    displayed: converted, target: converted)
            }
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
    private var wireframeMeshes: [Int: LowLevelMesh] = [:]
    private var wireframeEntities: [Int: ModelEntity] = [:]
    private var wireframeIndices: [UInt32] = []
    private var currentMetallic: Bool = false
    private var currentRoughness: Float = 0.6
    private var currentShowWireframe: Bool = false

    /// Pousse les nouveaux parametres de materiau a chaque entity vivant.
    /// Appelle par BodyView a chaque updateNSView pour permettre des
    /// changements live (Metallic toggle, Roughness slider).
    func applyMaterialSettings(metallic: Bool, roughness: Float) {
        currentMetallic = metallic
        currentRoughness = roughness
        for (pid, entity) in personEntities {
            entity.model?.materials = [SimpleMaterial(
                color: colorForPid(pid),
                roughness: .init(floatLiteral: roughness),
                isMetallic: metallic)]
        }
    }

    /// Active/desactive le rendu fil de fer pour toutes les personnes.
    func applyWireframeSetting(_ enabled: Bool) {
        currentShowWireframe = enabled
        for (_, wf) in wireframeEntities {
            wf.isEnabled = enabled
        }
    }

    private func makeEntity(pid: Int) -> ModelEntity {
        let material = SimpleMaterial(color: colorForPid(pid),
                                      roughness: .init(
                                        floatLiteral: currentRoughness),
                                      isMetallic: currentMetallic)
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
        // Cree l'entity wireframe sibling (cache jusqu'a toggle ON)
        if let wfMesh = createWireframeMesh(vertices: initial) {
            wireframeMeshes[pid] = wfMesh
            if let wfResource = try? MeshResource(from: wfMesh) {
                let wfMaterial = UnlitMaterial(color: NSColor.white)
                let wfEntity = ModelEntity(
                    mesh: wfResource, materials: [wfMaterial])
                wfEntity.isEnabled = currentShowWireframe
                entity.addChild(wfEntity)
                wireframeEntities[pid] = wfEntity
            }
        }
        return entity
    }

    /// Cree un LowLevelMesh en topologie .line avec les aretes de la
    /// topologie SMPL-X. Vertex buffer initial = positions zero ;
    /// updateMeshVertices se charge de la mise a jour live.
    private func createWireframeMesh(vertices: [SIMD3<Float>]) -> LowLevelMesh? {
        let posAttr = LowLevelMesh.Attribute(
            semantic: .position, format: .float3, offset: 0)
        let stride = MemoryLayout<SIMD3<Float>>.stride
        let posLayout = LowLevelMesh.Layout(
            bufferIndex: 0, bufferStride: stride)
        let desc = LowLevelMesh.Descriptor(
            vertexCapacity: vertices.count,
            vertexAttributes: [posAttr],
            vertexLayouts: [posLayout],
            indexCapacity: wireframeIndices.count,
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
            for (i, idx) in wireframeIndices.enumerated() where i < dst.count {
                dst[i] = idx
            }
        }
        let bounds = BoundingBox(min: SIMD3(-2, -2, -2),
                                 max: SIMD3(2, 2, 2))
        mesh.parts.replaceAll([
            .init(indexCount: wireframeIndices.count,
                  topology: .line,
                  materialIndex: 0,
                  bounds: bounds)
        ])
        return mesh
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
    /// `updateNormals=false` saute le recalcul des normales (~24 ms sur
    /// 10475 verts) — utile pendant l'interp 60 fps ou les normales
    /// stockees restent valides ~150 ms (1 frame Python).
    private func updateMeshVertices(_ entity: ModelEntity,
                                    vertices: [SIMD3<Float>],
                                    updateNormals: Bool = true) {
        let t0 = CFAbsoluteTimeGetCurrent()
        let pid = entity.components[PidComponent.self]?.pid ?? -1
        if let mesh = lowLevelMeshes[pid] {
            // Buffer 0 : positions (SIMD3<Float>)
            mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawPtr in
                let dst = rawPtr.bindMemory(to: SIMD3<Float>.self)
                let n = min(dst.count, vertices.count)
                for i in 0..<n { dst[i] = vertices[i] }
            }
            // Wireframe sibling : meme positions, indices line stockes
            if let wf = wireframeMeshes[pid], currentShowWireframe {
                wf.withUnsafeMutableBytes(bufferIndex: 0) { rawPtr in
                    let dst = rawPtr.bindMemory(to: SIMD3<Float>.self)
                    let n = min(dst.count, vertices.count)
                    for i in 0..<n { dst[i] = vertices[i] }
                }
            }
            // Buffer 1 : normales (calculees a partir des triangles).
            // Necessaire pour que SimpleMaterial (lit) calcule un
            // shading qui donne du relief au mesh ; sans normales le
            // mesh apparait en aplats de couleur. Skip pendant les
            // interp ticks pour eviter de bloquer le MainActor 60x/s.
            if updateNormals {
                let normals = Self.computeVertexNormals(
                    vertices: vertices, faces: faces)
                mesh.withUnsafeMutableBytes(bufferIndex: 1) { rawPtr in
                    let dst = rawPtr.bindMemory(to: SIMD3<Float>.self)
                    let n = min(dst.count, normals.count)
                    for i in 0..<n { dst[i] = normals[i] }
                }
            }
            let dtMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dtMs > 5 {
                NSLog("MeshRenderer.update: %.1f ms (pid=%d)", dtMs, pid)
            }
            return
        }
        entity.model?.mesh = fallbackMesh(vertices: vertices)
        let dtMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        if dtMs > 5 {
            NSLog("MeshRenderer.update(fallback): %.1f ms (pid=%d)", dtMs, pid)
        }
    }

    /// Normales par sommet : somme des normales des triangles
    /// adjacents, puis normalisation. Cout O(faces + verts).
    static func computeVertexNormals(
        vertices: [SIMD3<Float>], faces: [UInt32]
    ) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](
            repeating: SIMD3<Float>(0, 0, 0), count: vertices.count)
        var i = 0
        while i + 2 < faces.count {
            let a = Int(faces[i])
            let b = Int(faces[i + 1])
            let c = Int(faces[i + 2])
            i += 3
            if a >= vertices.count || b >= vertices.count
                || c >= vertices.count { continue }
            let v0 = vertices[a]
            let edge1 = vertices[b] - v0
            let edge2 = vertices[c] - v0
            let triNormal = cross(edge1, edge2)
            normals[a] += triNormal
            normals[b] += triNormal
            normals[c] += triNormal
        }
        for j in 0..<normals.count {
            let len = length(normals[j])
            if len > 1e-6 {
                normals[j] = normals[j] / len
            } else {
                normals[j] = SIMD3<Float>(0, 1, 0)
            }
        }
        return normals
    }

    private func createLowLevelMesh(vertices: [SIMD3<Float>]) -> LowLevelMesh? {
        let posAttr = LowLevelMesh.Attribute(
            semantic: .position, format: .float3, offset: 0)
        let normAttr = LowLevelMesh.Attribute(
            semantic: .normal, format: .float3, offset: 0)
        let stride = MemoryLayout<SIMD3<Float>>.stride
        let posLayout = LowLevelMesh.Layout(
            bufferIndex: 0, bufferStride: stride)
        let normLayout = LowLevelMesh.Layout(
            bufferIndex: 1, bufferStride: stride)
        let desc = LowLevelMesh.Descriptor(
            vertexCapacity: vertices.count,
            vertexAttributes: [posAttr, normAttr],
            vertexLayouts: [posLayout, normLayout],
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
        // Normales initiales (T-pose-ish) — recalculees au premier frame
        let initNormals = Self.computeVertexNormals(
            vertices: vertices, faces: faces)
        mesh.withUnsafeMutableBytes(bufferIndex: 1) { ptr in
            let dst = ptr.bindMemory(to: SIMD3<Float>.self)
            for (i, n) in initNormals.enumerated() where i < dst.count {
                dst[i] = n
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
