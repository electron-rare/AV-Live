import AVLiveWire
import Combine
import Foundation

/// Connects to the tethered iPhone over USB (usbmuxd), demuxes the
/// AVLiveWire stream, and republishes skeleton frames (as the existing
/// 91-joint `ArkitOSCListener.ArkitBodyFrame`) plus video payloads.
/// The blocking transport runs on a dedicated background thread; only
/// `@Published` writes hop to the main queue.
final class USBSkeletonConsumer: ObservableObject {
    /// 91-joint body frames keyed by pid — same shape
    /// `Skeleton3DRenderer` already consumes from `ArkitOSCListener`.
    @Published var bodies: [Int: ArkitOSCListener.ArkitBodyFrame] = [:]
    @Published var connected = false

    /// Called (on the main queue) for every decoded `.video` frame.
    var onVideo: ((VideoPayload) -> Void)?

    /// TCP port the iPhone `USBServer` listens on (must match the iOS
    /// app's `USBServer.port`).
    static let devicePort: UInt16 = 7000

    private let stateLock = NSLock()
    private var running = false
    private var thread: Thread?

    private var isRunning: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return running
    }

    func start() {
        stateLock.lock()
        if running { stateLock.unlock(); return }
        running = true
        stateLock.unlock()
        let t = Thread { [weak self] in self?.loop() }
        t.name = "cc.avlive.usbconsumer"
        t.start()
        thread = t
    }

    func stop() {
        stateLock.lock(); running = false; stateLock.unlock()
    }

    /// Pure mapping `SkeletonPayload` -> `ArkitBodyFrame`. Static so it
    /// is unit-testable without a transport.
    static func bodyFrame(pid: Int, from p: SkeletonPayload)
        -> ArkitOSCListener.ArkitBodyFrame {
        var f = ArkitOSCListener.ArkitBodyFrame()
        f.pid = pid
        f.joints = p.joints
        f.hasJoint = p.valid
        f.seenAt = CFAbsoluteTimeGetCurrent()
        return f
    }

    // MARK: - Background read loop

    private func loop() {
        while isRunning {
            guard let transport = UnixMuxTransport() else {
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            let client = USBClient(transport: transport)
            guard let dev = client.listDevices().first,
                  client.connect(deviceID: dev,
                                 port: Self.devicePort) else {
                transport.close()
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            publishConnected(true)
            var demux = StreamDemuxer()
            while isRunning {
                guard let chunk = transport.readStream(),
                      !chunk.isEmpty else { break }
                for frame in demux.feed(chunk) { route(frame) }
            }
            transport.close()
            publishConnected(false)
            if isRunning { Thread.sleep(forTimeInterval: 1.0) }
        }
    }

    private func route(_ frame: StreamDemuxer.Frame) {
        switch frame.header.tag {
        case .skeleton:
            guard let payload =
                SkeletonPayload(decoding: frame.payload) else { return }
            let pid = Int(frame.header.pid)
            let body = Self.bodyFrame(pid: pid, from: payload)
            DispatchQueue.main.async { [weak self] in
                self?.bodies[pid] = body
            }
        case .video:
            guard let payload =
                VideoPayload(decoding: frame.payload) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onVideo?(payload)
            }
        case .meta:
            break
        }
    }

    private func publishConnected(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.connected = value
        }
    }
}
