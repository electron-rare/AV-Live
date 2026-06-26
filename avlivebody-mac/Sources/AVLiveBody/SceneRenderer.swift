import Foundation
import Metal
import MetalKit

/// Metal renderer for the 10 background viz modes (storm, tunnel,
/// plasma, kaleido, voronoi, metaballs, starfield, bars, hands3d,
/// openpos). Compiles the bundled scene.metal at runtime; sits as the
/// backing layer under the transparent ARView.
final class SceneRenderer: NSObject, MTKViewDelegate {
    /// Mirror of scene.metal SceneUniforms (36 floats, 144 B). Field
    /// order MUST match the shader exactly.
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
        var mouth_open: Float = 0
        var eye_open_l: Float = 0
        var eye_open_r: Float = 0
        var head_tilt: Float = 0
        var head_yaw: Float = 0
        var finger_pinch_l: Float = 0
        var finger_pinch_r: Float = 0
        var body_x: Float = 0
        var body_y: Float = 0
        var body_z: Float = 0
        var body_height: Float = 0
        var arm_spread: Float = 0
        var pose_velocity: Float = 0
        var _pad0: Float = 0
        var _pad1: Float = 0
        var _pad2: Float = 0
        var _pad3: Float = 0
        var _pad4: Float = 0
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bgPipeline: MTLRenderPipelineState
    private let uniformsBuffer: MTLBuffer
    private var startTime: CFTimeInterval = CACurrentMediaTime()

    var uniforms = SceneUniforms()

    static func make() -> SceneRenderer? { SceneRenderer(failable: ()) }

    private init?(failable: Void) {
        guard let dev = MTLCreateSystemDefaultDevice(),
              let queue = dev.makeCommandQueue() else { return nil }
        self.device = dev
        self.commandQueue = queue
        guard let url = Bundle.main.url(forResource: "scene",
                                        withExtension: "metal"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("SceneRenderer: scene.metal missing from bundle")
            return nil
        }
        let lib: MTLLibrary
        do { lib = try dev.makeLibrary(source: source,
                                       options: MTLCompileOptions()) }
        catch { NSLog("SceneRenderer: compile error %@",
                      String(describing: error)); return nil }
        guard let vfn = lib.makeFunction(name: "bg_vertex"),
              let ffn = lib.makeFunction(name: "bg_fragment") else {
            NSLog("SceneRenderer: bg_vertex/bg_fragment missing")
            return nil
        }
        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vfn
        pd.fragmentFunction = ffn
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        do { self.bgPipeline =
            try dev.makeRenderPipelineState(descriptor: pd) }
        catch { NSLog("SceneRenderer: pipeline failed %@",
                      String(describing: error)); return nil }
        guard let buf = dev.makeBuffer(
            length: MemoryLayout<SceneUniforms>.stride,
            options: .storageModeShared) else { return nil }
        self.uniformsBuffer = buf
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.width = Float(size.width)
        uniforms.height = Float(size.height)
    }

    func draw(in view: MTKView) {
        uniforms.time = Float(CACurrentMediaTime() - startTime)
        uniformsBuffer.contents().bindMemory(
            to: SceneUniforms.self, capacity: 1).pointee = uniforms
        guard let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cb = commandQueue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rpd)
        else { return }
        enc.setRenderPipelineState(bgPipeline)
        enc.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }
}
