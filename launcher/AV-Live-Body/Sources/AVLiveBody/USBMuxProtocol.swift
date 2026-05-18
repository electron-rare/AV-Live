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
