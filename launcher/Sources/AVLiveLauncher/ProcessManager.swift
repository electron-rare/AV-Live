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

    private let defaults = UserDefaults.standard
    private var sclangProc: Process?
    private var oscopeProc: Process?
    private let logQueue = DispatchQueue(label: "cc.saillant.avlive.log")
    private let maxLogLines = 2000

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        sclangPath = defaults.string(forKey: "sclangPath")
            ?? "/Applications/SuperCollider.app/Contents/MacOS/sclang"
        soundAlgoLoadFile = defaults.string(forKey: "soundAlgoLoadFile")
            ?? "\(home)/Documents/Projets/AV-Live/sound_algo/00_load.scd"
        oscopePath = defaults.string(forKey: "oscopePath")
            ?? "\(home)/Documents/Projets/AV-Live/oscope-of/bin/oscope-of"
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
        p.currentDirectoryURL = URL(fileURLWithPath: oscopePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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
