import AVFoundation
import Cocoa

/// Capture la webcam macOS built-in (AVCaptureDeviceTypeBuiltInWideAngleCamera)
/// et expose une AVCaptureVideoPreviewLayer attachee a une NSView.
///
/// macOS autorise plusieurs processus a ouvrir la meme camera simultanement
/// (chaque process a sa propre AVCaptureSession), donc cohabiter avec le
/// worker Python Multi-HMR ne pose pas de probleme TCC.
final class CameraPreviewLayer {
    private let session = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer

    init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer.videoGravity = .resizeAspectFill
    }

    func start() -> Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified)
        guard let device = discovery.devices.first else {
            print("No built-in camera found")
            return false
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                print("session refused input")
                return false
            }
            session.addInput(input)
        } catch {
            print("AVCaptureDeviceInput error: \(error)")
            return false
        }
        session.sessionPreset = .high
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
        print("CameraPreviewLayer running on '\(device.localizedName)'")
        return true
    }

    func stop() {
        session.stopRunning()
    }
}
