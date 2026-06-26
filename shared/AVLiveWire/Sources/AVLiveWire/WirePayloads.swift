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

/// Up to N hands; each = chirality + 21 (x, y, confidence) points in
/// normalized image coordinates [0,1].
public struct HandsPayload: Equatable {
    public static let pointsPerHand = 21

    public struct Hand: Equatable {
        public var isRight: Bool
        public var points: [SIMD3<Float>]
        public init(isRight: Bool, points: [SIMD3<Float>]) {
            self.isRight = isRight; self.points = points
        }
    }

    public var hands: [Hand]
    public init(hands: [Hand]) { self.hands = hands }

    public func encoded() -> Data {
        var d = Data()
        d.append(UInt8(min(hands.count, 255)))
        for hand in hands.prefix(255) {
            d.append(hand.isRight ? 1 : 0)
            for i in 0..<Self.pointsPerHand {
                let p = i < hand.points.count ? hand.points[i] : .zero
                d.appendBE(p.x.bitPattern)
                d.appendBE(p.y.bitPattern)
                d.appendBE(p.z.bitPattern)
            }
        }
        return d
    }

    public init?(decoding data: Data) {
        let b = [UInt8](data)
        guard let n = b.first else { return nil }
        let per = 1 + Self.pointsPerHand * 12
        guard b.count == 1 + Int(n) * per else { return nil }
        var o = 1
        var result: [Hand] = []
        for _ in 0..<Int(n) {
            let isRight = b[o] != 0; o += 1
            func f() -> Float {
                let v = Float(bitPattern:
                    UInt32(bigEndianBytes: b[o..<o+4]))
                o += 4; return v
            }
            var pts: [SIMD3<Float>] = []
            for _ in 0..<Self.pointsPerHand {
                pts.append(SIMD3(f(), f(), f()))
            }
            result.append(Hand(isRight: isRight, points: pts))
        }
        hands = result
    }
}

/// One face: observation confidence + N landmark points in normalized
/// image coordinates [0,1] (Vision `allPoints`, ~76).
public struct FacePayload: Equatable {
    public var confidence: Float
    public var points: [SIMD2<Float>]
    public init(confidence: Float, points: [SIMD2<Float>]) {
        self.confidence = confidence; self.points = points
    }

    public func encoded() -> Data {
        var d = Data()
        d.appendBE(confidence.bitPattern)
        d.appendBE(UInt16(min(points.count, 65535)))
        for p in points {
            d.appendBE(p.x.bitPattern); d.appendBE(p.y.bitPattern)
        }
        return d
    }

    public init?(decoding data: Data) {
        let b = [UInt8](data)
        guard b.count >= 6 else { return nil }
        var o = 0
        func f() -> Float {
            let v = Float(bitPattern: UInt32(bigEndianBytes: b[o..<o+4]))
            o += 4; return v
        }
        confidence = f()
        let n = Int(UInt16(bigEndianBytes: b[o..<o+2])); o += 2
        guard b.count == 6 + n * 8 else { return nil }
        var pts: [SIMD2<Float>] = []
        for _ in 0..<n { pts.append(SIMD2(f(), f())) }
        points = pts
    }
}
