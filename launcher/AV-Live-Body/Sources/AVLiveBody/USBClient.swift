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
