import Foundation
import Network

/// Listener TCP qui decode le protocole binaire de smplx_osc_sender.py.
/// Frame : [u32 length][SMPX magic][i32 n_persons]
///         [(pid i32 + conf f32 + 3 transl + 10 betas + 10 expr
///           + 10475*3 verts)] × N
final class OSCServer {
    private static let maxBufferBytes = 8 * 1024 * 1024  // 8 MiB — well above per-frame size
    private let port: NWEndpoint.Port
    private let onPersons: ([SMPLXPersonData]) -> Void
    private var listener: NWListener?
    private var conn: NWConnection?
    private var buffer = Data()

    init(port: UInt16, onPersons: @escaping ([SMPLXPersonData]) -> Void) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.onPersons = onPersons
    }

    func start() {
        let params = NWParameters.tcp
        params.acceptLocalOnly = true
        do {
            let l = try NWListener(using: params, on: port)
            l.newConnectionHandler = { [weak self] conn in
                self?.conn = conn
                conn.start(queue: .global(qos: .userInitiated))
                self?.receive(on: conn)
            }
            l.start(queue: .global())
            self.listener = l
            print("OSC TCP listening on :\(port)")
        } catch {
            print("OSCServer.start error: \(error)")
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 64) {
            [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let d = data { self.buffer.append(d) }
            if self.buffer.count > Self.maxBufferBytes {
                NSLog("OSCServer: buffer exceeded %d bytes (%d), dropping connection", Self.maxBufferBytes, self.buffer.count)
                self.buffer.removeAll(keepingCapacity: false)
                conn.cancel()
                return
            }
            self.parseFrames()
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            self.receive(on: conn)
        }
    }

    private func parseFrames() {
        while true {
            guard buffer.count >= 4 else { return }
            let len = buffer.withUnsafeBytes {
                $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian
            }
            guard len > 0, len <= Self.maxBufferBytes else {
                NSLog("OSCServer: invalid frame length %u, resetting", len)
                self.buffer.removeAll(keepingCapacity: false)
                return
            }
            guard buffer.count >= 4 + Int(len) else { return }
            let payload = buffer.subdata(in: 4..<(4 + Int(len)))
            buffer.removeSubrange(0..<(4 + Int(len)))
            decode(payload: payload)
        }
    }

    private func decode(payload: Data) {
        guard payload.count > 8 else { return }
        let magic = payload.subdata(in: 0..<4)
        guard magic == "SMPX".data(using: .ascii) else { return }
        var offset = 4
        let nPersons: Int32 = payload.withUnsafeBytes {
            $0.load(fromByteOffset: offset, as: Int32.self).littleEndian
        }
        offset += 4
        var persons: [SMPLXPersonData] = []
        for _ in 0..<Int(nPersons) {
            let pid: Int32 = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Int32.self).littleEndian
            }
            offset += 4
            let conf: Float = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self)
            }
            offset += 4
            let tx: Float = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self)
            }
            offset += 4
            let ty: Float = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self)
            }
            offset += 4
            let tz: Float = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self)
            }
            offset += 4
            // betas (10*4) + expression (10*4) — skip
            offset += 80
            var verts: [SIMD3<Float>] = []
            verts.reserveCapacity(10475)
            for _ in 0..<10475 {
                let x: Float = payload.withUnsafeBytes {
                    $0.load(fromByteOffset: offset, as: Float.self)
                }
                offset += 4
                let y: Float = payload.withUnsafeBytes {
                    $0.load(fromByteOffset: offset, as: Float.self)
                }
                offset += 4
                let z: Float = payload.withUnsafeBytes {
                    $0.load(fromByteOffset: offset, as: Float.self)
                }
                offset += 4
                verts.append(SIMD3<Float>(x, y, z))
            }
            persons.append(SMPLXPersonData(
                pid: Int(pid), confidence: conf,
                translation: SIMD3(tx, ty, tz),
                vertices: verts
            ))
        }
        onPersons(persons)
    }
}
