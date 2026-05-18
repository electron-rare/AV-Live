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
