import AppKit
import CoreImage
import CoreVideo
import Foundation
import RealityKit

/// A flat plane at the back of the scene, textured with the iPhone
/// camera video. `update(_:)` is called on the main queue per frame.
@MainActor
final class VideoQuad {
    let entity = ModelEntity()

    private let ciContext = CIContext()
    private var opacity: Double = 1.0
    /// Plane is 1.6 m wide, 16:9; positioned 2 m behind the body.
    private static let width: Float = 1.6
    private static let height: Float = 0.9
    private static let zBack: Float = -2.0

    init() {
        let plane = MeshResource.generatePlane(
            width: Self.width, height: Self.height)
        var material = UnlitMaterial()
        material.color = .init(tint: .white)
        entity.model = ModelComponent(mesh: plane,
                                      materials: [material])
        entity.transform.translation =
            SIMD3<Float>(0, 0, Self.zBack)
    }

    func setVisible(_ visible: Bool) { entity.isEnabled = visible }

    func setOpacity(_ value: Double) {
        opacity = value
        // Re-tint current material; `update(_:)` will also use `opacity`.
        if var mat = entity.model?.materials.first as? UnlitMaterial {
            mat.color = .init(tint: NSColor(white: 1, alpha: CGFloat(value)))
            entity.model?.materials = [mat]
        }
    }

    /// Replace the plane's texture from a decoded camera frame.
    func update(_ pixelBuffer: CVPixelBuffer) {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(
            ci, from: ci.extent) else { return }
        guard let texture = try? TextureResource(
            image: cg, options: .init(semantic: .color)) else {
            NSLog("VideoQuad: TextureResource creation failed (%dx%d)",
                  CVPixelBufferGetWidth(pixelBuffer),
                  CVPixelBufferGetHeight(pixelBuffer))
            return
        }
        var material = UnlitMaterial()
        material.color = .init(
            tint: NSColor(white: 1, alpha: CGFloat(opacity)),
            texture: .init(texture))
        entity.model?.materials = [material]
    }
}
