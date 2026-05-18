import Foundation
import simd

/// ARKit/Multi-HMR world coords (y up, z back) -> RealityKit world
/// coords (y up, z forward). Apply to every vertex/translation that
/// crosses from source pipeline space into the scene.
@inline(__always)
func arkitToRealityKit(_ v: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(v.x, -v.y, -v.z)
}
