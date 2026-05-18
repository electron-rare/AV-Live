import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    @StateObject private var session = ARBodySession()
    @State private var sendEnvMesh: Bool = false

    /// Replace the live ARView with a gradient placeholder. Camera is
    /// unavailable inside Xcode previews; enable this flag there so the
    /// panel + skeleton overlay can still be laid out.
    var useMockBackground: Bool = false
    /// Overlay a synthetic ARKit T-pose so the skeleton renderer can be
    /// tuned without running on a device.
    var useMockSkeleton: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                cameraBackground
                    .ignoresSafeArea()
                SkeletonOverlay(
                    snapshot: useMockSkeleton
                        ? SkeletonSnapshot.mockTPose(in: geo.size)
                        : session.skeleton2D,
                    parents: useMockSkeleton
                        ? SkeletonSnapshot.mockParents
                        : session.bodyParentIndices)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                controlPanel
            }
            .onAppear { session.viewportSize = geo.size }
            .onChange(of: geo.size) { _, newSize in
                session.viewportSize = newSize
            }
        }
    }

    private var usbDotColor: Color {
        switch session.usbState {
        case .idle:       return .gray
        case .listening:  return .yellow
        case .connected:  return .green
        }
    }

    private var usbStateLabel: String {
        switch session.usbState {
        case .idle:       return "idle"
        case .listening:  return "listening :\(USBServer.port)"
        case .connected:  return "connected"
        }
    }

    @ViewBuilder
    private var cameraBackground: some View {
        if useMockBackground {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.20, blue: 0.24),
                        Color(red: 0.05, green: 0.05, blue: 0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
                Text("camera preview\n(unavailable in Xcode canvas)")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.35))
            }
        } else {
            ARViewContainer(session: session)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AR Body → AV-Live")
                .font(.headline)
                .foregroundColor(.white)
            Toggle(isOn: $sendEnvMesh) {
                Text("Env mesh (LiDAR)").foregroundColor(.white)
            }
            HStack {
                Button(session.running ? "Stop" : "Start") {
                    if session.running {
                        session.stop()
                    } else {
                        session.configure(sendEnvMesh: sendEnvMesh)
                        session.start()
                    }
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Text(session.status)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(.black.opacity(0.5))
                    .cornerRadius(6)
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(usbDotColor)
                    .frame(width: 8, height: 8)
                Text("USB \(usbStateLabel)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                Spacer(minLength: 8)
                Text("bodies: \(session.bodyCount)  frames: \(session.framesSent)  j/s: \(Int(session.jointsPerSec))")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(.black.opacity(0.5))
        .cornerRadius(10)
        .padding()
    }
}

extension SkeletonSnapshot {
    /// Parent indices for the 16-joint preview stick figure. Each entry
    /// is the parent joint index, or -1 for the root (head).
    static let mockParents: [Int] = [
        -1,  // 0 head
         0,  // 1 neck
         1,  // 2 lShoulder
         1,  // 3 rShoulder
         2,  // 4 lElbow
         3,  // 5 rElbow
         4,  // 6 lWrist
         5,  // 7 rWrist
         1,  // 8 spine
         8,  // 9 pelvis
         9,  // 10 lHip
         9,  // 11 rHip
        10,  // 12 lKnee
        11,  // 13 rKnee
        12,  // 14 lAnkle
        13,  // 15 rAnkle
    ]

    /// Synthetic 16-joint stick figure used by Xcode previews. ARKit
    /// is not available in the preview canvas, so we cannot rely on
    /// `ARSkeletonDefinition.neutralBodySkeleton3D` (returns nil).
    static func mockTPose(in size: CGSize) -> SkeletonSnapshot {
        // Normalized layout: origin at body center, +y down, ±1 spans
        // roughly the full body height.
        let layout: [CGPoint] = [
            CGPoint(x:  0.00, y: -0.45),
            CGPoint(x:  0.00, y: -0.32),
            CGPoint(x: -0.18, y: -0.30),
            CGPoint(x:  0.18, y: -0.30),
            CGPoint(x: -0.30, y: -0.12),
            CGPoint(x:  0.30, y: -0.12),
            CGPoint(x: -0.36, y:  0.08),
            CGPoint(x:  0.36, y:  0.08),
            CGPoint(x:  0.00, y: -0.10),
            CGPoint(x:  0.00, y:  0.06),
            CGPoint(x: -0.10, y:  0.09),
            CGPoint(x:  0.10, y:  0.09),
            CGPoint(x: -0.12, y:  0.30),
            CGPoint(x:  0.12, y:  0.30),
            CGPoint(x: -0.13, y:  0.46),
            CGPoint(x:  0.13, y:  0.46),
        ]
        let scale = min(size.width * 0.9, size.height * 0.8)
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let pts: [CGPoint?] = layout.map {
            CGPoint(x: cx + $0.x * scale,
                    y: cy + $0.y * scale)
        }
        return SkeletonSnapshot(
            points: pts,
            tracked: Array(repeating: true, count: pts.count))
    }
}

/// Draws ARKit body joints + bones over the camera view. Bones are
/// derived from `ARSkeletonDefinition.defaultBody3D` parent indices.
struct SkeletonOverlay: View {
    let snapshot: SkeletonSnapshot?
    let parents: [Int]

    var body: some View {
        Canvas { ctx, _ in
            guard let snap = snapshot else { return }
            for (i, parent) in parents.enumerated() where parent >= 0 {
                guard i < snap.points.count, parent < snap.points.count,
                      let a = snap.points[i], let b = snap.points[parent]
                else { continue }
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                let solid = snap.tracked[i] && snap.tracked[parent]
                ctx.stroke(
                    path,
                    with: .color(solid ? .green : .yellow.opacity(0.5)),
                    lineWidth: solid ? 2 : 1.2)
            }
            for (i, pt) in snap.points.enumerated() {
                guard let pt else { continue }
                let r: CGFloat = snap.tracked[i] ? 4 : 2.5
                let rect = CGRect(x: pt.x - r, y: pt.y - r,
                                  width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(snap.tracked[i]
                                      ? .cyan : .yellow.opacity(0.8)))
            }
        }
    }
}

#Preview("iPhone 15 Pro — portrait") {
    ContentView(useMockBackground: true, useMockSkeleton: true)
}

#Preview("iPhone 15 Pro — landscape", traits: .landscapeLeft) {
    ContentView(useMockBackground: true, useMockSkeleton: true)
}

#Preview("Empty camera (no body)") {
    ContentView(useMockBackground: true, useMockSkeleton: false)
}
