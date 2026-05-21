import XCTest
import AVLiveWire
@testable import AVLiveBody

final class BodyFusionTests: XCTestCase {
    private func skeleton(pelvisZ: Float) -> SkeletonPayload {
        var p = SkeletonPayload()
        p.joints[0] = SIMD3(0, 0, pelvisZ)
        p.valid[0] = true
        return p
    }

    func testPelvisDepthOverride() {
        let mesh = MultiHMRPerson(
            vertices: [SIMD3<Float>](repeating: .zero, count: 1),
            translation: SIMD3(0, 0, -1.0), score: 0.9)
        let fused = BodyFusion.fuse(
            persons: [mesh], skeletons: [0: skeleton(pelvisZ: -2.5)])
        XCTAssertEqual(fused[0].translation.z, -2.5, accuracy: 1e-4)
    }

    func testPassthroughWhenNoSkeleton() {
        let mesh = MultiHMRPerson(
            vertices: [SIMD3<Float>](repeating: .zero, count: 1),
            translation: SIMD3(0, 0, -1.0), score: 0.9)
        let fused = BodyFusion.fuse(persons: [mesh], skeletons: [:])
        XCTAssertEqual(fused[0].translation.z, -1.0, accuracy: 1e-4)
    }
}
