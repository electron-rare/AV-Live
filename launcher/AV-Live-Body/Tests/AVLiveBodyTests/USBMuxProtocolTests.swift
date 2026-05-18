import XCTest
@testable import AVLiveBody

final class USBMuxProtocolTests: XCTestCase {
    func testEncodeWrapsPlistWith16ByteHeader() {
        let body: [String: Any] = ["MessageType": "ListDevices"]
        let packet = USBMuxProtocol.encode(plist: body, tag: 3)
        XCTAssertGreaterThan(packet.count, 16)
        XCTAssertEqual(Int(USBMuxProtocol.readLE32(packet, 0)),
                       packet.count)
        XCTAssertEqual(USBMuxProtocol.readLE32(packet, 4), 1)
        XCTAssertEqual(USBMuxProtocol.readLE32(packet, 8), 8)
        XCTAssertEqual(USBMuxProtocol.readLE32(packet, 12), 3)
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
