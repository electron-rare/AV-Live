import XCTest
@testable import AVLiveWire

/// Feeds an encoded frame stream through the demuxer in 7-byte
/// chunks — the worst-case fragmentation a TCP tunnel can produce.
final class LoopbackTests: XCTestCase {
    func testManyFramesChunked() {
        var skel = SkeletonPayload()
        skel.valid[0] = true
        skel.joints[0] = SIMD3(1, 1, 1)

        var stream = Data()
        for i in 0..<20 {
            let payload = skel.encoded()
            let h = FrameHeader(tag: .skeleton, pid: Int16(i),
                timestamp: Double(i),
                length: UInt32(payload.count))
            stream += h.encoded() + payload
        }

        var demux = StreamDemuxer()
        var frames: [StreamDemuxer.Frame] = []
        var offset = 0
        while offset < stream.count {
            let end = min(offset + 7, stream.count)
            let lo = stream.index(stream.startIndex, offsetBy: offset)
            let hi = stream.index(stream.startIndex, offsetBy: end)
            frames += demux.feed(Data(stream[lo..<hi]))
            offset = end
        }

        XCTAssertEqual(frames.count, 20)
        XCTAssertEqual(frames[5].header.pid, 5)
        XCTAssertEqual(SkeletonPayload(decoding: frames[5].payload),
                       skel)
    }
}
