import SwiftUI
import simd

/// Lightweight SwiftUI overlay that draws the 68-point face skeleton and
/// 21-point hand skeletons sent by data_only_viz/pose_bridge.py over OSC.
/// Sits in the ContentView ZStack above BodyView. Coordinates from the
/// listener are normalised (0..1 in image space) ; here we map them to
/// the overlay's geometry. Rendering is intentionally minimal : small
/// dots + a few polylines for facial features and hand bones.
struct FaceHandOverlay: View {
    @ObservedObject var poseListener: PoseOSCListener
    var showFace: Bool = true
    var showHands: Bool = true

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                if showFace {
                    for face in poseListener.faces.values {
                        drawFace(face, in: &ctx, size: size)
                    }
                }
                if showHands {
                    for hand in poseListener.hands.values {
                        drawHand(hand, in: &ctx, size: size)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Face (dlib 68 layout)

    /// Index spans in the 68-point dlib convention.
    private static let jaw       = Array(0..<17)
    private static let browR     = Array(17..<22)
    private static let browL     = Array(22..<27)
    private static let noseBridge = Array(27..<31)
    private static let nostril   = Array(31..<36)
    private static let eyeR      = Array(36..<42)
    private static let eyeL      = Array(42..<48)
    private static let lipOuter  = Array(48..<60)
    private static let lipInner  = Array(60..<68)

    private func drawFace(_ face: PoseOSCListener.FaceFrame,
                          in ctx: inout GraphicsContext,
                          size: CGSize) {
        let stroke = GraphicsContext.Shading.color(.green.opacity(0.85))
        let dot    = GraphicsContext.Shading.color(.green.opacity(0.95))

        drawPolyline(face.points, indices: Self.jaw, closed: false,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.browR, closed: false,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.browL, closed: false,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.noseBridge, closed: false,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.nostril, closed: false,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.eyeR, closed: true,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.eyeL, closed: true,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.lipOuter, closed: true,
                     in: &ctx, size: size, shading: stroke, width: 1.2)
        drawPolyline(face.points, indices: Self.lipInner, closed: true,
                     in: &ctx, size: size, shading: stroke, width: 1.0)

        for i in 0..<68 where face.hasPoint[i] {
            let p = mapPoint(face.points[i], size: size)
            let r = CGRect(x: p.x - 1.2, y: p.y - 1.2,
                           width: 2.4, height: 2.4)
            ctx.fill(Path(ellipseIn: r), with: dot)
        }
    }

    // MARK: - Hand (MediaPipe 21 landmarks)

    /// MediaPipe hand bone connectivity (5 fingers x 4 bones + palm).
    private static let handBones: [(Int, Int)] = [
        // Thumb
        (0, 1), (1, 2), (2, 3), (3, 4),
        // Index
        (0, 5), (5, 6), (6, 7), (7, 8),
        // Middle
        (5, 9), (9, 10), (10, 11), (11, 12),
        // Ring
        (9, 13), (13, 14), (14, 15), (15, 16),
        // Pinky
        (13, 17), (17, 18), (18, 19), (19, 20),
        // Palm closure
        (0, 17),
    ]

    private func drawHand(_ hand: PoseOSCListener.HandFrame,
                          in ctx: inout GraphicsContext,
                          size: CGSize) {
        // Left = cyan, right = magenta.
        let color: Color = hand.side == 0 ? .cyan : .pink
        let stroke = GraphicsContext.Shading.color(color.opacity(0.85))
        let dot    = GraphicsContext.Shading.color(color.opacity(0.95))

        for (a, b) in Self.handBones {
            guard hand.hasPoint[a], hand.hasPoint[b] else { continue }
            let pa = mapPoint(hand.points[a], size: size)
            let pb = mapPoint(hand.points[b], size: size)
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)
            ctx.stroke(path, with: stroke, lineWidth: 1.8)
        }
        for i in 0..<21 where hand.hasPoint[i] {
            let p = mapPoint(hand.points[i], size: size)
            let r = CGRect(x: p.x - 1.8, y: p.y - 1.8,
                           width: 3.6, height: 3.6)
            ctx.fill(Path(ellipseIn: r), with: dot)
        }
    }

    // MARK: - Helpers

    private func drawPolyline(_ pts: [SIMD2<Float>],
                              indices: [Int],
                              closed: Bool,
                              in ctx: inout GraphicsContext,
                              size: CGSize,
                              shading: GraphicsContext.Shading,
                              width: CGFloat) {
        guard indices.count >= 2 else { return }
        var path = Path()
        var started = false
        for i in indices {
            let p = mapPoint(pts[i], size: size)
            if !started {
                path.move(to: p)
                started = true
            } else {
                path.addLine(to: p)
            }
        }
        if closed, let first = indices.first {
            path.addLine(to: mapPoint(pts[first], size: size))
        }
        ctx.stroke(path, with: shading, lineWidth: width)
    }

    private func mapPoint(_ p: SIMD2<Float>, size: CGSize) -> CGPoint {
        // Normalised coords come from MediaPipe in image space already.
        CGPoint(x: CGFloat(p.x) * size.width,
                y: CGFloat(p.y) * size.height)
    }
}
