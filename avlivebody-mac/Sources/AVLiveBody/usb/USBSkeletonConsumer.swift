import AVLiveWire
import Combine
import CoreVideo
import Foundation

/// Connects to the tethered iPhone over USB (usbmuxd), demuxes the
/// AVLiveWire stream, republishes skeleton payloads (keyed by pid)
/// and forwards decoded camera frames. Blocking transport runs on a
/// dedicated background thread; only `@Published` writes hop to main.
final class USBSkeletonConsumer: ObservableObject {
    /// 91-joint skeleton payloads keyed by pid.
    @Published var skeletons: [Int: SkeletonPayload] = [:]
    @Published var connected = false

    /// Called on the main queue for every decoded camera frame.
    var onVideoFrame: ((CVPixelBuffer) -> Void)?

    /// TCP port the iPhone `USBServer` listens on.
    static let devicePort: UInt16 = 7000

    private let videoDecoder = VideoDecoder()
    private let stateLock = NSLock()
    private var running = false
    private var thread: Thread?

    init() {
        videoDecoder.onFrame = { [weak self] pixelBuffer in
            DispatchQueue.main.async {
                self?.onVideoFrame?(pixelBuffer)
            }
        }
    }

    private var isRunning: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return running
    }

    func start() {
        stateLock.lock()
        if running { stateLock.unlock(); return }
        running = true
        let t = Thread { [weak self] in self?.loop() }
        t.name = "cc.avlive.usbconsumer"
        thread = t
        stateLock.unlock()
        t.start()
    }

    func stop() {
        stateLock.lock(); running = false; stateLock.unlock()
    }

    private func loop() {
        while isRunning {
            guard let transport = UnixMuxTransport() else {
                NSLog("USBSkeletonConsumer: no usbmuxd; retry")
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            let client = USBClient(transport: transport)
            let devices = client.listDevices()
            guard let dev = devices.first,
                  client.connect(deviceID: dev,
                                 port: Self.devicePort) else {
                NSLog("USBSkeletonConsumer: no device; retry")
                transport.close()
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            NSLog("USBSkeletonConsumer: connected to device %d", dev)
            publishConnected(true)
            var demux = StreamDemuxer()
            while isRunning {
                guard let chunk = transport.readStream(),
                      !chunk.isEmpty else { break }
                for frame in demux.feed(chunk) { route(frame) }
            }
            transport.close()
            publishConnected(false)
            NSLog("USBSkeletonConsumer: disconnected")
            if isRunning { Thread.sleep(forTimeInterval: 1.0) }
        }
    }

    private func route(_ frame: StreamDemuxer.Frame) {
        switch frame.header.tag {
        case .skeleton:
            guard let payload =
                SkeletonPayload(decoding: frame.payload) else { return }
            let pid = Int(frame.header.pid)
            DispatchQueue.main.async { [weak self] in
                self?.skeletons[pid] = payload
            }
        case .video:
            guard let payload =
                VideoPayload(decoding: frame.payload) else { return }
            videoDecoder.decode(payload)
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
