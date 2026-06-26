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

    func testHandsPayloadRoundTrip() {
        let left = HandsPayload.Hand(
            isRight: false,
            points: (0..<21).map { SIMD3(Float($0) * 0.01,
                                         Float($0) * 0.02, 0.9) })
        let right = HandsPayload.Hand(
            isRight: true,
            points: (0..<21).map { SIMD3(Float($0) * 0.03,
                                         Float($0) * 0.04, 0.5) })
        let p = HandsPayload(hands: [left, right])
        let decoded = HandsPayload(decoding: p.encoded())
        XCTAssertEqual(decoded, p)
        XCTAssertEqual(decoded?.hands.count, 2)
        XCTAssertEqual(decoded?.hands[0].isRight, false)
        XCTAssertEqual(decoded?.hands[1].isRight, true)
    }

    func testHandsPayloadEmpty() {
        let p = HandsPayload(hands: [])
        let decoded = HandsPayload(decoding: p.encoded())
        XCTAssertEqual(decoded?.hands.count, 0)
    }

    func testHandsPayloadRejectsTruncated() {
        let p = HandsPayload(hands: [
            HandsPayload.Hand(isRight: false,
                              points: Array(repeating: .zero, count: 21))])
        let bad = p.encoded().dropLast()
        XCTAssertNil(HandsPayload(decoding: bad))
    }

    func testFacePayloadRoundTrip() {
        let pts = (0..<76).map { SIMD2(Float($0) * 0.001,
                                       Float($0) * 0.002) }
        let p = FacePayload(confidence: 0.87, points: pts)
        let decoded = FacePayload(decoding: p.encoded())
        XCTAssertEqual(decoded, p)
        XCTAssertEqual(decoded?.points.count, 76)
        XCTAssertEqual(decoded?.confidence, 0.87)
    }

    func testFacePayloadRejectsTruncated() {
        let p = FacePayload(confidence: 0.5,
                            points: [SIMD2(0.1, 0.2)])
        XCTAssertNil(FacePayload(decoding: p.encoded().dropLast()))
    }
}
