import XCTest
@testable import AVLiveWire

final class StreamDemuxerTests: XCTestCase {
    private func frame(_ tag: FrameTag, _ payload: Data) -> Data {
        let h = FrameHeader(tag: tag, pid: 0, timestamp: 1,
                            length: UInt32(payload.count))
        return h.encoded() + payload
    }

    func testSingleFrame() {
        var d = StreamDemuxer()
        let out = d.feed(frame(.video, Data([1, 2, 3])))
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].payload, Data([1, 2, 3]))
    }

    func testSplitAcrossChunks() {
        var d = StreamDemuxer()
        let whole = frame(.video, Data([9, 9, 9, 9, 9]))
        XCTAssertTrue(d.feed(whole.prefix(10)).isEmpty)
        let out = d.feed(whole.dropFirst(10))
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].payload, Data([9, 9, 9, 9, 9]))
    }

    func testTwoFramesOneChunk() {
        var d = StreamDemuxer()
        let out = d.feed(frame(.meta, Data([1]))
                         + frame(.video, Data([2, 2])))
        XCTAssertEqual(out.count, 2)
    }

    func testResyncAfterGarbage() {
        var d = StreamDemuxer()
        let out = d.feed(Data([0xDE, 0xAD])
                         + frame(.video, Data([7])))
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].payload, Data([7]))
    }
}
