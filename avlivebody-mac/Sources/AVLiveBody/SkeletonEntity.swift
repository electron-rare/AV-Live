import AVLiveWire
import AppKit
import Foundation
import RealityKit
import simd

/// Renders 91-joint skeletons as yellow marker spheres. One marker
/// pool per pid. ARKit world coords -> RealityKit space (x, -y, -z).
@MainActor
final class SkeletonEntity {
    let root = Entity()

    private static let jointCount = 91
    private static let markerRadius: Float = 0.012

    private var pools: [Int: [ModelEntity]] = [:]
    private let mesh = MeshResource.generateSphere(radius: markerRadius)
    private let material = SimpleMaterial(
        color: NSColor.systemYellow, roughness: 0.6, isMetallic: false)

    func update(_ skeletons: [Int: SkeletonPayload]) {
        // Drop pools for pids no longer present.
        for pid in pools.keys where skeletons[pid] == nil {
            pools[pid]?.forEach { $0.removeFromParent() }
            pools.removeValue(forKey: pid)
        }
        for (pid, payload) in skeletons {
            let pool = pools[pid] ?? makePool()
            pools[pid] = pool
            let n = min(Self.jointCount, payload.joints.count,
                        payload.valid.count)
            for i in 0..<n {
                let marker = pool[i]
                if payload.valid[i] {
                    let j = payload.joints[i]
                    marker.transform.translation =
                        SIMD3<Float>(j.x, -j.y, -j.z)
                    marker.isEnabled = true
                } else {
                    marker.isEnabled = false
                }
            }
        }
    }

    private func makePool() -> [ModelEntity] {
        var pool: [ModelEntity] = []
        pool.reserveCapacity(Self.jointCount)
        for _ in 0..<Self.jointCount {
            let e = ModelEntity(mesh: mesh, materials: [material])
            e.isEnabled = false
            root.addChild(e)
            pool.append(e)
        }
        return pool
    }
}
