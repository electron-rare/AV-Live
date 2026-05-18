import XCTest
@testable import AVLiveWire

final class WirePayloadsTests: XCTestCase {
    func testSkeletonRoundTrip() {
        var f = SkeletonPayload()
        f.joints[0] = SIMD3(1, 2, 3)
        f.valid[0] = true
        f.joints[90] = SIMD3(-4, 5, -6)
        f.valid[90] = true
        let decoded = SkeletonPayload(decoding: f.encoded())
        XCTAssertEqual(decoded, f)
    }

    func testSkeletonRejectsWrongSize() {
        XCTAssertNil(SkeletonPayload(decoding: Data([0, 1, 2])))
    }

    func testVideoPayloadRoundTrip() {
        let p = VideoPayload(isKeyframe: true,
                             data: Data([9, 8, 7, 6]))
        let decoded = VideoPayload(decoding: p.encoded())
        XCTAssertEqual(decoded, p)
    }
}
