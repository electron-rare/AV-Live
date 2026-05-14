import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    @StateObject private var session = ARBodySession()
    @State private var host: String = "192.168.0.159"
    @State private var pythonPort: String = "57128"   // -> data_only_viz IphoneOSCListener
    @State private var swiftPort: String = "57129"    // -> AVLiveBody ArkitOSCListener (diagnostic)
    @State private var sendEnvMesh: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ARViewContainer(session: session)
                    .ignoresSafeArea()
                SkeletonOverlay(snapshot: session.skeleton2D,
                                parents: session.bodyParentIndices)
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

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AR Body → AV-Live")
                .font(.headline)
                .foregroundColor(.white)
            HStack {
                Text("Host").foregroundColor(.white)
                TextField("GrosMac IP", text: $host)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Py").foregroundColor(.white)
                TextField("57128", text: $pythonPort)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text("Swift").foregroundColor(.white)
                TextField("57129", text: $swiftPort)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            Toggle(isOn: $sendEnvMesh) {
                Text("Env mesh (LiDAR)").foregroundColor(.white)
            }
            HStack {
                Button(session.running ? "Stop" : "Start") {
                    if session.running {
                        session.stop()
                    } else {
                        session.configure(
                            host: host,
                            pythonPort: UInt16(pythonPort) ?? 57128,
                            swiftPort: UInt16(swiftPort) ?? 57129,
                            sendEnvMesh: sendEnvMesh)
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
            Text("bodies: \(session.bodyCount)  frames: \(session.framesSent)  joints/s: \(Int(session.jointsPerSec))")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(.black.opacity(0.5))
        .cornerRadius(10)
        .padding()
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
