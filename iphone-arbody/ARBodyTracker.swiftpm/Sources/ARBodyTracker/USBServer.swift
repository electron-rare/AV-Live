import Foundation
import Network
import AVLiveWire

/// TCP listener on a fixed local port. usbmuxd tunnels it to the
/// tethered Mac — the port is never advertised on any network.
final class USBServer {
    static let port: UInt16 = 7000

    enum State { case idle, listening, connected }
    var onState: ((State) -> Void)?

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "cc.avlive.usbserver")

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let l = try? NWListener(using: params,
            on: NWEndpoint.Port(rawValue: Self.port)!) else {
            onState?(.idle)
            return
        }
        listener = l
        l.newConnectionHandler = { [weak self] conn in
            self?.adopt(conn)
        }
        l.start(queue: queue)
        onState?(.listening)
    }

    private func adopt(_ conn: NWConnection) {
        connection?.cancel()
        connection = conn
        conn.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready:  self?.onState?(.connected)
            case .failed, .cancelled: self?.onState?(.listening)
            default: break
            }
        }
        conn.start(queue: queue)
    }

    /// Send one framed message. Drops silently if no peer.
    func send(tag: FrameTag, pid: Int16, timestamp: Double,
              payload: Data) {
        guard let conn = connection else { return }
        guard payload.count <= Int(StreamDemuxer.maxPayloadLength)
        else { return }
        let header = FrameHeader(tag: tag, pid: pid,
            timestamp: timestamp, length: UInt32(payload.count))
        conn.send(content: header.encoded() + payload,
                  completion: .contentProcessed { _ in })
    }

    func stop() {
        connection?.cancel(); listener?.cancel()
        onState?(.idle)
    }
}
