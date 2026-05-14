import Combine
import Foundation
import RealityKit
import SwiftUI
import simd

/// RealityKit renderer for MediaPipe Pose 3D world landmarks (33 joints,
/// metric coords relative to the hip-center) fused with dlib face 68
/// 2D landmarks and MediaPipe Hand 21 2D landmarks per side.
///
/// Topology: a SINGLE LowLevelMesh (topology=.line) per person bundles
/// body bones + face chains + hand chains + anatomical connectors into
/// one continuous procedural wireframe humanoid. Vertices are layed out
/// contiguously :
///
///   slots [0..33)      : 33 body landmarks (MediaPipe Pose)
///   slots [33..101)    : 68 dlib face landmarks (anchored on nose)
///   slots [101..122)   : 21 left-hand landmarks (anchored on left wrist)
///   slots [122..143)   : 21 right-hand landmarks (anchored on right wrist)
///
/// Indices are baked once at makePerson and split into 4 mesh parts
/// (one per material colour), so the draw cost is 4 draw-calls per
/// person regardless of which segments are valid (invalid segments
/// collapse to zero-length degenerate lines).
///
/// Coordinate mapping (MediaPipe -> RealityKit):
///   MediaPipe : x = right, y = down,  z = forward (away from cam).
///   RealityKit: x = right, y = up,    z = backward (toward cam).
///   => convert with (x, -y, -z).
@MainActor
final class Skeleton3DRenderer: ObservableObject {

    // MARK: - Topology constants

    /// 32 bones connecting MediaPipe Pose 33 landmarks.
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

    /// dlib 68 face chains (subset of MediaPipe 478 in our pipeline).
    /// Open chains are listed as runs ; closed loops include the
    /// wrap-around edge.
    static let FACE_CHAINS: [[Int]] = [
        // jaw 0..16 (open)
        Array(0...16),
        // right brow 17..21 (open)
        Array(17...21),
        // left brow 22..26 (open)
        Array(22...26),
        // nose bridge 27..30 (open)
        Array(27...30),
        // nose base 31..35 (open)
        Array(31...35),
        // right eye 36..41 (closed)
        [36, 37, 38, 39, 40, 41, 36],
        // left eye 42..47 (closed)
        [42, 43, 44, 45, 46, 47, 42],
        // outer lips 48..59 (closed)
        [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 48],
        // inner lips 60..67 (closed)
        [60, 61, 62, 63, 64, 65, 66, 67, 60],
    ]

    /// MediaPipe Hand 21 chains.
    static let HAND_CHAINS: [[Int]] = [
        // palm closure : wrist -> index_mcp -> middle_mcp -> ring_mcp
        // -> pinky_mcp -> wrist
        [0, 5, 9, 13, 17, 0],
        // thumb (with wrist connector 0-1)
        [0, 1, 2, 3, 4],
        // index
        [5, 6, 7, 8],
        // middle
        [9, 10, 11, 12],
        // ring
        [13, 14, 15, 16],
        // pinky
        [17, 18, 19, 20],
    ]

    enum BoneChain {
        case trunk, arm, leg, face
        /// Material slot in the part list (see materialPalette).
        var materialIndex: Int {
            switch self {
            case .trunk: return 0    // white
            case .arm:   return 1    // cyan
            case .leg:   return 2    // magenta/pink
            case .face:  return 3    // light grey
            }
        }
    }

    // MARK: - Layout offsets

    private static let bodyOffset:      Int = 0
    private static let bodyCount:       Int = 33
    private static let faceOffset:      Int = 33
    private static let faceCount:       Int = 68
    private static let lHandOffset:     Int = 33 + 68          // 101
    private static let rHandOffset:     Int = 33 + 68 + 21     // 122
    private static let handCount:       Int = 21
    private static let vertexCount:     Int = 33 + 68 + 21 + 21 // 143

    // Material slot indices.
    private static let matWhite:  Int = 0
    private static let matCyan:   Int = 1
    private static let matPink:   Int = 2
    private static let matGrey:   Int = 3

    // MARK: - Tunables

    private static let handScale3D: Float = 0.18      // typical hand size (m)
    private static let faceForwardOffset: Float = 0.05
    private static let minConfidence: Float = 0.3
    private static let retainSec: TimeInterval = 1.0
    private static let updatePeriod: TimeInterval = 1.0 / 30.0

    // MARK: - Per-person state

    private struct PartLayout {
        /// Per-material : list of (vertex-slot-a, vertex-slot-b) edges.
        var edges: [(Int, Int)]
        /// Pre-computed index range in the global index buffer.
        var indexOffset: Int
        var indexCount: Int
    }

    private struct PersonEntities {
        var root: Entity
        var modelEntity: ModelEntity
        var mesh: LowLevelMesh
        /// Per-material part layout (4 parts). Indices are baked at
        /// build time, only vertex positions change per frame.
        var parts: [PartLayout]
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
    private var pelvisOffsets: [Int: SIMD3<Float>] = [:]

    // MARK: - Public API

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
        poseSub?.cancel(); poseSub = nil
        faceSub?.cancel(); faceSub = nil
        handSub?.cancel(); handSub = nil
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

        for pid in frames.keys { lastSeenAt[pid] = now }
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

    /// Build the full vertex array (143 SIMD3<Float>) for a given frame.
    /// Invalid points are emitted at SIMD3<Float>(NaN, NaN, NaN) so the
    /// edge culling pass downstream can collapse incident edges.
    private func buildVertices(frame: PoseOSCListener.Pose3DFrame,
                               pid: Int)
        -> (vertices: [SIMD3<Float>], valid: [Bool])
    {
        var v = [SIMD3<Float>](repeating: .zero, count: Self.vertexCount)
        var ok = [Bool](repeating: false, count: Self.vertexCount)

        // ---- Body (33 slots) ----
        var rk = [SIMD3<Float>](repeating: .zero, count: 33)
        for i in 0..<33 {
            let k = frame.kps[i]
            let visible = frame.hasPoint[i] && k.w >= Self.minConfidence
            rk[i] = SIMD3<Float>(k.x, -k.y, -k.z)
            v[Self.bodyOffset + i] = rk[i]
            ok[Self.bodyOffset + i] = visible
        }

        // ---- Face (68 slots) anchored on body nose rk[0] ----
        let nose = ok[Self.bodyOffset + 0] ? rk[0] : SIMD3<Float>(0, 0, 0)
        if let face = lastFace[pid], ok[Self.bodyOffset + 0] {
            // Head width in 3D from ears, fallback 0.18 m.
            let headWidth3D: Float
            if ok[Self.bodyOffset + 7] && ok[Self.bodyOffset + 8] {
                headWidth3D = max(0.10, simd_length(rk[7] - rk[8]))
            } else {
                headWidth3D = 0.18
            }
            // 2D bbox of face points.
            var minX: Float =  .infinity, maxX: Float = -.infinity
            var sumX: Float = 0, sumY: Float = 0
            var n: Float = 0
            for i in 0..<68 where face.hasPoint[i] {
                let p = face.points[i]
                if p.x < minX { minX = p.x }
                if p.x > maxX { maxX = p.x }
                sumX += p.x; sumY += p.y; n += 1
            }
            if n > 4 && maxX > minX {
                let face2DWidth = max(maxX - minX, 1e-4)
                let scale = headWidth3D / face2DWidth
                let cx = sumX / n
                let cy = sumY / n
                for i in 0..<68 {
                    let slot = Self.faceOffset + i
                    if face.hasPoint[i] {
                        let dx = face.points[i].x - cx
                        let dy = face.points[i].y - cy
                        v[slot] = nose + SIMD3<Float>(
                            dx * scale,
                            -dy * scale,
                            Self.faceForwardOffset)
                        ok[slot] = true
                    }
                }
            }
        }

        // ---- Hands (21 + 21) anchored on rk[15]/rk[16] ----
        for (_, hand) in lastHands {
            let isLeft = (hand.side == 0)
            let wristIdx = isLeft ? 15 : 16
            guard ok[Self.bodyOffset + wristIdx] else { continue }
            let wrist = rk[wristIdx]
            let baseOffset = isLeft ? Self.lHandOffset : Self.rHandOffset

            var sumX: Float = 0, sumY: Float = 0, n: Float = 0
            for i in 0..<21 where hand.hasPoint[i] {
                sumX += hand.points[i].x
                sumY += hand.points[i].y
                n += 1
            }
            guard n > 2 else { continue }
            let cx = sumX / n
            let cy = sumY / n
            let s = Self.handScale3D
            for i in 0..<21 {
                let slot = baseOffset + i
                if hand.hasPoint[i] {
                    let dx = hand.points[i].x - cx
                    let dy = hand.points[i].y - cy
                    v[slot] = wrist + SIMD3<Float>(dx * s, -dy * s, 0)
                    ok[slot] = true
                }
            }
        }

        return (v, ok)
    }

    private func apply(frame: PoseOSCListener.Pose3DFrame,
                       pid: Int,
                       to entities: PersonEntities) {
        let built = buildVertices(frame: frame, pid: pid)
        let v = built.vertices
        let ok = built.valid

        // Push vertices into the LowLevelMesh. Edges whose endpoints
        // are invalid get the second endpoint collapsed onto the first
        // (zero-length line, invisible).
        entities.mesh.withUnsafeMutableBytes(bufferIndex: 0) { ptr in
            let dst = ptr.bindMemory(to: SIMD3<Float>.self)
            let n = min(dst.count, v.count)
            for i in 0..<n { dst[i] = v[i] }
        }

        // Rewrite the index buffer slot-by-slot only for edges whose
        // validity changed. For simplicity (and since the buffer is
        // small : ~280 indices), rewrite the whole index buffer each
        // frame, collapsing invalid edges to a single repeated slot.
        // This is cheap enough at 30 Hz.
        entities.mesh.withUnsafeMutableIndices { ptr in
            let dst = ptr.bindMemory(to: UInt32.self)
            var cursor = 0
            for part in entities.parts {
                for (a, b) in part.edges {
                    let validEdge = ok[a] && ok[b]
                    if validEdge {
                        dst[cursor] = UInt32(a)
                        dst[cursor + 1] = UInt32(b)
                    } else {
                        // Degenerate edge : both indices point to a, so
                        // the line has zero length and renders nothing.
                        dst[cursor] = UInt32(a)
                        dst[cursor + 1] = UInt32(a)
                    }
                    cursor += 2
                }
            }
        }
    }

    // MARK: - Construction

    /// Compute the flat edge list per material, in the order matWhite,
    /// matCyan, matPink, matGrey. Returns the parts plus the total
    /// index count.
    private func buildEdgeTable() -> [PartLayout] {
        var byMat: [Int: [(Int, Int)]] = [
            Self.matWhite: [],
            Self.matCyan:  [],
            Self.matPink:  [],
            Self.matGrey:  [],
        ]

        // ---- Body bones ----
        for (a, b, chain) in Self.POSE_CONNECTIONS {
            byMat[chain.materialIndex, default: []].append(
                (Self.bodyOffset + a, Self.bodyOffset + b))
        }

        // ---- Face chains (grey) ----
        for chain in Self.FACE_CHAINS {
            guard chain.count >= 2 else { continue }
            for k in 0..<(chain.count - 1) {
                byMat[Self.matGrey, default: []].append((
                    Self.faceOffset + chain[k],
                    Self.faceOffset + chain[k + 1]))
            }
        }

        // ---- Hand chains : left=cyan, right=pink ----
        for chain in Self.HAND_CHAINS {
            guard chain.count >= 2 else { continue }
            for k in 0..<(chain.count - 1) {
                byMat[Self.matCyan, default: []].append((
                    Self.lHandOffset + chain[k],
                    Self.lHandOffset + chain[k + 1]))
                byMat[Self.matPink, default: []].append((
                    Self.rHandOffset + chain[k],
                    Self.rHandOffset + chain[k + 1]))
            }
        }

        // ---- Anatomical connectors (white) ----
        // body nose (0) -> face nose-bridge top (slot 27)
        byMat[Self.matWhite, default: []].append((
            Self.bodyOffset + 0, Self.faceOffset + 27))
        // body left wrist (15) -> left hand wrist (idx 0)
        byMat[Self.matWhite, default: []].append((
            Self.bodyOffset + 15, Self.lHandOffset + 0))
        // body right wrist (16) -> right hand wrist (idx 0)
        byMat[Self.matWhite, default: []].append((
            Self.bodyOffset + 16, Self.rHandOffset + 0))

        var parts: [PartLayout] = []
        var cursor = 0
        for mat in 0..<4 {
            let edges = byMat[mat] ?? []
            let ic = edges.count * 2
            parts.append(PartLayout(
                edges: edges, indexOffset: cursor, indexCount: ic))
            cursor += ic
        }
        return parts
    }

    private func makePerson(pid: Int, parent: Entity) -> PersonEntities {
        let root = Entity()
        parent.addChild(root)
        if let off = pelvisOffsets[pid] {
            root.transform.translation = off
        }

        let parts = buildEdgeTable()
        let totalIndices = parts.reduce(0) { $0 + $1.indexCount }

        // Build LowLevelMesh : single position buffer (float3), line
        // topology, 4 parts referencing 4 materials.
        let posAttr = LowLevelMesh.Attribute(
            semantic: .position, format: .float3, offset: 0)
        let posLayout = LowLevelMesh.Layout(
            bufferIndex: 0,
            bufferStride: MemoryLayout<SIMD3<Float>>.stride)
        let desc = LowLevelMesh.Descriptor(
            vertexCapacity: Self.vertexCount,
            vertexAttributes: [posAttr],
            vertexLayouts: [posLayout],
            indexCapacity: max(totalIndices, 2),
            indexType: .uint32)

        guard let mesh = try? LowLevelMesh(descriptor: desc) else {
            // Fallback : empty entity, log and bail.
            NSLog("Skeleton3DRenderer: LowLevelMesh creation FAILED pid=%d", pid)
            let dummy = ModelEntity()
            root.addChild(dummy)
            return PersonEntities(
                root: root, modelEntity: dummy,
                mesh: try! LowLevelMesh(descriptor: desc),
                parts: parts)
        }

        // Init vertices to zero (everything collapses at origin until
        // the first frame arrives).
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { ptr in
            let dst = ptr.bindMemory(to: SIMD3<Float>.self)
            for i in 0..<min(dst.count, Self.vertexCount) {
                dst[i] = .zero
            }
        }

        // Bake the index buffer once. Edges are collapsed/restored at
        // apply() time only by rewriting them in place ; the layout is
        // fixed.
        mesh.withUnsafeMutableIndices { ptr in
            let dst = ptr.bindMemory(to: UInt32.self)
            var cursor = 0
            for part in parts {
                for (a, _) in part.edges {
                    // Start collapsed (a, a) — invisible until first frame.
                    dst[cursor]     = UInt32(a)
                    dst[cursor + 1] = UInt32(a)
                    cursor += 2
                }
            }
        }

        // Configure parts (one per material). UnlitMaterial works fine
        // with line topology and is the cheapest path.
        let bounds = BoundingBox(min: SIMD3(-4, -4, -4),
                                 max: SIMD3(4, 4, 4))
        var meshParts: [LowLevelMesh.Part] = []
        for (i, p) in parts.enumerated() {
            meshParts.append(.init(
                indexOffset: p.indexOffset * MemoryLayout<UInt32>.size,
                indexCount: max(p.indexCount, 0),
                topology: .line,
                materialIndex: i,
                bounds: bounds))
        }
        mesh.parts.replaceAll(meshParts)

        // Materials per chain group.
        let materials: [any RealityKit.Material] = [
            UnlitMaterial(color: .white),                       // 0 trunk + connectors
            UnlitMaterial(color: .systemTeal),                  // 1 arms + L hand
            UnlitMaterial(color: .systemPink),                  // 2 legs + R hand
            UnlitMaterial(color: NSColor(white: 0.85,
                                         alpha: 1.0)),          // 3 face
        ]

        var modelEntity = ModelEntity()
        if let resource = try? MeshResource(from: mesh) {
            modelEntity = ModelEntity(mesh: resource,
                                      materials: materials)
        }
        root.addChild(modelEntity)

        NSLog("Skeleton3DRenderer: spawned pid=%d (1 fused LowLevelMesh, %d verts, %d line indices, 4 parts)",
              pid, Self.vertexCount, totalIndices)

        return PersonEntities(
            root: root,
            modelEntity: modelEntity,
            mesh: mesh,
            parts: parts)
    }
}
