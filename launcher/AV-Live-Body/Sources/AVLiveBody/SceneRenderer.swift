import Foundation
import Metal
import MetalKit

/// Renderer Metal pour les 10 viz modes background (storm, tunnel,
/// plasma, kaleido, voronoi, metaballs, starfield, bars, hands3d,
/// openpos). Reutilise le shader scene.metal porte depuis
/// data_only_viz Python. Sert de couche backing sous l'ARView dans
/// BodyView.
final class SceneRenderer: NSObject, MTKViewDelegate {
    // Mirror C struct of scene.metal SceneUniforms (20 floats)
    struct SceneUniforms {
        var time: Float = 0
        var rms: Float = 0
        var kp_norm: Float = 0
        var netz_dev: Float = 0
        var lightning_flash: Float = 0
        var flare: Float = 0
        var wind_norm: Float = 0
        var bz_norm: Float = 0
        var social_rate: Float = 0
        var pose_alive: Float = 0
        var pose_count: Float = 0
        var width: Float = 1280
        var height: Float = 720
        var viz_mode: Float = 0
        var hand_l_x: Float = 0
        var hand_l_y: Float = 0
        var hand_r_x: Float = 0
        var hand_r_y: Float = 0
        var _pad0: Float = 0
        var _pad1: Float = 0
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bgPipeline: MTLRenderPipelineState
    private let uniformsBuffer: MTLBuffer
    private var startTime: CFTimeInterval = CACurrentMediaTime()

    /// Mis a jour en live depuis RenderSettings / OSC handler.
    var uniforms = SceneUniforms()

    static func make() -> SceneRenderer? {
        return SceneRenderer.init(failable: ())
    }

    private init?(failable: Void) {
        guard let dev = MTLCreateSystemDefaultDevice(),
              let queue = dev.makeCommandQueue() else { return nil }
        self.device = dev
        self.commandQueue = queue

        // Compile scene.metal au runtime depuis le bundle
        guard let url = Bundle.module.url(forResource: "scene",
                                          withExtension: "metal"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            print("SceneRenderer: scene.metal absent du bundle")
            return nil
        }
        let opts = MTLCompileOptions()
        let lib: MTLLibrary
        do {
            lib = try dev.makeLibrary(source: source, options: opts)
        } catch {
            print("SceneRenderer: scene.metal compile error: \(error)")
            return nil
        }
        guard let vfn = lib.makeFunction(name: "bg_vertex"),
              let ffn = lib.makeFunction(name: "bg_fragment") else {
            print("SceneRenderer: bg_vertex/bg_fragment missing")
            return nil
        }
        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vfn
        pd.fragmentFunction = ffn
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        // Pas de blending : le MTKView est opaque, l'ARView par-dessus
        // est transparent.
        do {
            self.bgPipeline = try dev.makeRenderPipelineState(descriptor: pd)
        } catch {
            print("SceneRenderer: pipeline build failed: \(error)")
            return nil
        }
        guard let buf = dev.makeBuffer(
            length: MemoryLayout<SceneUniforms>.stride,
            options: .storageModeShared) else { return nil }
        self.uniformsBuffer = buf
        super.init()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.width = Float(size.width)
        uniforms.height = Float(size.height)
    }

    func draw(in view: MTKView) {
        uniforms.time = Float(CACurrentMediaTime() - startTime)
        // Copy uniforms vers buffer GPU (shared memory)
        let ptr = uniformsBuffer.contents().bindMemory(
            to: SceneUniforms.self, capacity: 1)
        ptr.pointee = uniforms

        guard let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cb = commandQueue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else {
            return
        }
        enc.setRenderPipelineState(bgPipeline)
        enc.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }
}
