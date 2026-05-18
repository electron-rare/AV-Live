import XCTest
import AVLiveWire
@testable import AVLiveBody

final class USBSkeletonConsumerTests: XCTestCase {
    func testSkeletonPayloadMapsToBodyFrame() {
        var p = SkeletonPayload()
        p.joints[0] = SIMD3(1, 2, 3)
        p.valid[0] = true
        p.joints[90] = SIMD3(-4, 5, -6)
        p.valid[90] = true
        let frame = USBSkeletonConsumer.bodyFrame(pid: 7, from: p)
        XCTAssertEqual(frame.pid, 7)
        XCTAssertEqual(frame.joints.count, 91)
        XCTAssertEqual(frame.hasJoint.count, 91)
        XCTAssertEqual(frame.joints[0], SIMD3(1, 2, 3))
        XCTAssertTrue(frame.hasJoint[0])
        XCTAssertEqual(frame.joints[90], SIMD3(-4, 5, -6))
        XCTAssertFalse(frame.hasJoint[1])
    }
}
