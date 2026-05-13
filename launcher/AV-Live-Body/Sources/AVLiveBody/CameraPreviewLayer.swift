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
        // On enumere TOUS les types puis on filtre durement : nom ne
        // contient ni 'iPhone', ni 'GSM', ni 'Desk View', ni
        // 'Continuity' (cas Continuity Camera 13+) et deviceType ==
        // builtInWideAngleCamera. Ca evite tous les pieges.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera,
                          .continuityCamera,
                          .external,
                          .deskViewCamera],
            mediaType: .video,
            position: .unspecified)
        NSLog("AV-Live-Body: %d cameras detected", discovery.devices.count)
        for d in discovery.devices {
            NSLog("AV-Live-Body:  - %@  type=%@",
                  d.localizedName, d.deviceType.rawValue)
        }
        let banned = ["iPhone", "GSM", "Desk View", "Continuity"]
        let device = discovery.devices.first { d in
            guard d.deviceType == .builtInWideAngleCamera else { return false }
            let name = d.localizedName
            for b in banned where name.localizedCaseInsensitiveContains(b) {
                return false
            }
            return true
        }
        guard let device = device else {
            NSLog("AV-Live-Body: no Mac built-in camera found")
            return false
        }
        NSLog("AV-Live-Body: picked '%@'", device.localizedName)
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
        return true
    }

    func stop() {
        session.stopRunning()
    }
}
