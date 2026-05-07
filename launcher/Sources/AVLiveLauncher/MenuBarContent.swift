import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var processManager: ProcessManager
    let openLogs: () -> Void
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AV-Live")
                .font(.headline)

            Divider()

            ProcessRow(
                title: "SuperCollider",
                subtitle: "sclang + scsynth + web bridge",
                isRunning: processManager.sclangRunning,
                start: processManager.startSclang,
                stop: processManager.stopSclang
            )

            ProcessRow(
                title: "Oscilloscope",
                subtitle: "oscope-of visualizer",
                isRunning: processManager.oscopeRunning,
                start: processManager.startOscope,
                stop: processManager.stopOscope
            )

            Divider()

            HStack {
                Button(action: openLogs) {
                    Label("Logs", systemImage: "text.alignleft")
                }
                Button(action: { showSettings = true }) {
                    Label("Paths…", systemImage: "gearshape")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 360)
        .sheet(isPresented: $showSettings) {
            SettingsView(processManager: processManager,
                         dismiss: { showSettings = false })
        }
    }
}

private struct ProcessRow: View {
    let title: String
    let subtitle: String
    let isRunning: Bool
    let start: () -> Void
    let stop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(isRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button(isRunning ? "Stop" : "Start") {
                isRunning ? stop() : start()
            }
            .frame(width: 60)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var processManager: ProcessManager
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Auto-start everything when the app launches",
                   isOn: Binding(
                    get: { processManager.autoStart },
                    set: { processManager.autoStart = $0 }
                   ))
            Divider()
            Text("Paths").font(.headline)
            PathField(
                label: "sclang binary",
                path: Binding(
                    get: { processManager.sclangPath },
                    set: { processManager.sclangPath = $0 }
                ),
                isDirectory: false
            )
            PathField(
                label: "Load file (00_load.scd)",
                path: Binding(
                    get: { processManager.soundAlgoLoadFile },
                    set: { processManager.soundAlgoLoadFile = $0 }
                ),
                isDirectory: false
            )
            PathField(
                label: "oscope-of binary",
                path: Binding(
                    get: { processManager.oscopePath },
                    set: { processManager.oscopePath = $0 }
                ),
                isDirectory: false
            )
            HStack {
                Spacer()
                Button("Done", action: dismiss).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

private struct PathField: View {
    let label: String
    @Binding var path: String
    let isDirectory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack {
                TextField("", text: $path)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = !isDirectory
                    panel.canChooseDirectories = isDirectory
                    panel.allowsMultipleSelection = false
                    panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
                    if panel.runModal() == .OK, let url = panel.url {
                        path = url.path
                    }
                }
            }
        }
    }
}
