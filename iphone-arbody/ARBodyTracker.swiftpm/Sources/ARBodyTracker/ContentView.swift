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
        ZStack(alignment: .topLeading) {
            ARViewContainer(session: session)
                .ignoresSafeArea()
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
                Text("frames: \(session.framesSent)  joints/s: \(Int(session.jointsPerSec))")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(.black.opacity(0.5))
            .cornerRadius(10)
            .padding()
        }
    }
}
