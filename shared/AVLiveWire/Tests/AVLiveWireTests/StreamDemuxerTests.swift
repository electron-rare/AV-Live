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

    func testPartialMagicAtBoundary() {
        var d = StreamDemuxer()
        XCTAssertTrue(d.feed(Data([0x41, 0x56, 0x4C])).isEmpty)
        let payload = Data([42])
        let h = FrameHeader(tag: .meta, pid: 0, timestamp: 0,
                            length: UInt32(payload.count))
        var rest = Data([0x31])
        rest.append(h.encoded().dropFirst(4))
        rest.append(payload)
        let out = d.feed(rest)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].payload, payload)
    }

    func testSkipsCorruptOversizedLength() {
        var d = StreamDemuxer()
        // Header claiming a 4 GB payload, then a valid frame after.
        let bad = FrameHeader(tag: .video, pid: 0, timestamp: 0,
                              length: UInt32.max).encoded()
        let good = frame(.video, Data([5, 5]))
        let out = d.feed(bad + good)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].payload, Data([5, 5]))
    }
}
