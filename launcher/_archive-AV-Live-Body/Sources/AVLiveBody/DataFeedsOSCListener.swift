import Foundation
import Network

/// UDP :57127 listener that consumes /data/<feed>/* messages from
/// the Python data_feeds package and exposes the latest per-feed
/// payloads to the SwiftUI HUD via @Published.
@MainActor
final class DataFeedsOSCListener: ObservableObject {
    struct TransientEvent: Equatable, Identifiable {
        let id = UUID()
        let feed: String
        let key: String
        let value: Double
        let seenAt: TimeInterval
    }

    @Published var samples: [String: [String: Double]] = [:]
    @Published var counts: [String: Int] = [:]
    @Published var heartbeats: [String: TimeInterval] = [:]
    @Published var recentEvents: [TransientEvent] = []

    private var listener: NWListener?
    static let defaultPort: UInt16 = 57127
    private static let maxEvents: Int = 32

    func start(port: UInt16 = DataFeedsOSCListener.defaultPort) {
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params,
                                   on: NWEndpoint.Port(rawValue: port)!)
            l.newConnectionHandler = { [weak self] conn in
                conn.start(queue: .global(qos: .userInitiated))
                self?.receive(on: conn)
            }
            l.start(queue: .global())
            self.listener = l
            NSLog("DataFeedsOSCListener UDP :%d", port)
        } catch {
            NSLog("DataFeedsOSCListener bind :%d failed: %@",
                  Int(port), String(describing: error))
        }
    }

    private nonisolated func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let d = data, !d.isEmpty {
                self?.handle(packet: d)
            }
            if error == nil { self?.receive(on: conn) }
        }
    }

    private nonisolated func handle(packet: Data) {
        guard let (address, types, payload) = parseOSCHeader(packet) else {
            return
        }
        let args = parseOSCArgs(types: types, data: payload)
        Task { @MainActor [weak self] in
            self?.apply(address: address, args: args)
        }
    }

    private func apply(address: String, args: [Any]) {
        // address shape : /data/<feed>/<route>
        let trimmed = address.hasPrefix("/")
            ? String(address.dropFirst()) : address
        let comps = trimmed.split(separator: "/")
        guard comps.count >= 3, comps[0] == "data" else { return }
        let feed = String(comps[1])
        let route = String(comps[2])
        switch route {
        case "count":
            if let n = args.first as? Int32 {
                counts[feed] = Int(n)
            }
        case "heartbeat":
            if let t = args.first as? Float {
                heartbeats[feed] = TimeInterval(t)
            } else if let t = args.first as? Double {
                heartbeats[feed] = t
            }
        case "sample":
            guard args.count >= 2 else { return }
            let key: String
            switch args[0] {
            case let s as String: key = s
            case let i as Int32: key = String(i)
            default: return
            }
            let value: Double
            switch args[1] {
            case let f as Float: value = Double(f)
            case let d as Double: value = d
            case let i as Int32: value = Double(i)
            default: return
            }
            var d = samples[feed] ?? [:]
            d[key] = value
            samples[feed] = d
            let ev = TransientEvent(feed: feed, key: key, value: value,
                                    seenAt: CFAbsoluteTimeGetCurrent())
            recentEvents.append(ev)
            if recentEvents.count > Self.maxEvents {
                recentEvents.removeFirst(recentEvents.count - Self.maxEvents)
            }
        default:
            break
        }
    }

    // MARK: - Minimal OSC parser (mirror of ArkitOSCListener helpers)

    private nonisolated func align4(_ n: Int) -> Int { (n + 3) & ~3 }

    private nonisolated func parseOSCHeader(_ data: Data
                                            ) -> (String, String, Data)? {
        guard let endAddr = data.firstIndex(of: 0) else { return nil }
        let address = String(data: data[..<endAddr], encoding: .ascii) ?? ""
        let addrEnd = align4(endAddr - data.startIndex + 1)
        guard addrEnd < data.count else { return nil }
        let rest = data[(data.startIndex + addrEnd)...]
        guard let comma = rest.first, comma == UInt8(ascii: ","),
              let endTypes = rest.firstIndex(of: 0) else { return nil }
        let typesData = rest[rest.startIndex.advanced(by: 1)..<endTypes]
        let types = String(data: typesData, encoding: .ascii) ?? ""
        let typesEnd = align4(endTypes - rest.startIndex + 1)
        guard typesEnd <= rest.count else { return nil }
        let payload = rest[rest.startIndex.advanced(by: typesEnd)...]
        return (address, types, Data(payload))
    }

    private nonisolated func parseOSCArgs(types: String, data: Data) -> [Any] {
        var args: [Any] = []
        var offset = 0
        for t in types {
            switch t {
            case "i":
                guard offset + 4 <= data.count else { return args }
                let v = data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: Int32.self)
                }.bigEndian
                args.append(v)
                offset += 4
            case "f":
                guard offset + 4 <= data.count else { return args }
                let raw = data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                }.bigEndian
                args.append(Float(bitPattern: raw))
                offset += 4
            case "d":
                guard offset + 8 <= data.count else { return args }
                let raw = data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
                }.bigEndian
                args.append(Double(bitPattern: raw))
                offset += 8
            case "s":
                let start = offset
                while offset < data.count
                    && data[data.startIndex.advanced(by: offset)] != 0 {
                    offset += 1
                }
                let lo = data.startIndex.advanced(by: start)
                let hi = data.startIndex.advanced(by: offset)
                let slice = data[lo..<hi]
                let s = String(data: slice, encoding: .ascii) ?? ""
                args.append(s)
                offset = align4(offset + 1)
            default:
                return args
            }
        }
        return args
    }
}
