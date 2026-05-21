import Foundation

public struct StreamDemuxer {
    public struct Frame: Equatable {
        public let header: FrameHeader
        public let payload: Data
    }

    /// Largest plausible payload (8 MB) — comfortably covers any HEVC
    /// access unit. A header claiming more is treated as corrupt.
    public static let maxPayloadLength: UInt32 = 8 * 1024 * 1024

    private var buffer = Data()
    public init() {}

    /// Append bytes; return every complete frame now available.
    public mutating func feed(_ chunk: Data) -> [Frame] {
        buffer.append(chunk)
        var out: [Frame] = []
        while true {
            guard let start = findMagic() else {
                // keep at most 3 trailing bytes (partial magic)
                if buffer.count > 3 {
                    buffer = buffer.suffix(3)
                }
                break
            }
            if start > 0 { buffer.removeFirst(start) }
            guard buffer.count >= FrameHeader.byteCount,
                  let h = FrameHeader(decoding: buffer) else { break }
            if h.length > Self.maxPayloadLength {
                // Implausible length — corrupt header; skip the magic
                // and resync on the next one.
                buffer.removeFirst(FrameHeader.magic.count)
                continue
            }
            let total = FrameHeader.byteCount + Int(h.length)
            guard buffer.count >= total else { break }
            let payloadStart = buffer.index(
                buffer.startIndex, offsetBy: FrameHeader.byteCount)
            let payloadEnd = buffer.index(
                buffer.startIndex, offsetBy: total)
            out.append(Frame(header: h,
                payload: Data(buffer[payloadStart..<payloadEnd])))
            buffer.removeFirst(total)
        }
        return out
    }

    private func findMagic() -> Int? {
        let m = FrameHeader.magic
        let bytes = [UInt8](buffer)
        guard bytes.count >= m.count else { return nil }
        for i in 0...(bytes.count - m.count) {
            if Array(bytes[i..<i+m.count]) == m { return i }
        }
        return nil
    }
}
