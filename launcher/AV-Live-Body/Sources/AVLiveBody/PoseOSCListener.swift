import Foundation
import Network
import simd

/// Listener UDP sur :57126 qui parse les messages OSC envoyes par
/// data_only_viz/pose_bridge.py et publie l'etat des personnes
/// detectees pour le rendu skeleton dans BodyView. La classe n'est
/// pas @MainActor pour pouvoir etre callbackee par Network.framework
/// depuis sa queue globale ; on hop sur MainActor pour les Published.
final class PoseOSCListener: ObservableObject {
    /// Position (x, y normalises 0..1) + confidence par personne.
    /// On garde uniquement les routes interessantes pour overlay 3D :
    /// /pose/center, /pose/wrist, /pose/head, /pose/sho_span,
    /// /pose/torso_yaw, /pose/body_pitch.
    struct PoseFrame: Equatable {
        var center: SIMD2<Float> = .zero
        var head: SIMD2<Float> = .zero
        var wristL: SIMD2<Float> = .zero
        var wristR: SIMD2<Float> = .zero
        var shoSpan: Float = 0
        var torsoYaw: Float = 0
        var bodyPitch: Float = 0
        var seenAt: TimeInterval = 0
    }

    @Published var persons: [Int: PoseFrame] = [:]
    @Published var count: Int = 0

    private var listener: NWListener?

    private func updatePublished(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    func start(port: UInt16 = 57126) {
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
            NSLog("PoseOSCListener: udp :%d up", port)
        } catch {
            NSLog("PoseOSCListener: bind :%d failed : %@",
                  Int(port), String(describing: error))
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let data = data, !data.isEmpty {
                self?.handle(packet: data)
            }
            if error == nil {
                self?.receive(on: conn)
            }
        }
    }

    private func handle(packet: Data) {
        guard let (address, types, payload) = parseOSCHeader(packet) else {
            return
        }
        let args = parseOSCArgs(types: types, data: payload)
        updatePublished { [weak self] in
            self?.apply(address: address, args: args)
        }
    }

    private func apply(address: String, args: [Any]) {
        switch address {
        case "/pose/count":
            if let n = args.first as? Int32 { count = Int(n) }
        case "/pose/center":
            guard args.count >= 3,
                  let pid = args[0] as? Int32,
                  let cx = args[1] as? Float,
                  let cy = args[2] as? Float else { return }
            var p = persons[Int(pid)] ?? PoseFrame()
            p.center = SIMD2(cx, cy)
            p.seenAt = CFAbsoluteTimeGetCurrent()
            persons[Int(pid)] = p
        case "/pose/head":
            guard args.count >= 4,
                  let pid = args[0] as? Int32,
                  let x = args[1] as? Float,
                  let y = args[2] as? Float else { return }
            var p = persons[Int(pid)] ?? PoseFrame()
            p.head = SIMD2(x, y)
            persons[Int(pid)] = p
        case "/pose/wrist":
            guard args.count >= 4,
                  let pid = args[0] as? Int32,
                  let side = args[1] as? String,
                  let x = args[2] as? Float,
                  let y = args[3] as? Float else { return }
            var p = persons[Int(pid)] ?? PoseFrame()
            if side == "l" {
                p.wristL = SIMD2(x, y)
            } else {
                p.wristR = SIMD2(x, y)
            }
            persons[Int(pid)] = p
        case "/pose/sho_span":
            guard args.count >= 2,
                  let pid = args[0] as? Int32,
                  let dx = args[1] as? Float else { return }
            var p = persons[Int(pid)] ?? PoseFrame()
            p.shoSpan = dx
            persons[Int(pid)] = p
        case "/pose/torso_yaw":
            guard args.count >= 2,
                  let pid = args[0] as? Int32,
                  let v = args[1] as? Float else { return }
            var p = persons[Int(pid)] ?? PoseFrame()
            p.torsoYaw = v
            persons[Int(pid)] = p
        case "/pose/body_pitch":
            guard args.count >= 2,
                  let pid = args[0] as? Int32,
                  let v = args[1] as? Float else { return }
            var p = persons[Int(pid)] ?? PoseFrame()
            p.bodyPitch = v
            persons[Int(pid)] = p
        default:
            break
        }
        // Garbage-collect persons non vues depuis > 2 s
        let now = CFAbsoluteTimeGetCurrent()
        persons = persons.filter { $0.value.seenAt == 0
                                   || now - $0.value.seenAt < 2.0 }
    }

    // MARK: - Minimal OSC parser

    private func align4(_ n: Int) -> Int { (n + 3) & ~3 }

    private func parseOSCHeader(_ data: Data
                               ) -> (String, String, Data)? {
        // Address jusqu'au \0
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
