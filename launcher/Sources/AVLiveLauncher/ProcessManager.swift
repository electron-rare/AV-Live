import AppKit
import Combine
import Foundation

struct LogLine: Identifiable, Equatable {
    let id = UUID()
    let timestamp = Date()
    let source: String
    let text: String
}

final class ProcessManager: ObservableObject {
    // Observable state
    @Published var sclangRunning = false
    @Published var oscopeRunning = false
    @Published var webRunning = false
    @Published private(set) var logs: [LogLine] = []

    // Persisted paths (UserDefaults, key/value)
    @Published var sclangPath: String { didSet { defaults.set(sclangPath, forKey: "sclangPath") } }
    @Published var soundAlgoLoadFile: String { didSet { defaults.set(soundAlgoLoadFile, forKey: "soundAlgoLoadFile") } }
    @Published var oscopePath: String { didSet { defaults.set(oscopePath, forKey: "oscopePath") } }
    @Published var nodePath: String { didSet { defaults.set(nodePath, forKey: "nodePath") } }
    @Published var webServerScript: String { didSet { defaults.set(webServerScript, forKey: "webServerScript") } }
    @Published var webPort: Int { didSet { defaults.set(webPort, forKey: "webPort") } }
    @Published var autoStart: Bool { didSet { defaults.set(autoStart, forKey: "autoStart") } }
    @Published var autoOpenBrowser: Bool { didSet { defaults.set(autoOpenBrowser, forKey: "autoOpenBrowser") } }

    private let defaults = UserDefaults.standard
    private var sclangProc: Process?
    private var oscopeProc: Process?
    private var webProc: Process?
    private var sclangWantsRestart = false
    let osc = OSCSender(host: "127.0.0.1", port: 57121)
    private let logQueue = DispatchQueue(label: "cc.saillant.avlive.log")
    private let maxLogLines = 2000

    init() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // Discover the AV-Live tree by trying a list of likely locations.
        // First match wins. Includes the path derived from the .app bundle
        // when the launcher is installed inside an AV-Live checkout.
        let avLiveCandidates: [String] = {
            var c: [String] = []
            // Walk up from the bundle: <root>/launcher/build/AVLiveLauncher.app
            let bundleParents = (0..<5).reduce(into: [URL]()) { acc, _ in
                let last = acc.last ?? Bundle.main.bundleURL
                acc.append(last.deletingLastPathComponent())
            }
            for url in bundleParents {
                let candidate = url.path
                if fm.fileExists(atPath: candidate + "/sound_algo/00_load.scd") {
                    c.append(candidate)
                }
            }
            // Plus the well-known paths
            c.append("\(home)/AV-Live")
            c.append("\(home)/Documents/Projets/AV-Live")
            return c
        }()
        let avLive = avLiveCandidates.first(where: {
            fm.fileExists(atPath: $0 + "/sound_algo/00_load.scd")
        }) ?? "\(home)/AV-Live"

        sclangPath = defaults.string(forKey: "sclangPath")
            ?? "/Applications/SuperCollider.app/Contents/MacOS/sclang"
        // Prefer boot.scd (single-block, auto-executable by sclang CLI) over
        // 00_load.scd which is split into ~32 IDE-only Cmd+Enter blocks.
        let bootCandidate    = "\(avLive)/sound_algo/boot.scd"
        let legacyCandidate  = "\(avLive)/sound_algo/00_load.scd"
        soundAlgoLoadFile = defaults.string(forKey: "soundAlgoLoadFile")
            ?? (fm.fileExists(atPath: bootCandidate) ? bootCandidate : legacyCandidate)

        // openFrameworks Release produces a .app bundle in bin/. Default to the
        // executable inside the bundle, with fallback to the bare binary if
        // the user built with a custom Makefile target.
        let bundled = "\(avLive)/oscope-of/bin/oscope-of.app/Contents/MacOS/oscope-of"
        let bare    = "\(avLive)/oscope-of/bin/oscope-of"
        let stored = defaults.string(forKey: "oscopePath")
        if let s = stored, !s.isEmpty {
            oscopePath = s
        } else if fm.fileExists(atPath: bundled) {
            oscopePath = bundled
        } else {
            oscopePath = bare
        }
        webServerScript = defaults.string(forKey: "webServerScript")
            ?? "\(avLive)/sound_algo/web/server.js"

        // Discover node : try /usr/local/bin (Intel Homebrew or stock pkg),
        // /opt/homebrew/bin (Apple Silicon Homebrew), then `which node`
        // resolved against an extended PATH.
        let nodeCandidates = ["/usr/local/bin/node", "/opt/homebrew/bin/node",
                              "/usr/bin/node"]
        nodePath = defaults.string(forKey: "nodePath")
            ?? (nodeCandidates.first(where: { fm.isExecutableFile(atPath: $0) })
                ?? "/usr/local/bin/node")

        webPort = (defaults.object(forKey: "webPort") as? Int) ?? 3000
        autoStart = (defaults.object(forKey: "autoStart") as? Bool) ?? true
        autoOpenBrowser = (defaults.object(forKey: "autoOpenBrowser") as? Bool) ?? true
    }

    /// Start everything that's currently stopped. Used by AppDelegate on
    /// launch when autoStart is enabled.
    func startAll() {
        if !sclangRunning { startSclang() }
        // Stagger so sclang has a head start booting scsynth before
        // oscope-of opens its OSC listener
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            if !self.oscopeRunning { self.startOscope() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            if !self.webRunning { self.startWeb() }
        }
        if autoOpenBrowser {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard let self = self else { return }
                if let url = URL(string: "http://localhost:\(self.webPort)/control/") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - web server

    func startWeb() {
        guard webProc == nil else { return }
        guard FileManager.default.isExecutableFile(atPath: nodePath) else {
            append(source: "launcher", text: "node not found at \(nodePath)")
            return
        }
        guard FileManager.default.fileExists(atPath: webServerScript) else {
            append(source: "launcher", text: "server.js not found at \(webServerScript)")
            return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: nodePath)
        p.arguments = [webServerScript]
        p.currentDirectoryURL = URL(fileURLWithPath: webServerScript)
            .deletingLastPathComponent()
        // node needs PATH to resolve helper subprocesses + npm dep binaries
        var env = ProcessInfo.processInfo.environment
        let extraPath = "/usr/local/bin:/opt/homebrew/bin"
        env["PATH"] = (env["PATH"] ?? "/usr/bin:/bin") + ":" + extraPath
        env["HTTP_PORT"] = String(webPort)
        p.environment = env
        attach(process: p, label: "web")
        do {
            try p.run()
            webProc = p
            DispatchQueue.main.async { self.webRunning = true }
            p.terminationHandler = { [weak self] proc in
                self?.append(source: "web", text: "exited with status \(proc.terminationStatus)")
                DispatchQueue.main.async {
                    self?.webProc = nil
                    self?.webRunning = false
                    if self?.webWantsRestart == true {
                        self?.webWantsRestart = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            self?.startWeb()
                        }
                    }
                }
            }
            append(source: "launcher", text: "started web server on :\(webPort)")
        } catch {
            append(source: "launcher", text: "failed to start web server: \(error)")
        }
    }

    func stopWeb() {
        webWantsRestart = false
        webProc?.terminate()
    }

    private var webWantsRestart = false

    func restartWeb() {
        guard webProc != nil else { startWeb(); return }
        append(source: "launcher", text: "restarting web server…")
        webWantsRestart = true
        webProc?.terminate()
        webWantsRestart = true
    }

    func openBrowser() {
        if let url = URL(string: "http://localhost:\(webPort)/control/") {
            NSWorkspace.shared.open(url)
        }
    }

    func openHydra() {
        if let url = URL(string: "http://localhost:\(webPort)/hydra/") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Album catalog (filesystem-derived)

    struct Album: Identifiable {
        let letter: String
        let slug: String        // e.g. "acid_journey"
        let displayTitle: String  // e.g. "Acid Journey"
        var id: String { letter }
    }

    /// Scans <avLive>/sound_algo/tracks/ for X_slug subdirectories and
    /// returns an Album entry per letter, sorted alphabetically.
    func discoverAlbums() -> [Album] {
        let fm = FileManager.default
        let tracksRoot = URL(fileURLWithPath: soundAlgoLoadFile)
            .deletingLastPathComponent()
            .appendingPathComponent("tracks", isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(
                atPath: tracksRoot.path) else {
            return []
        }
        var albums: [Album] = []
        for name in entries {
            // X_slug pattern with X = single uppercase letter
            guard name.count >= 3,
                  name[name.index(name.startIndex, offsetBy: 1)] == "_",
                  let first = name.first, first.isUppercase, first.isLetter else {
                continue
            }
            let dir = tracksRoot.appendingPathComponent(name).path
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            let letter = String(first)
            let slug = String(name.dropFirst(2))
            let title = slug.split(separator: "_")
                            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                            .joined(separator: " ")
            albums.append(Album(letter: letter, slug: slug, displayTitle: title))
        }
        return albums.sorted { $0.letter < $1.letter }
    }

    func playAlbum(_ letter: String, gap: Int = 8) {
        osc.send("/control/playAlbum", letter, gap)
    }

    func playTrack(_ letter: String, _ n: Int) {
        osc.send("/control/playTrack", letter, n)
    }

    func stopAlbum() {
        osc.send("/control/stopAlbum")
    }

    // MARK: - sclang

    func startSclang() {
        guard sclangProc == nil else { return }
        guard FileManager.default.fileExists(atPath: sclangPath) else {
            append(source: "launcher", text: "sclang not found at \(sclangPath)")
            return
        }
        guard FileManager.default.fileExists(atPath: soundAlgoLoadFile) else {
            append(source: "launcher", text: "load file not found at \(soundAlgoLoadFile)")
            return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: sclangPath)
        p.arguments = [soundAlgoLoadFile]
        // sclang resolves relative paths from the current working dir; cd to the load file's dir
        p.currentDirectoryURL = URL(fileURLWithPath: soundAlgoLoadFile).deletingLastPathComponent()
        attach(process: p, label: "sclang")
        do {
            try p.run()
            sclangProc = p
            DispatchQueue.main.async { self.sclangRunning = true }
            p.terminationHandler = { [weak self] proc in
                self?.append(source: "sclang", text: "exited with status \(proc.terminationStatus)")
                DispatchQueue.main.async {
                    self?.sclangProc = nil
                    self?.sclangRunning = false
                    self?.maybeRestartSclang()
                }
            }
            append(source: "launcher", text: "started sclang \(sclangPath) \(soundAlgoLoadFile)")
        } catch {
            append(source: "launcher", text: "failed to start sclang: \(error)")
        }
    }

    func stopSclang() {
        sclangWantsRestart = false
        sclangProc?.terminate()
        // sclang's terminate doesn't always tear scsynth down cleanly —
        // run a belt-and-braces pkill so the next boot can grab :57110.
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["-f", "scsynth"]
        try? kill.run()
    }

    /// Restart sclang : fire and forget. Sets the auto-restart flag,
    /// terminates the current process. terminationHandler observes the
    /// flag and re-spawns after scsynth is reaped.
    func restartSclang() {
        guard sclangProc != nil else { startSclang(); return }
        append(source: "launcher", text: "restarting sclang…")
        sclangWantsRestart = true
        stopSclang()
        // stopSclang resets the flag — re-set it because we want restart
        sclangWantsRestart = true
    }

    /// Watches both .av-live-restart-sclang and .av-live-restart-web
    /// sentinel files. Triggered by the bridge's reboot handlers.
    private var sentinelTimer: Timer?
    func startSentinelWatcher() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sclangSentinel = home.appendingPathComponent(".av-live-restart-sclang").path
        let webSentinel    = home.appendingPathComponent(".av-live-restart-web").path
        sentinelTimer?.invalidate()
        sentinelTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if FileManager.default.fileExists(atPath: sclangSentinel) {
                try? FileManager.default.removeItem(atPath: sclangSentinel)
                self?.append(source: "launcher", text: "sentinel detected — restarting sclang")
                self?.restartSclang()
            }
            if FileManager.default.fileExists(atPath: webSentinel) {
                try? FileManager.default.removeItem(atPath: webSentinel)
                self?.append(source: "launcher", text: "sentinel detected — restarting web")
                self?.restartWeb()
            }
        }
    }

    private func maybeRestartSclang() {
        guard sclangWantsRestart else { return }
        sclangWantsRestart = false
        // Small delay so scsynth pkill finishes and the audio device is free
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.startSclang()
        }
    }

    // MARK: - oscope-of

    func startOscope() {
        guard oscopeProc == nil else { return }
        guard FileManager.default.fileExists(atPath: oscopePath) else {
            append(source: "launcher", text: "oscope-of binary not found at \(oscopePath)")
            return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: oscopePath)
        p.currentDirectoryURL = oscopeProjectRoot(from: oscopePath)
        attach(process: p, label: "oscope")
        do {
            try p.run()
            oscopeProc = p
            DispatchQueue.main.async { self.oscopeRunning = true }
            p.terminationHandler = { [weak self] proc in
                self?.append(source: "oscope", text: "exited with status \(proc.terminationStatus)")
                DispatchQueue.main.async {
                    self?.oscopeProc = nil
                    self?.oscopeRunning = false
                }
            }
            append(source: "launcher", text: "started oscope-of \(oscopePath)")
        } catch {
            append(source: "launcher", text: "failed to start oscope-of: \(error)")
        }
    }

    func stopOscope() {
        oscopeProc?.terminate()
    }

    /// openFrameworks expects the working dir to be the project root (the
    /// directory containing `bin/`) so it can find `bin/data/`. The binary
    /// path can be either `<root>/bin/oscope-of` (bare) or
    /// `<root>/bin/oscope-of.app/Contents/MacOS/oscope-of` (release bundle) —
    /// walk up to the parent of `bin/` either way.
    private func oscopeProjectRoot(from binaryPath: String) -> URL {
        var url = URL(fileURLWithPath: binaryPath).deletingLastPathComponent()
        while url.path != "/" {
            if url.lastPathComponent == "bin" {
                return url.deletingLastPathComponent()
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: binaryPath).deletingLastPathComponent()
    }

    // MARK: - utilities

    func stopAll() {
        sclangProc?.terminate()
        oscopeProc?.terminate()
        webProc?.terminate()
    }

    func clearLogs() {
        DispatchQueue.main.async { self.logs.removeAll() }
    }

    private func attach(process: Process, label: String) {
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        attachReader(outPipe.fileHandleForReading, source: label)
        attachReader(errPipe.fileHandleForReading, source: label + "!")
    }

    private func attachReader(_ fh: FileHandle, source: String) {
        fh.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let str = String(data: data, encoding: .utf8) else { return }
            for raw in str.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(raw)
                if !line.isEmpty {
                    self?.append(source: source, text: line)
                }
            }
        }
    }

    private func append(source: String, text: String) {
        let entry = LogLine(source: source, text: text)
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogLines {
                self.logs.removeFirst(self.logs.count - self.maxLogLines)
            }
        }
    }
}
