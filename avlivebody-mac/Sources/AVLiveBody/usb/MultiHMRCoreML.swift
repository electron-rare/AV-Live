import CoreML
import CoreVideo
import CoreImage
import Foundation

/// One detected SMPL-X body from Multi-HMR.
struct MultiHMRPerson {
    var vertices: [SIMD3<Float>]   // 10475 SMPL-X verts, model space
    var translation: SIMD3<Float>  // pelvis translation
    var score: Float
}

/// CoreML wrapper around the bundled `multihmr_full_672_s.mlpackage`.
/// Mirrors `data_only_viz/multihmr_coreml.py`: two MLMultiArray inputs
/// (`image` 1x3x672x672 ImageNet-normalized, `cam_K` 1x3x3), fixed
/// K=4 person outputs.
final class MultiHMRCoreML {
    static let inputSize = 672
    static let vertexCount = 10475
    static let maxPersons = 4
    private static let detThreshold: Float = 0.3
    private static let normMean: [Float] = [0.485, 0.456, 0.406]
    private static let normStd: [Float] = [0.229, 0.224, 0.225]

    private let model: MLModel
    private let ciContext = CIContext()

    /// Loads the bundled model. Returns nil if the resource or load
    /// fails — callers fall back to skeleton-only rendering.
    init?() {
        guard let url = Bundle.main.url(
            forResource: "multihmr_full_672_s",
            withExtension: "mlmodelc") else {
            NSLog("MultiHMRCoreML: mlpackage resource missing")
            return nil
        }
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuAndGPU
        do {
            model = try MLModel(contentsOf: url, configuration: cfg)
        } catch {
            NSLog("MultiHMRCoreML: load failed %@",
                  String(describing: error))
            return nil
        }
    }

    /// Run inference on one camera frame. `cameraK` is the 3x3 camera
    /// intrinsics row-major.
    func infer(_ pixelBuffer: CVPixelBuffer,
               cameraK: [Float]) -> [MultiHMRPerson] {
        guard let image = makeImageInput(pixelBuffer),
              let k = makeKInput(cameraK) else { return [] }
        let inputs: [String: MLFeatureValue] = [
            "image": MLFeatureValue(multiArray: image),
            "cam_K": MLFeatureValue(multiArray: k),
        ]
        guard let provider = try? MLDictionaryFeatureProvider(
            dictionary: inputs),
              let out = try? model.prediction(from: provider) else {
            return []
        }
        return parse(out)
    }

    // MARK: - Input preprocessing

    /// `CVPixelBuffer` -> [1,3,672,672] Float32, RGB, ImageNet-normed.
    private func makeImageInput(_ pb: CVPixelBuffer) -> MLMultiArray? {
        let n = Self.inputSize
        // Resize to n x n BGRA via CoreImage.
        let ci = CIImage(cvPixelBuffer: pb)
        let sx = CGFloat(n) / ci.extent.width
        let sy = CGFloat(n) / ci.extent.height
        let scaled = ci.transformed(
            by: CGAffineTransform(scaleX: sx, y: sy))
        var dst: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, n, n,
            kCVPixelFormatType_32BGRA, nil, &dst)
        guard let dst else { return nil }
        ciContext.render(scaled, to: dst)
        CVPixelBufferLockBaseAddress(dst, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(dst, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(dst) else {
            return nil
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(dst)
        let px = base.assumingMemoryBound(to: UInt8.self)
        guard let arr = try? MLMultiArray(
            shape: [1, 3, NSNumber(value: n), NSNumber(value: n)],
            dataType: .float32) else { return nil }
        let ptr = arr.dataPointer.assumingMemoryBound(to: Float.self)
        let plane = n * n
        for y in 0..<n {
            for x in 0..<n {
                let p = y * rowBytes + x * 4   // BGRA
                let b = Float(px[p]) / 255.0
                let g = Float(px[p + 1]) / 255.0
                let r = Float(px[p + 2]) / 255.0
                let idx = y * n + x
                ptr[idx] =
                    (r - Self.normMean[0]) / Self.normStd[0]
                ptr[plane + idx] =
                    (g - Self.normMean[1]) / Self.normStd[1]
                ptr[2 * plane + idx] =
                    (b - Self.normMean[2]) / Self.normStd[2]
            }
        }
        return arr
    }

    /// 9 row-major intrinsics -> [1,3,3] Float32.
    private func makeKInput(_ k: [Float]) -> MLMultiArray? {
        guard k.count == 9,
              let arr = try? MLMultiArray(
                shape: [1, 3, 3], dataType: .float32) else { return nil }
        let ptr = arr.dataPointer.assumingMemoryBound(to: Float.self)
        for i in 0..<9 { ptr[i] = k[i] }
        return arr
    }

    // MARK: - Output parsing

    private func parse(_ out: MLFeatureProvider) -> [MultiHMRPerson] {
        guard let v3d = out.featureValue(for: "var_2420")?
                .multiArrayValue,
              let transl = out.featureValue(for: "var_2423")?
                .multiArrayValue,
              let scores = out.featureValue(for: "var_2436")?
                .multiArrayValue else { return [] }
        var persons: [MultiHMRPerson] = []
        let vc = Self.vertexCount
        for k in 0..<Self.maxPersons {
            let score = scores[k].floatValue
            if score < Self.detThreshold { continue }
            var verts = [SIMD3<Float>](
                repeating: .zero, count: vc)
            let base = k * vc * 3
            for i in 0..<vc {
                let o = base + i * 3
                verts[i] = SIMD3(v3d[o].floatValue,
                                 v3d[o + 1].floatValue,
                                 v3d[o + 2].floatValue)
            }
            let tb = k * 3
            persons.append(MultiHMRPerson(
                vertices: verts,
                translation: SIMD3(transl[tb].floatValue,
                                   transl[tb + 1].floatValue,
                                   transl[tb + 2].floatValue),
                score: score))
        }
        return persons
    }
}
