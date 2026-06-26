// avlivebody-mac/Sources/AVLiveBody/HandFaceSkeleton.swift
import AVLiveWire
import AppKit
import RealityKit
import simd

@MainActor
final class HandFaceSkeleton {
    let root = Entity()
    private static let r: Float = 0.008
    private static let spanX: Float = 1.2   // maps [0,1] -> [-0.6,0.6] m
    private static let spanY: Float = 0.9

    private let mesh = MeshResource.generateSphere(radius: r)
    private let handMat = SimpleMaterial(color: NSColor.cyan, isMetallic: false)
    private let faceMat = SimpleMaterial(color: NSColor.magenta, isMetallic: false)
    private var handPool: [ModelEntity] = []
    private var facePool: [ModelEntity] = []
    private var depth: Float = 0

    func setDepth(_ z: Float) { depth = z }

    func update(hands: HandsPayload?, face: FacePayload?) {
        let hpts = (hands?.hands ?? []).flatMap { $0.points }
        layout(&handPool, count: hpts.count, mat: handMat)
        for (i, p) in hpts.enumerated() { place(handPool[i], p.x, p.y) }
        for i in hpts.count..<handPool.count { handPool[i].isEnabled = false }

        let fpts = face?.points ?? []
        layout(&facePool, count: fpts.count, mat: faceMat)
        for (i, p) in fpts.enumerated() { place(facePool[i], p.x, p.y) }
        for i in fpts.count..<facePool.count { facePool[i].isEnabled = false }
    }

    private func place(_ e: ModelEntity, _ nx: Float, _ ny: Float) {
        // normalized top-left [0,1] -> centered meters, y up
        e.transform.translation = SIMD3<Float>(
            (nx - 0.5) * Self.spanX,
            (0.5 - ny) * Self.spanY,
            depth)
        e.isEnabled = true
    }

    private func layout(_ pool: inout [ModelEntity], count: Int,
                        mat: SimpleMaterial) {
        while pool.count < count {
            let e = ModelEntity(mesh: mesh, materials: [mat])
            root.addChild(e); pool.append(e)
        }
    }
}
