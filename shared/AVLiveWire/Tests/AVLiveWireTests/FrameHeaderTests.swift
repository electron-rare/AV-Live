import XCTest
@testable import AVLiveWire

final class FrameHeaderTests: XCTestCase {
    func testRoundTrip() {
        let h = FrameHeader(tag: .skeleton, pid: 7,
                            timestamp: 12.5, length: 1092)
        let bytes = h.encoded()
        XCTAssertEqual(bytes.count, FrameHeader.byteCount)
        let decoded = FrameHeader(decoding: bytes)
        XCTAssertEqual(decoded, h)
    }

    func testRejectsBadMagic() {
        var bytes = FrameHeader(tag: .video, pid: -1,
                                timestamp: 0, length: 0).encoded()
        bytes[0] = 0x00
        XCTAssertNil(FrameHeader(decoding: bytes))
    }

    func testRejectsShortBuffer() {
        XCTAssertNil(FrameHeader(decoding: Data([0x41, 0x56])))
    }
}
