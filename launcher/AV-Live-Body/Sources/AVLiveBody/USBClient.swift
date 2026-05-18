import Foundation
import Darwin

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

/// Production transport: blocking AF_UNIX socket to usbmuxd.
final class UnixMuxTransport: MuxTransport {
    private var fd: Int32 = -1

    init?(path: String = "/var/run/usbmuxd") {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        precondition(path.utf8.count < 104,
                     "usbmuxd socket path exceeds sun_path limit")
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
        guard fd >= 0 else { return }
        data.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            var off = 0
            while off < data.count {
                let w = Darwin.write(fd, base.advanced(by: off),
                                     data.count - off)
                if w <= 0 {
                    if w < 0 && errno == EINTR { continue }
                    break
                }
                off += w
            }
        }
    }

    /// Read one usbmux packet: 4-byte LE length prefix then body.
    func receivePacket() -> Data? {
        guard let head = readN(4) else { return nil }
        guard let len = USBMuxProtocol.readLE32(head, 0) else { return nil }
        let total = Int(len)
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
            if r < 0 {
                if errno == EINTR { continue }
                return got > 0 && !exact ? Data(buf[0..<got]) : nil
            }
            if r == 0 {   // EOF — peer closed
                return got > 0 && !exact ? Data(buf[0..<got]) : nil
            }
            got += r
            if !exact { break }
        }
        return Data(buf[0..<got])
    }

    deinit { close() }

    func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
    }
}
