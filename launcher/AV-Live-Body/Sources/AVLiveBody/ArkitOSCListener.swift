import Foundation
import Network
import simd

/// Listener UDP secondaire qui consomme /body3d/kp envoyes par l'app
/// iOS ARBodyTracker. Permet une visualisation diagnostique des joints
/// ARKit (91 joints, LiDAR-anchored) en parallele du flux MediaPipe
/// fusionne cote Python. Port distinct de PoseOSCListener (:57126)
/// pour eviter le clash de bind UDP : l'iPhone doit pousser vers les
/// deux ports si on veut Python ET Swift ; ou utiliser un fanout
/// (proxy UDP one-to-many) si une seule destination est practique.
final class ArkitOSCListener: ObservableObject {
    struct ArkitBodyFrame: Equatable {
        var pid: Int = -1
        /// 91 ARKit joints world-space (x, y, z meters).
        var joints: [SIMD3<Float>] = Array(repeating: .zero, count: 91)
        /// Per-joint "has been written" flag.
        var hasJoint: [Bool] = Array(repeating: false, count: 91)
        var seenAt: TimeInterval = 0
    }

    @Published var bodies: [Int: ArkitBodyFrame] = [:]
    @Published var count: Int = 0

    static let defaultPort: UInt16 = 57129   // distinct from :57128 (Python)
    private var listener: NWListener?

    func start(port: UInt16 = ArkitOSCListener.defaultPort) {
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
            NSLog("ArkitOSCListener: udp :%d up", port)
        } catch {
            NSLog("ArkitOSCListener: bind :%d failed: %@",
                  Int(port), String(describing: error))
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let d = data, !d.isEmpty {
                self?.handle(packet: d)
            }
            if error == nil { self?.receive(on: conn) }
        }
    }

    private func handle(packet: Data) {
        guard let (address, types, payload) = parseOSCHeader(packet) else {
            return
        }
        let args = parseOSCArgs(types: types, data: payload)
        DispatchQueue.main.async { [weak self] in
            self?.apply(address: address, args: args)
        }
    }

    private func apply(address: String, args: [Any]) {
        switch address {
        case "/body3d/count":
            if let n = args.first as? Int32 { count = Int(n) }
            if count == 0 { bodies.removeAll(keepingCapacity: true) }
        case "/body3d/kp":
            // pid (i32), joint_idx (i32), x (f32), y (f32), z (f32)
            guard args.count >= 5,
                  let pid = args[0] as? Int32,
                  let idx = args[1] as? Int32,
                  let x = args[2] as? Float,
                  let y = args[3] as? Float,
                  let z = args[4] as? Float else { return }
            let i = Int(idx)
            guard i >= 0 && i < 91 else { return }
            var b = bodies[Int(pid)] ?? ArkitBodyFrame()
            b.pid = Int(pid)
            b.joints[i] = SIMD3(x, y, z)
            b.hasJoint[i] = true
            b.seenAt = CFAbsoluteTimeGetCurrent()
            bodies[Int(pid)] = b
        default:
            break
        }
        // Garbage-collect bodies non vus depuis > 2 s
        let now = CFAbsoluteTimeGetCurrent()
        bodies = bodies.filter { now - $0.value.seenAt < 2.0 }
    }

    // MARK: - Minimal OSC parser (mirror of PoseOSCListener helpers)

    private func align4(_ n: Int) -> Int { (n + 3) & ~3 }

    private func parseOSCHeader(_ data: Data
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

    private func parseOSCArgs(types: String, data: Data) -> [Any] {
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
