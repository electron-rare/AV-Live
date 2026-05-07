import Darwin
import Foundation

// Minimal OSC 1.0 client — only what AV-Live needs (UDP send, no
// reception, only string + int + float args). Avoids pulling in a
// dependency for ~80 LOC of bit twiddling.

final class OSCSender {
    private let host: String
    private let port: UInt16

    init(host: String = "127.0.0.1", port: UInt16 = 57121) {
        self.host = host
        self.port = port
    }

    func send(_ address: String, _ args: Any...) {
        let data = encode(address: address, args: args)
        sendUDP(data: data)
    }

    // MARK: - Encoding (OSC 1.0 — strings null-terminated and padded
    // to 4-byte boundaries, ints big-endian int32, floats big-endian
    // float32, type tag string starts with ',')

    private func encode(address: String, args: [Any]) -> Data {
        var out = Data()
        out.append(oscString(address))

        var tags = ","
        var argsData = Data()
        for a in args {
            if let s = a as? String {
                tags += "s"
                argsData.append(oscString(s))
            } else if let i = a as? Int {
                tags += "i"
                argsData.append(oscInt32(Int32(i)))
            } else if let f = a as? Float {
                tags += "f"
                argsData.append(oscFloat32(f))
            } else if let d = a as? Double {
                tags += "f"
                argsData.append(oscFloat32(Float(d)))
            }
        }
        out.append(oscString(tags))
        out.append(argsData)
        return out
    }

    private func oscString(_ s: String) -> Data {
        var d = s.data(using: .utf8) ?? Data()
        d.append(0)
        let pad = (4 - d.count % 4) % 4
        d.append(Data(count: pad))
        return d
    }

    private func oscInt32(_ v: Int32) -> Data {
        var be = v.bigEndian
        return Data(bytes: &be, count: 4)
    }

    private func oscFloat32(_ v: Float) -> Data {
        var be = v.bitPattern.bigEndian
        return Data(bytes: &be, count: 4)
    }

    // MARK: - Transport

    private func sendUDP(data: Data) {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let result = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
            let buf = raw.baseAddress!
            return withUnsafePointer(to: &addr) { saInPtr in
                saInPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    sendto(fd, buf, data.count, 0,
                           saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        _ = result
    }
}
