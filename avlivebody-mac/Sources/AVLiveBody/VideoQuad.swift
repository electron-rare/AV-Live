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
        material.color = .init(tint: .white,
                               texture: .init(texture))
        entity.model?.materials = [material]
    }
}
