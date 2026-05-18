import Foundation

public enum FrameTag: UInt8 {
    case skeleton = 1
    case video = 2
    case meta = 3
}

/// Fixed-size frame header. Layout (big-endian):
/// magic[4]=`AVL1` | tag u8 | pid i16 | timestamp f64 | length u32
public struct FrameHeader: Equatable {
    public static let magic: [UInt8] = [0x41, 0x56, 0x4C, 0x31]
    public static let byteCount = 19

    public var tag: FrameTag
    public var pid: Int16
    public var timestamp: Double
    public var length: UInt32

    public init(tag: FrameTag, pid: Int16,
                timestamp: Double, length: UInt32) {
        self.tag = tag; self.pid = pid
        self.timestamp = timestamp; self.length = length
    }

    public func encoded() -> Data {
        var d = Data(Self.magic)
        d.append(tag.rawValue)
        d.appendBE(UInt16(bitPattern: pid))
        d.appendBE(timestamp.bitPattern)
        d.appendBE(length)
        return d
    }

    public init?(decoding data: Data) {
        guard data.count >= Self.byteCount else { return nil }
        let b = [UInt8](data.prefix(Self.byteCount))
        guard Array(b[0..<4]) == Self.magic,
              let t = FrameTag(rawValue: b[4]) else { return nil }
        tag = t
        pid = Int16(bitPattern: UInt16(bigEndianBytes: b[5...6]))
        timestamp = Double(bitPattern: UInt64(bigEndianBytes: b[7...14]))
        length = UInt32(bigEndianBytes: b[15...18])
    }
}

extension Data {
    mutating func appendBE(_ v: UInt16) {
        appendBE(UInt64(v), width: 2) }
    mutating func appendBE(_ v: UInt32) {
        appendBE(UInt64(v), width: 4) }
    mutating func appendBE(_ v: UInt64, width: Int = 8) {
        for i in stride(from: width - 1, through: 0, by: -1) {
            append(UInt8((v >> (8 * i)) & 0xFF))
        }
    }
}

extension UInt16 {
    init<S: Sequence>(bigEndianBytes s: S) where S.Element == UInt8 {
        self = s.reduce(0) { ($0 << 8) | UInt16($1) }
    }
}
extension UInt32 {
    init<S: Sequence>(bigEndianBytes s: S) where S.Element == UInt8 {
        self = s.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
extension UInt64 {
    init<S: Sequence>(bigEndianBytes s: S) where S.Element == UInt8 {
        self = s.reduce(0) { ($0 << 8) | UInt64($1) }
    }
}
