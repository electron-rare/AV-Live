import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var processManager: ProcessManager
    let openLogs: () -> Void
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AV-Live")
                    .font(.headline)
                Spacer()
                Picker("", selection: Binding(
                    get: { processManager.mode },
                    set: { processManager.mode = $0 }
                )) {
                    ForEach(LaunchMode.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 200)
            }

            Divider()

            // -- Process rows pilotes par le mode -----------------------
            if processManager.mode == .bodyMesh {
                // Mode bodyMesh : Multi-HMR headless + AVB + SC + feeds
                ProcessRow(
                    title: "SuperCollider",
                    subtitle: "sclang + scsynth (audio)",
                    isRunning: processManager.sclangRunning,
                    start: processManager.startSclang,
                    stop: processManager.stopSclang
                )
                ProcessRow(
                    title: "Multi-HMR worker",
                    subtitle: "Python headless — SMPL-X via TCP :57130",
                    isRunning: processManager.metalVizRunning,
                    start: processManager.startMetalViz,
                    stop: processManager.stopMetalViz
                )
                ProcessRow(
                    title: "AV-Live-Body",
                    subtitle: "RealityKit mesh renderer + cam overlay",
                    isRunning: processManager.bodyAppRunning,
                    start: processManager.startBodyApp,
                    stop: processManager.stopBodyApp
                )
            } else {
                // SC + oF sont communs aux modes full / dataOnly.
                ProcessRow(
                    title: "SuperCollider",
                    subtitle: processManager.mode == .dataOnly
                        ? "sclang + scsynth (pas de web bridge)"
                        : "sclang + scsynth + web bridge",
                    isRunning: processManager.sclangRunning,
                    start: processManager.startSclang,
                    stop: processManager.stopSclang
                )
                if processManager.mode == .dataOnly {
                    ProcessRow(
                        title: "Metal Viz",
                        subtitle: "Python + pyobjc + Metal (data-only)",
                        isRunning: processManager.metalVizRunning,
                        start: processManager.startMetalViz,
                        stop: processManager.stopMetalViz
                    )
                    Toggle("Multi-HMR (mesh SMPL-X dense via :57130)",
                           isOn: $processManager.useMultiHMR)
                        .toggleStyle(.switch)
                        .font(.caption)
                        .padding(.horizontal, 4)
                } else {
                    ProcessRow(
                        title: "Oscilloscope",
                        subtitle: "oscope-of visualizer",
                        isRunning: processManager.oscopeRunning,
                        start: processManager.startOscope,
                        stop: processManager.stopOscope
                    )
                }
            }
            if processManager.mode == .full || processManager.mode == .dataOnly {
                ProcessRow(
                    title: "Web UI",
                    subtitle: "Express :\(processManager.webPort) — control + Hydra",
                    isRunning: processManager.webRunning,
                    start: processManager.startWeb,
                    stop: processManager.stopWeb
                )
            }
            ProcessRow(
                title: "Data Feeds",
                subtitle: processManager.mode == .dataOnly
                    ? "config.data-only.toml — pose YOLO + opendata"
                    : (processManager.mode == .bodyMesh
                        ? "config.data-only.toml — sonification only"
                        : "USGS · SWPC · Grid · Lightning · Pose · …"),
                isRunning: processManager.dataFeedsRunning,
                start: processManager.startDataFeeds,
                stop: processManager.stopDataFeeds
            )

            // AV-Live-Body — toujours disponible, lancable a la demande
            // depuis n'importe quel mode (le worker Multi-HMR doit tourner
            // pour qu'il recoive des vertices, sinon fenetre vide).
            if processManager.mode != .bodyMesh {
                ProcessRow(
                    title: "AV-Live-Body",
                    subtitle: "RealityKit mesh + cam (touche S = panel)",
                    isRunning: processManager.bodyAppRunning,
                    start: processManager.startBodyApp,
                    stop: processManager.stopBodyApp
                )
            }

            // Dashboard web data-only (Express :3211, dashboard + carte
            // monde live OSC). Visible en dataOnly + bodyMesh.
            if processManager.mode == .dataOnly
                || processManager.mode == .bodyMesh {
                ProcessRow(
                    title: "Dashboard data-only",
                    subtitle: "Express :\(processManager.dataWebPort) — dashboard + carte monde",
                    isRunning: processManager.dataWebRunning,
                    start: processManager.startDataWeb,
                    stop: processManager.stopDataWeb
                )
                if processManager.dataWebRunning {
                    HStack {
                        Button(action: processManager.openDataDashboard) {
                            Label("Dashboard", systemImage: "gauge")
                        }
                        Button(action: processManager.openDataMap) {
                            Label("Carte monde", systemImage: "globe")
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }

            if processManager.mode == .full {
                HStack {
                    Button(action: processManager.openBrowser) {
                        Label("Control", systemImage: "slider.horizontal.3")
                    }
                    .disabled(!processManager.webRunning)
                    Button(action: processManager.openHydra) {
                        Label("Hydra", systemImage: "waveform")
                    }
                    .disabled(!processManager.webRunning)
                    Spacer()
                }
                Divider()
                // Album quick-launcher : sends /control/playAlbum <letter> over OSC
                AlbumLauncher(processManager: processManager)
            } else {
                // Mode data-only : section installation des dependances + statut
                DataOnlyPanel(processManager: processManager)
            }

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
        .frame(width: 380)
        .sheet(isPresented: $showSettings) {
            SettingsView(processManager: processManager,
                         dismiss: { showSettings = false })
        }
    }
}

private struct DataOnlyPanel: View {
    @ObservedObject var processManager: ProcessManager
    @State private var depsStatus: String = "checking…"
    @State private var installing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Pose dependencies").font(.subheadline).bold()
                Spacer()
                Circle()
                    .fill(depsStatus == "installed" ? Color.green
                          : (installing ? Color.orange : Color.red))
                    .frame(width: 10, height: 10)
                Text(depsStatus).font(.caption).foregroundColor(.secondary)
            }
            HStack {
                Button(action: installPoseDeps) {
                    Label(installing ? "Installing…" : "Install pose deps",
                          systemImage: "arrow.down.circle")
                }
                .disabled(installing)
                Button(action: refreshDepsStatus) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh dependency check")
                Spacer()
            }
            Text("OSC out: 127.0.0.1:57121 (SC) + 127.0.0.1:57123 (oF)")
                .font(.caption).foregroundColor(.secondary)

            Divider()
            Text("Source open-data → preset").font(.subheadline).bold()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    PresetButton(source: "USGS",   effect: "seismic",     scene: "geo",     viz: "voronoi",   processManager: processManager)
                    PresetButton(source: "Blitz",  effect: "lightning",   scene: "pulse",   viz: "storm",     processManager: processManager)
                    PresetButton(source: "Wind",   effect: "solar drone", scene: "weather", viz: "tunnel",    processManager: processManager)
                    PresetButton(source: "Kp/Bz",  effect: "geomag",      scene: "geo",     viz: "plasma",    processManager: processManager)
                }
                HStack(spacing: 4) {
                    PresetButton(source: "X-ray",  effect: "flare",       scene: "weather", viz: "bars",      processManager: processManager)
                    PresetButton(source: "OpenSky",effect: "aviation",    scene: "flight",  viz: "kaleido",   processManager: processManager)
                    PresetButton(source: "Bsky",   effect: "social pulse",scene: "pulse",   viz: "bars",      processManager: processManager)
                    PresetButton(source: "Pose",   effect: "body",        scene: "body",    viz: "metaballs", processManager: processManager)
                }
                HStack(spacing: 4) {
                    PresetButton(source: "Cosmos", effect: "all sources", scene: "full",    viz: "starfield", processManager: processManager)
                    Spacer()
                }
            }

            Divider()
            Text("Audio scene").font(.subheadline).bold()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    SceneButton(label: "all",     processManager: processManager)
                    SceneButton(label: "full",    processManager: processManager)
                    SceneButton(label: "quiet",   processManager: processManager)
                    SceneButton(label: "stop",    processManager: processManager)
                }
                HStack(spacing: 4) {
                    SceneButton(label: "cavity",  processManager: processManager)
                    SceneButton(label: "geo",     processManager: processManager)
                    SceneButton(label: "body",    processManager: processManager)
                    SceneButton(label: "weather", processManager: processManager)
                }
                HStack(spacing: 4) {
                    SceneButton(label: "flight",  processManager: processManager)
                    SceneButton(label: "pulse",   processManager: processManager)
                    Spacer()
                }
            }

            Divider()
            Text("Visual mode").font(.subheadline).bold()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    VizModeButton(idx: 0, label: "storm",     processManager: processManager)
                    VizModeButton(idx: 1, label: "tunnel",    processManager: processManager)
                    VizModeButton(idx: 2, label: "plasma",    processManager: processManager)
                    VizModeButton(idx: 3, label: "kaleido",   processManager: processManager)
                }
                HStack(spacing: 4) {
                    VizModeButton(idx: 4, label: "voronoi",   processManager: processManager)
                    VizModeButton(idx: 5, label: "metaballs", processManager: processManager)
                    VizModeButton(idx: 6, label: "stars",     processManager: processManager)
                    VizModeButton(idx: 7, label: "bars",      processManager: processManager)
                }
            }
        }
        .onAppear { refreshDepsStatus() }
    }

    private func refreshDepsStatus() {
        // Detecte la presence du venv et des modules pose en background :
        // p.waitUntilExit() peut bloquer plusieurs centaines de ms sur un
        // cold cache (disque, NSFileCoordinator), ce qui freezerait le UI.
        let venvPython = processManager.dataFeedsDir + "/.venv/bin/python"
        guard FileManager.default.isExecutableFile(atPath: venvPython) else {
            depsStatus = "no venv"
            return
        }
        depsStatus = "checking…"
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: venvPython)
            p.arguments = ["-c", "import cv2, ultralytics, numpy"]
            let null = Pipe(); p.standardOutput = null; p.standardError = null
            var status: String
            do {
                try p.run()
                p.waitUntilExit()
                status = (p.terminationStatus == 0) ? "installed" : "missing"
            } catch {
                status = "error"
            }
            DispatchQueue.main.async { depsStatus = status }
        }
    }

    private func installPoseDeps() {
        installing = true
        depsStatus = "syncing…"
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: processManager.uvPath)
            p.arguments = ["sync", "--extra", "pose"]
            p.currentDirectoryURL = URL(fileURLWithPath: processManager.dataFeedsDir)
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = (env["PATH"] ?? "")
                + ":/opt/homebrew/bin:/usr/local/bin:\(env["HOME"] ?? "")/.local/bin"
            p.environment = env
            do {
                try p.run()
                p.waitUntilExit()
            } catch {
                // ignore — refreshDepsStatus va remonter l'echec
            }
            DispatchQueue.main.async {
                installing = false
                refreshDepsStatus()
            }
        }
    }
}

private struct PresetButton: View {
    let source: String      // nom de la source open-data (USGS, Blitz, ...)
    let effect: String      // effet musical/visuel (seismic, lightning, ...)
    let scene: String       // scene SC associee
    let viz: String         // viz mode Metal associe
    let processManager: ProcessManager
    @ObservedObject var pm: ProcessManager
    init(source: String, effect: String, scene: String, viz: String, processManager: ProcessManager) {
        self.source = source; self.effect = effect
        self.scene = scene; self.viz = viz
        self.processManager = processManager
        self.pm = processManager
    }
    private var isActive: Bool {
        pm.activePreset == source
    }
    var body: some View {
        Button(action: {
            processManager.osc.send("/control/doScene", scene)
            processManager.oscViz.send("/control/vizMode", viz)
            // Notifie le HUD du preset actif via /control/preset <source>
            processManager.oscViz.send("/control/preset", source)
            DispatchQueue.main.async { pm.activePreset = source }
        }) {
            VStack(spacing: 1) {
                Text(source)
                    .font(.system(.caption, design: .monospaced).bold())
                Text(effect)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 60, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.accentColor.opacity(0.25) : .clear)
            )
        }
        .buttonStyle(.bordered)
        .help("Source: \(source) · Scene: \(scene) · Viz: \(viz)")
        .disabled(!processManager.sclangRunning && !processManager.metalVizRunning)
    }
}

private struct VizModeButton: View {
    let idx: Int
    let label: String
    let processManager: ProcessManager
    var body: some View {
        Button(action: {
            // Routage direct vers le visualizer Metal (data_only_viz)
            // sur 57123. Le viz Python ecoute /control/vizMode <int|string>.
            processManager.oscViz.send("/control/vizMode", idx)
        }) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 56)
        }
        .buttonStyle(.bordered)
        .disabled(!processManager.metalVizRunning)
    }
}

private struct SceneButton: View {
    let label: String
    let processManager: ProcessManager
    var body: some View {
        Button(action: {
            // Le patch data-only utilise /control/doScene ; l'ancien
            // /control/dataScene est garde en fallback compat (data_only_program.scd)
            processManager.osc.send("/control/doScene", label)
            processManager.osc.send("/control/dataScene", label)
        }) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 48)
        }
        .buttonStyle(.bordered)
        .disabled(!processManager.sclangRunning)
    }
}

private struct AlbumLauncher: View {
    @ObservedObject var processManager: ProcessManager
    @State private var albums: [ProcessManager.Album] = []
    @State private var gap: Int = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Albums").font(.subheadline).bold()
                Spacer()
                Text("gap").font(.caption).foregroundColor(.secondary)
                Stepper(value: $gap, in: 0...32) {
                    Text("\(gap)s").font(.system(.caption, design: .monospaced))
                }
                .labelsHidden()
                .frame(width: 60)
                Button(action: processManager.stopAlbum) {
                    Image(systemName: "stop.fill")
                }
                .help("Stop album")
            }
            if albums.isEmpty {
                Text("no tracks/ folder found")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(albums) { album in
                            Button(action: {
                                processManager.playAlbum(album.letter, gap: gap)
                            }) {
                                VStack(spacing: 1) {
                                    Text(album.letter)
                                        .font(.system(.caption, design: .monospaced).bold())
                                    Text(album.displayTitle)
                                        .font(.system(size: 9))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(width: 64, height: 30)
                                .padding(.horizontal, 2)
                            }
                            .help("\(album.letter) — \(album.displayTitle)")
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onAppear { albums = processManager.discoverAlbums() }
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
            Toggle("Open browser at http://localhost:\(processManager.webPort) on launch",
                   isOn: Binding(
                    get: { processManager.autoOpenBrowser },
                    set: { processManager.autoOpenBrowser = $0 }
                   ))
            Toggle("Auto-start data_feeds bridge (USGS, SWPC, grid, pose…)",
                   isOn: Binding(
                    get: { processManager.autoStartDataFeeds },
                    set: { processManager.autoStartDataFeeds = $0 }
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
            PathField(
                label: "node binary",
                path: Binding(
                    get: { processManager.nodePath },
                    set: { processManager.nodePath = $0 }
                ),
                isDirectory: false
            )
            PathField(
                label: "Web server.js",
                path: Binding(
                    get: { processManager.webServerScript },
                    set: { processManager.webServerScript = $0 }
                ),
                isDirectory: false
            )
            PathField(
                label: "uv binary",
                path: Binding(
                    get: { processManager.uvPath },
                    set: { processManager.uvPath = $0 }
                ),
                isDirectory: false
            )
            PathField(
                label: "data_feeds directory",
                path: Binding(
                    get: { processManager.dataFeedsDir },
                    set: { processManager.dataFeedsDir = $0 }
                ),
                isDirectory: true
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
