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
    @Published private(set) var logs: [LogLine] = []

    // Persisted paths (UserDefaults, key/value)
    @Published var sclangPath: String { didSet { defaults.set(sclangPath, forKey: "sclangPath") } }
    @Published var soundAlgoLoadFile: String { didSet { defaults.set(soundAlgoLoadFile, forKey: "soundAlgoLoadFile") } }
    @Published var oscopePath: String { didSet { defaults.set(oscopePath, forKey: "oscopePath") } }
    @Published var autoStart: Bool { didSet { defaults.set(autoStart, forKey: "autoStart") } }

    private let defaults = UserDefaults.standard
    private var sclangProc: Process?
    private var oscopeProc: Process?
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
        soundAlgoLoadFile = defaults.string(forKey: "soundAlgoLoadFile")
            ?? "\(avLive)/sound_algo/00_load.scd"

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
        autoStart = (defaults.object(forKey: "autoStart") as? Bool) ?? true
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
                }
            }
            append(source: "launcher", text: "started sclang \(sclangPath) \(soundAlgoLoadFile)")
        } catch {
            append(source: "launcher", text: "failed to start sclang: \(error)")
        }
    }

    func stopSclang() {
        sclangProc?.terminate()
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
