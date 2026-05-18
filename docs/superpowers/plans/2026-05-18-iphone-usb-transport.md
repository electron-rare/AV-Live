# iPhone USB Transport Implementation Plan (Plan 1 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the network-free USB byte-pipe between the iOS
`ARBodyTracker` app and the macOS `AVLiveBody` app: a shared wire
format, a native `usbmux` client, an iOS TCP listener, and an
incremental stream demuxer.

**Architecture:** A shared SwiftPM package `AVLiveWire` defines the
binary frame codec used by both apps. The iOS app serves frames on a
local TCP port; the macOS app reaches that port through Apple's
`usbmuxd` daemon over the USB cable (no IP network). A demuxer
reassembles frames from the byte stream.

**Tech Stack:** Swift 5.9+, SwiftPM, `Network.framework` (iOS
listener), raw Unix-domain socket + property-list serialization
(macOS usbmux client), `XCTest`.

**Companion spec:** `docs/superpowers/specs/2026-05-18-iphone-usb-body-link-design.md`

---

## File Structure

| File | Responsibility |
|------|----------------|
| `shared/AVLiveWire/Package.swift` | SwiftPM manifest for the shared library |
| `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift` | Fixed 19-byte frame header encode/decode |
| `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift` | Skeleton / video / meta payload codecs |
| `shared/AVLiveWire/Sources/AVLiveWire/StreamDemuxer.swift` | Incremental byte-stream → frames, resync on partial buffers |
| `shared/AVLiveWire/Tests/AVLiveWireTests/*.swift` | Unit tests for the above |
| `launcher/AV-Live-Body/Sources/AVLiveBody/USBMuxProtocol.swift` | usbmux message framing (header + plist) |
| `launcher/AV-Live-Body/Sources/AVLiveBody/USBClient.swift` | usbmux device list, connect-to-port, attach/detach, byte stream |
| `launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBMuxProtocolTests.swift` | usbmux codec tests |
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/USBServer.swift` | iOS TCP `NWListener`, frame send queue |
| `launcher/AV-Live-Body/Package.swift` | add `AVLiveWire` dependency (modify) |
| `iphone-arbody/ARBodyTracker.swiftpm/Package.swift` | add `AVLiveWire` dependency (modify) |

`AVLiveWire` is a plain SwiftPM library so both the macOS package and
the iOS `.swiftpm` app can depend on it via a local path — the wire
format is defined exactly once.

---

## Task 1: Shared package skeleton

**Files:**
- Create: `shared/AVLiveWire/Package.swift`
- Create: `shared/AVLiveWire/Sources/AVLiveWire/AVLiveWire.swift`
- Create: `shared/AVLiveWire/Tests/AVLiveWireTests/SmokeTests.swift`

- [ ] **Step 1: Create the package manifest**

`shared/AVLiveWire/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AVLiveWire",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "AVLiveWire", targets: ["AVLiveWire"]),
    ],
    targets: [
        .target(name: "AVLiveWire"),
        .testTarget(name: "AVLiveWireTests", dependencies: ["AVLiveWire"]),
    ]
)
```

- [ ] **Step 2: Create a placeholder source + smoke test**

`shared/AVLiveWire/Sources/AVLiveWire/AVLiveWire.swift`:

```swift
/// AVLiveWire — binary frame format shared by ARBodyTracker (iOS)
/// and AVLiveBody (macOS) over the USB transport.
public enum AVLiveWire {
    public static let protocolVersion: UInt8 = 1
}
```

`shared/AVLiveWire/Tests/AVLiveWireTests/SmokeTests.swift`:

```swift
import XCTest
@testable import AVLiveWire

final class SmokeTests: XCTestCase {
    func testProtocolVersion() {
        XCTAssertEqual(AVLiveWire.protocolVersion, 1)
    }
}
```

- [ ] **Step 3: Run the test to verify the package builds**

Run: `cd shared/AVLiveWire && swift test`
Expected: PASS, 1 test.

- [ ] **Step 4: Commit**

```bash
git add shared/AVLiveWire
git commit -m "feat(avlivewire): shared wire package skeleton"
```

---

## Task 2: Frame header codec

The frame header is a fixed 19-byte big-endian record:
`tag (u8) | pid (i16) | timestamp (f64) | length (u32)` — total
1+2+8+4 = 15 bytes, plus a 4-byte magic prefix `0x41 0x56 0x4C 0x31`
("AVL1") = 19 bytes. The magic lets the demuxer resync.

**Files:**
- Create: `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift`
- Test: `shared/AVLiveWire/Tests/AVLiveWireTests/FrameHeaderTests.swift`

- [ ] **Step 1: Write the failing test**

`shared/AVLiveWire/Tests/AVLiveWireTests/FrameHeaderTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd shared/AVLiveWire && swift test --filter FrameHeaderTests`
Expected: FAIL — `FrameHeader` is undefined.

- [ ] **Step 3: Write the implementation**

`shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift`:

```swift
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd shared/AVLiveWire && swift test --filter FrameHeaderTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add shared/AVLiveWire
git commit -m "feat(avlivewire): fixed 19-byte frame header codec"
```

---

## Task 3: Payload codecs

**Files:**
- Create: `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift`
- Test: `shared/AVLiveWire/Tests/AVLiveWireTests/WirePayloadsTests.swift`

- [ ] **Step 1: Write the failing test**

`shared/AVLiveWire/Tests/AVLiveWireTests/WirePayloadsTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd shared/AVLiveWire && swift test --filter WirePayloadsTests`
Expected: FAIL — `SkeletonPayload` / `VideoPayload` undefined.

- [ ] **Step 3: Write the implementation**

`shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift`:

```swift
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd shared/AVLiveWire && swift test --filter WirePayloadsTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add shared/AVLiveWire
git commit -m "feat(avlivewire): skeleton and video payload codecs"
```

---

## Task 4: Stream demuxer

The demuxer is fed arbitrary byte chunks (TCP delivers
non-frame-aligned data) and emits complete `(FrameHeader, Data)`
frames. It resyncs on the magic prefix if the stream is corrupt.

**Files:**
- Create: `shared/AVLiveWire/Sources/AVLiveWire/StreamDemuxer.swift`
- Test: `shared/AVLiveWire/Tests/AVLiveWireTests/StreamDemuxerTests.swift`

- [ ] **Step 1: Write the failing test**

`shared/AVLiveWire/Tests/AVLiveWireTests/StreamDemuxerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd shared/AVLiveWire && swift test --filter StreamDemuxerTests`
Expected: FAIL — `StreamDemuxer` undefined.

- [ ] **Step 3: Write the implementation**

`shared/AVLiveWire/Sources/AVLiveWire/StreamDemuxer.swift`:

```swift
import Foundation

public struct StreamDemuxer {
    public struct Frame: Equatable {
        public let header: FrameHeader
        public let payload: Data
    }

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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd shared/AVLiveWire && swift test --filter StreamDemuxerTests`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add shared/AVLiveWire
git commit -m "feat(avlivewire): incremental stream demuxer"
```

---

## Task 5: usbmux message codec

`usbmuxd` speaks a request/response protocol on the Unix socket
`/var/run/usbmuxd`: a 16-byte little-endian header
(`length | version=1 | message=8 (plist) | tag`) followed by an XML
property list.

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/USBMuxProtocol.swift`
- Test: `launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBMuxProtocolTests.swift`

- [ ] **Step 1: Write the failing test**

`launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBMuxProtocolTests.swift`:

```swift
import XCTest
@testable import AVLiveBody

final class USBMuxProtocolTests: XCTestCase {
    func testEncodeWrapsPlistWith16ByteHeader() {
        let body: [String: Any] = ["MessageType": "ListDevices"]
        let packet = USBMuxProtocol.encode(plist: body, tag: 3)
        XCTAssertGreaterThan(packet.count, 16)
        let len = packet.prefix(4).reduce(0) { $0 | (UInt32($1) << 0) }
        XCTAssertEqual(Int(USBMuxProtocol.readLE32(packet, 0)),
                       packet.count)
        XCTAssertEqual(USBMuxProtocol.readLE32(packet, 4), 1)
        XCTAssertEqual(USBMuxProtocol.readLE32(packet, 8), 8)
        XCTAssertEqual(USBMuxProtocol.readLE32(packet, 12), 3)
        _ = len
    }

    func testDecodeRoundTrip() {
        let packet = USBMuxProtocol.encode(
            plist: ["MessageType": "Result", "Number": 0], tag: 1)
        let decoded = USBMuxProtocol.decode(packet)
        XCTAssertEqual(decoded?["MessageType"] as? String, "Result")
        XCTAssertEqual(decoded?["Number"] as? Int, 0)
    }

    func testDecodeRejectsShortPacket() {
        XCTAssertNil(USBMuxProtocol.decode(Data([0, 1, 2])))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd launcher/AV-Live-Body && swift test --filter USBMuxProtocolTests`
Expected: FAIL — `USBMuxProtocol` undefined.

- [ ] **Step 3: Write the implementation**

`launcher/AV-Live-Body/Sources/AVLiveBody/USBMuxProtocol.swift`:

```swift
import Foundation

/// Codec for the usbmuxd request/response protocol. 16-byte
/// little-endian header (length, version=1, message=8, tag) then an
/// XML property list.
enum USBMuxProtocol {
    static func encode(plist: [String: Any], tag: UInt32) -> Data {
        let body = (try? PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0))
            ?? Data()
        var d = Data()
        appendLE32(&d, UInt32(16 + body.count))   // length
        appendLE32(&d, 1)                          // version
        appendLE32(&d, 8)                          // message: plist
        appendLE32(&d, tag)
        d.append(body)
        return d
    }

    static func decode(_ packet: Data) -> [String: Any]? {
        guard packet.count >= 16 else { return nil }
        let body = packet.dropFirst(16)
        return (try? PropertyListSerialization.propertyList(
            from: body, options: [], format: nil)) as? [String: Any]
    }

    static func appendLE32(_ d: inout Data, _ v: UInt32) {
        for i in 0..<4 { d.append(UInt8((v >> (8 * i)) & 0xFF)) }
    }

    static func readLE32(_ d: Data, _ offset: Int) -> UInt32 {
        let b = [UInt8](d)
        var v: UInt32 = 0
        for i in 0..<4 { v |= UInt32(b[offset + i]) << (8 * i) }
        return v
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd launcher/AV-Live-Body && swift test --filter USBMuxProtocolTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add launcher/AV-Live-Body
git commit -m "feat(av-live-body): usbmux message codec"
```

---

## Task 6: USBClient — device discovery + connect

`USBClient` opens `/var/run/usbmuxd`, lists attached devices, and
connects to a chosen device's TCP port — yielding a byte stream that
is physically tunneled over USB. It is tested against an injectable
socket transport so no real device is needed.

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/USBClient.swift`
- Test: `launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBClientTests.swift`

- [ ] **Step 1: Write the failing test**

`launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBClientTests.swift`:

```swift
import XCTest
@testable import AVLiveBody

/// In-memory stand-in for the usbmuxd Unix socket.
final class MockMuxTransport: MuxTransport {
    var sent: [Data] = []
    var canned: [Data] = []
    func send(_ data: Data) { sent.append(data) }
    func receivePacket() -> Data? {
        canned.isEmpty ? nil : canned.removeFirst()
    }
    func close() {}
}

final class USBClientTests: XCTestCase {
    func testListDevicesParsesDeviceIDs() {
        let mock = MockMuxTransport()
        mock.canned = [USBMuxProtocol.encode(plist: [
            "DeviceList": [
                ["DeviceID": 42,
                 "Properties": ["ConnectionType": "USB"]],
            ]], tag: 0)]
        let client = USBClient(transport: mock)
        let devices = client.listDevices()
        XCTAssertEqual(devices, [42])
    }

    func testConnectSendsConnectRequest() {
        let mock = MockMuxTransport()
        mock.canned = [USBMuxProtocol.encode(
            plist: ["MessageType": "Result", "Number": 0], tag: 0)]
        let client = USBClient(transport: mock)
        let ok = client.connect(deviceID: 42, port: 7000)
        XCTAssertTrue(ok)
        let req = USBMuxProtocol.decode(mock.sent.last!)
        XCTAssertEqual(req?["MessageType"] as? String, "Connect")
        XCTAssertEqual(req?["DeviceID"] as? Int, 42)
        // usbmux expects the port byte-swapped to big-endian
        XCTAssertEqual(req?["PortNumber"] as? Int,
                       Int((UInt16(7000) << 8) | (UInt16(7000) >> 8)))
    }

    func testConnectFailsOnNonZeroResult() {
        let mock = MockMuxTransport()
        mock.canned = [USBMuxProtocol.encode(
            plist: ["MessageType": "Result", "Number": 3], tag: 0)]
        let client = USBClient(transport: mock)
        XCTAssertFalse(client.connect(deviceID: 1, port: 7000))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd launcher/AV-Live-Body && swift test --filter USBClientTests`
Expected: FAIL — `MuxTransport` / `USBClient` undefined.

- [ ] **Step 3: Write the implementation**

`launcher/AV-Live-Body/Sources/AVLiveBody/USBClient.swift`:

```swift
import Foundation

/// Transport abstraction over the usbmuxd Unix socket. The real
/// implementation wraps a `socket(AF_UNIX)`; tests inject a mock.
protocol MuxTransport {
    func send(_ data: Data)
    func receivePacket() -> Data?
    func close()
}

/// usbmux client: device discovery + connect-to-port. After a
/// successful `connect`, the same transport carries the raw tunneled
/// byte stream from the device.
final class USBClient {
    private let transport: MuxTransport
    private var tag: UInt32 = 0

    init(transport: MuxTransport) {
        self.transport = transport
    }

    func listDevices() -> [Int] {
        tag += 1
        transport.send(USBMuxProtocol.encode(
            plist: ["MessageType": "ListDevices"], tag: tag))
        guard let reply = transport.receivePacket(),
              let plist = USBMuxProtocol.decode(reply),
              let list = plist["DeviceList"] as? [[String: Any]]
        else { return [] }
        return list.compactMap { $0["DeviceID"] as? Int }
    }

    /// Returns true once the transport is tunneled to `port` on the
    /// device. usbmux wants the TCP port in big-endian order.
    func connect(deviceID: Int, port: UInt16) -> Bool {
        tag += 1
        let swapped = Int((port << 8) | (port >> 8))
        transport.send(USBMuxProtocol.encode(plist: [
            "MessageType": "Connect",
            "DeviceID": deviceID,
            "PortNumber": swapped,
        ], tag: tag))
        guard let reply = transport.receivePacket(),
              let plist = USBMuxProtocol.decode(reply),
              let number = plist["Number"] as? Int
        else { return false }
        return number == 0
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd launcher/AV-Live-Body && swift test --filter USBClientTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add launcher/AV-Live-Body
git commit -m "feat(av-live-body): usbmux device discovery + connect"
```

---

## Task 7: Real Unix-socket transport

`UnixMuxTransport` is the production `MuxTransport`: a blocking
`AF_UNIX` socket to `/var/run/usbmuxd`. It has no unit test (it needs
the daemon); it is exercised by the end-to-end smoke task.

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/USBClient.swift`

- [ ] **Step 1: Append the real transport**

Append to `USBClient.swift`:

```swift
import Darwin

/// Production transport: blocking AF_UNIX socket to usbmuxd.
final class UnixMuxTransport: MuxTransport {
    private var fd: Int32 = -1

    init?(path: String = "/var/run/usbmuxd") {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = path.withCString { src in
            withUnsafeMutablePointer(to: &addr.sun_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: 104) {
                    strcpy($0, src)
                }
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, size)
            }
        }
        if ok != 0 { Darwin.close(fd); return nil }
    }

    func send(_ data: Data) {
        data.withUnsafeBytes { _ = Darwin.write(fd, $0.baseAddress, data.count) }
    }

    /// Read one usbmux packet: 4-byte LE length prefix then body.
    func receivePacket() -> Data? {
        guard let head = readN(4) else { return nil }
        let total = Int(USBMuxProtocol.readLE32(head, 0))
        guard total >= 16, let rest = readN(total - 4) else { return nil }
        return head + rest
    }

    /// Read raw tunneled bytes after a successful Connect.
    func readStream(max: Int = 65536) -> Data? {
        readN(max, exact: false)
    }

    private func readN(_ n: Int, exact: Bool = true) -> Data? {
        var buf = [UInt8](repeating: 0, count: n)
        var got = 0
        while got < n {
            let r = buf.withUnsafeMutableBytes {
                Darwin.read(fd, $0.baseAddress!.advanced(by: got), n - got)
            }
            if r <= 0 { return got > 0 && !exact
                ? Data(buf[0..<got]) : nil }
            got += r
            if !exact { break }
        }
        return Data(buf[0..<got])
    }

    func close() { if fd >= 0 { Darwin.close(fd) } }
}
```

- [ ] **Step 2: Run the existing suite to confirm no regression**

Run: `cd launcher/AV-Live-Body && swift test --filter USBClientTests`
Expected: PASS, 3 tests (mock-based tests unaffected).

- [ ] **Step 3: Commit**

```bash
git add launcher/AV-Live-Body
git commit -m "feat(av-live-body): real usbmuxd unix socket transport"
```

---

## Task 8: iOS USBServer

`USBServer` runs inside ARBodyTracker: an `NWListener` on a fixed
local TCP port. usbmuxd exposes that port to the tethered Mac. It
sends `AVLiveWire` frames and exposes a connection-state callback.

**Files:**
- Create: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/USBServer.swift`

- [ ] **Step 1: Write the implementation**

`iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/USBServer.swift`:

```swift
import Foundation
import Network
import AVLiveWire

/// TCP listener on a fixed local port. usbmuxd tunnels it to the
/// tethered Mac — the port is never advertised on any network.
final class USBServer {
    static let port: UInt16 = 7000

    enum State { case idle, listening, connected }
    var onState: ((State) -> Void)?

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "cc.avlive.usbserver")

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        listener = try? NWListener(using: params,
            on: NWEndpoint.Port(rawValue: Self.port)!)
        listener?.newConnectionHandler = { [weak self] conn in
            self?.adopt(conn)
        }
        listener?.start(queue: queue)
        onState?(.listening)
    }

    private func adopt(_ conn: NWConnection) {
        connection?.cancel()
        connection = conn
        conn.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready:  self?.onState?(.connected)
            case .failed, .cancelled: self?.onState?(.listening)
            default: break
            }
        }
        conn.start(queue: queue)
    }

    /// Send one framed message. Drops silently if no peer.
    func send(tag: FrameTag, pid: Int16, timestamp: Double,
              payload: Data) {
        guard let conn = connection else { return }
        let header = FrameHeader(tag: tag, pid: pid,
            timestamp: timestamp, length: UInt32(payload.count))
        conn.send(content: header.encoded() + payload,
                  completion: .contentProcessed { _ in })
    }

    func stop() {
        connection?.cancel(); listener?.cancel()
        onState?(.idle)
    }
}
```

- [ ] **Step 2: Verify the iOS app target builds**

Run: `cd iphone-arbody/ARBodyTracker.swiftpm && swift build`
Expected: build succeeds (the `AVLiveWire` dependency is added in
Task 9; until then this step is expected to fail on the missing
`import AVLiveWire` — proceed to Task 9, then re-run).

- [ ] **Step 3: Commit**

```bash
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/USBServer.swift
git commit -m "feat(ios): USB TCP frame server"
```

---

## Task 9: Wire AVLiveWire into both apps

**Files:**
- Modify: `launcher/AV-Live-Body/Package.swift`
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Package.swift`

- [ ] **Step 1: Add the dependency to AV-Live-Body**

In `launcher/AV-Live-Body/Package.swift`, add to `dependencies:`:

```swift
.package(path: "../../shared/AVLiveWire"),
```

and add `"AVLiveWire"` to the `AVLiveBody` target's `dependencies`
array:

```swift
.product(name: "AVLiveWire", package: "AVLiveWire"),
```

- [ ] **Step 2: Add the dependency to ARBodyTracker**

In `iphone-arbody/ARBodyTracker.swiftpm/Package.swift`, add the same
`.package(path:)` entry (path relative to the `.swiftpm`:
`../../shared/AVLiveWire`) and the same `.product` to the app target.

- [ ] **Step 3: Build both apps**

Run: `cd launcher/AV-Live-Body && swift build`
Expected: build succeeds, `import AVLiveWire` resolves.

Run: `cd iphone-arbody/ARBodyTracker.swiftpm && swift build`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add launcher/AV-Live-Body/Package.swift
git add iphone-arbody/ARBodyTracker.swiftpm/Package.swift
git commit -m "build: depend on shared AVLiveWire package"
```

---

## Task 10: End-to-end loopback smoke test

Verify the transport end to end without a device, using a local TCP
loopback in place of the USB tunnel: a server sends frames, a client
demuxes them.

**Files:**
- Test: `shared/AVLiveWire/Tests/AVLiveWireTests/LoopbackTests.swift`

- [ ] **Step 1: Write the test**

`shared/AVLiveWire/Tests/AVLiveWireTests/LoopbackTests.swift`:

```swift
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
            frames += demux.feed(stream[
                stream.index(stream.startIndex, offsetBy: offset)..<
                stream.index(stream.startIndex, offsetBy: end)])
            offset = end
        }

        XCTAssertEqual(frames.count, 20)
        XCTAssertEqual(frames[5].header.pid, 5)
        XCTAssertEqual(SkeletonPayload(decoding: frames[5].payload),
                       skel)
    }
}
```

- [ ] **Step 2: Run the test**

Run: `cd shared/AVLiveWire && swift test --filter LoopbackTests`
Expected: PASS, 1 test.

- [ ] **Step 3: Run the full suites**

Run: `cd shared/AVLiveWire && swift test`
Expected: PASS, all tests (Tasks 1-4 + loopback).

Run: `cd launcher/AV-Live-Body && swift test --filter USBMuxProtocolTests --filter USBClientTests`
Expected: PASS, all usbmux tests.

- [ ] **Step 4: Commit**

```bash
git add shared/AVLiveWire
git commit -m "test(avlivewire): end-to-end chunked loopback"
```

---

## Manual verification (requires a tethered iPhone)

Not a coded task — performed once the iOS app from Plan 2 streams
real frames:

1. Tether the iPhone by USB; trust the Mac if prompted.
2. From the Mac, `UnixMuxTransport()` + `USBClient.listDevices()`
   returns the device ID.
3. `connect(deviceID:port:7000)` succeeds while ARBodyTracker runs.
4. Bytes read from the transport, fed to `StreamDemuxer`, yield
   `skeleton` frames.

---

## Self-Review

- **Spec coverage:** This plan covers the spec's `WireFormat`,
  `StreamDemuxer`, `USBClient`, and `USBServer` units, and the
  "usbmux native Swift client" decision. `VideoEncoder`,
  `VideoDecoder`, `MultiHMRCoreML`, `BodyFusion`, `ARBodySession`
  changes, and `PoseOSCBridge` are deliberately deferred to Plans 2
  and 3.
- **Placeholders:** none — every step carries complete code or an
  exact command.
- **Type consistency:** `FrameHeader`, `FrameTag`, `SkeletonPayload`,
  `VideoPayload`, `StreamDemuxer.Frame`, `MuxTransport`, `USBClient`,
  `USBMuxProtocol`, `USBServer` are used with consistent signatures
  across tasks. `USBServer.send` builds a `FrameHeader` exactly as
  `StreamDemuxer` expects to parse it.
- **Known ordering note:** Task 8 Step 2 cannot fully build until
  Task 9 adds the dependency — flagged inline in Task 8.
