import XCTest
@testable import AVLiveWire

final class Skeleton2DPayloadTests: XCTestCase {
    func testRoundTrip() {
        var p = Skeleton2DPayload()
        for i in 0..<Skeleton2DPayload.jointCount {
            p.points[i] = SIMD2(Float(i) * 0.001, Float(i) * 0.002)
            p.valid[i] = (i % 2 == 0)
        }
        let data = p.encoded()
        let r = Skeleton2DPayload(decoding: data)
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.points[10].x, p.points[10].x, accuracy: 1e-6)
        XCTAssertEqual(r!.valid[10], p.valid[10])
        XCTAssertEqual(r!.valid[11], p.valid[11])
    }

    func testByteCount() {
        // 91 joints × 2 floats × 4 bytes + 91 valid bytes = 91*8+91 = 819
        XCTAssertEqual(Skeleton2DPayload.byteCount, 91 * 8 + 91)
    }

    func testRejectsWrongSize() {
        XCTAssertNil(Skeleton2DPayload(decoding: Data([0, 1, 2])))
    }

    func testFrameTagSkeleton2D() {
        XCTAssertEqual(FrameTag.skeleton2D.rawValue, 6)
    }
}
