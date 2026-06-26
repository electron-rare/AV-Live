// avlivebody-mac/Sources/AVLiveBody/SceneUniformBuilder.swift
import AVLiveWire
import simd

enum SceneUniformBuilder {
    // ARKit defaultBody3D indices (best-effort constants — ARSkeletonDefinition
    // is iOS-only and cannot be queried here; verify indices against the
    // iPhone's 91-joint order if channels read zero unexpectedly; the j()
    // guard degrades any out-of-range or invalid joint to 0 gracefully).
    private static let hipsIdx = 0
    private static let headIdx = 51
    private static let lWristIdx = 32
    private static let rWristIdx = 7

    static func fill(_ u: inout SceneRenderer.SceneUniforms,
                     skeletons: [Int: SkeletonPayload],
                     hands: HandsPayload?,
                     face: FacePayload?,
                     prevPelvis: inout SIMD3<Float>?) {
        u.pose_count = Float(skeletons.count)
        u.pose_alive = skeletons.isEmpty ? 0 : 1

        if let body = skeletons.values.first {
            func j(_ i: Int) -> SIMD3<Float>? {
                (i < body.joints.count && body.valid[i]) ? body.joints[i] : nil
            }
            if let hips = j(hipsIdx) {
                u.body_x = hips.x; u.body_y = hips.y; u.body_z = hips.z
                if let prev = prevPelvis {
                    let v = simd_length(hips - prev)
                    u.pose_velocity = u.pose_velocity * 0.7 + v * 0.3
                }
                prevPelvis = hips
                if let head = j(headIdx) {
                    u.body_height = abs(head.y - hips.y)
                }
            }
            if let lw = j(lWristIdx), let rw = j(rWristIdx) {
                u.arm_spread = abs(lw.x - rw.x)
            }
        }

        // Hands (Phase-0 Vision, normalized [0,1]).
        u.hand_l_x = 0; u.hand_l_y = 0; u.hand_r_x = 0; u.hand_r_y = 0
        u.finger_pinch_l = 0; u.finger_pinch_r = 0
        for hand in hands?.hands ?? [] {
            let c = centroid(hand.points)           // (x,y)
            let pinch = dist(hand.points, 4, 8)     // thumb_tip..index_tip
            if hand.isRight {
                u.hand_r_x = c.x; u.hand_r_y = c.y; u.finger_pinch_r = pinch
            } else {
                u.hand_l_x = c.x; u.hand_l_y = c.y; u.finger_pinch_l = pinch
            }
        }

        // Face (Phase-0 Vision allPoints). Region-based derivation is
        // deferred to v2 — the Vision face-region index mapping is not yet
        // established. Leave all face scalars at 0 intentionally for v1.
        if let f = face, f.points.count > 8 {
            let ys = f.points.map { $0.y }, xs = f.points.map { $0.x }
            let h = (ys.max() ?? 0) - (ys.min() ?? 0)
            let w = (xs.max() ?? 0) - (xs.min() ?? 0)
            u.mouth_open = 0      // set from outer/inner-lip points at impl time
            u.eye_open_l = 0; u.eye_open_r = 0
            u.head_tilt = 0; u.head_yaw = 0
            _ = (h, w)
        }
    }

    private static func centroid(_ p: [SIMD3<Float>]) -> SIMD2<Float> {
        guard !p.isEmpty else { return .zero }
        var s = SIMD2<Float>(0, 0)
        for v in p { s.x += v.x; s.y += v.y }
        return s / Float(p.count)
    }
    private static func dist(_ p: [SIMD3<Float>], _ a: Int, _ b: Int)
        -> Float {
        guard a < p.count, b < p.count else { return 0 }
        return simd_length(SIMD2(p[a].x, p[a].y) - SIMD2(p[b].x, p[b].y))
    }
}
