import Foundation
import simd

/// 91 ARKit joints in world space + a per-joint validity flag.
public struct SkeletonPayload: Equatable {
    public static let jointCount = 91
    /// 91 * 3 * 4 bytes (floats) + 91 validity bytes.
    public static let byteCount = jointCount * 12 + jointCount

    public var joints: [SIMD3<Float>]
    public var valid: [Bool]

    public init() {
        joints = Array(repeating: .zero, count: Self.jointCount)
        valid = Array(repeating: false, count: Self.jointCount)
    }

    public func encoded() -> Data {
        var d = Data(capacity: Self.byteCount)
        for j in joints {
            d.appendBE(j.x.bitPattern); d.appendBE(j.y.bitPattern)
            d.appendBE(j.z.bitPattern)
        }
        for v in valid { d.append(v ? 1 : 0) }
        return d
    }

    public init?(decoding data: Data) {
        guard data.count == Self.byteCount else { return nil }
        let b = [UInt8](data)
        self.init()
        var o = 0
        for i in 0..<Self.jointCount {
            func f() -> Float {
                let v = Float(bitPattern:
                    UInt32(bigEndianBytes: b[o..<o+4]))
                o += 4; return v
            }
            joints[i] = SIMD3(f(), f(), f())
        }
        for i in 0..<Self.jointCount { valid[i] = b[o + i] != 0 }
    }
}

/// One HEVC access unit + a keyframe flag.
public struct VideoPayload: Equatable {
    public var isKeyframe: Bool
    public var data: Data

    public init(isKeyframe: Bool, data: Data) {
        self.isKeyframe = isKeyframe; self.data = data
    }

    public func encoded() -> Data {
        var d = Data([isKeyframe ? 1 : 0])
        d.append(data)
        return d
    }

    public init?(decoding data: Data) {
        guard let first = data.first else { return nil }
        isKeyframe = first != 0
        self.data = data.dropFirst()
    }
}
