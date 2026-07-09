import Foundation
import MnemoCore

/// Launches and terminates the real stack processes.
///
/// - Ollama runs as a launchd/brew service; `launch(.ollama)` verifies the model
///   is present locally (never silently downloads at query time) and warms it.
/// - The engine is the supermemory-server binary bound to loopback with BYOM=Ollama.
/// - SMFS mounts the memory-path with backing store = the local engine.
public struct SystemProcessLauncher: ProcessLauncher {
    let config: MnemoConfig
    let environment: [String: String]

    public init(config: MnemoConfig, environment: [String: String] = [:]) {
        self.config = config
        self.environment = environment
    }

    public func launch(_ p: ManagedProcess) async throws {
        switch p {
        case .ollama:
            // Managed externally (launchd / brew services). If it is not up yet, start it.
            if await boundAddress(.ollama) == nil {
                try run("/usr/bin/env", ["brew", "services", "start", "ollama"])
            }
            _ = try await ensureModelResident()
        case .engine:
            if await boundAddress(.engine) != nil { return }   // already serving
            guard let bin = engineBinaryPath() else { throw LaunchError.binaryNotFound("supermemory-server") }
            try spawnDetached(bin, [], logPath: logPath("engine"))
        case .smfs:
            if await boundAddress(.smfs) != nil { return }     // already mounted
            guard let bin = which("smfs") else { throw LaunchError.binaryNotFound("smfs") }
            let mountPoint = (config.smfs.mountPoint as NSString).expandingTildeInPath
            try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
            try run(bin, ["mount", "mnemo", "--path", mountPoint,
                          "--api-url", config.smfs.backingStore.absoluteString,
                          "--backend", "nfs"])
        }
    }

    public func terminate(_ p: ManagedProcess) async {
        switch p {
        case .ollama:
            _ = try? run("/usr/bin/env", ["brew", "services", "stop", "ollama"])
        case .engine:
            _ = try? run("/usr/bin/pkill", ["-f", "supermemory-server"])
        case .smfs:
            if let bin = which("smfs") { _ = try? run(bin, ["unmount", "mnemo"]) }
        }
    }

    public func boundAddress(_ p: ManagedProcess) async -> String? {
        switch p {
        case .ollama, .engine:
            let port = p == .ollama
                ? String(config.model.runtimeBaseURL.port ?? 11434)
                : String(config.engine.baseURL.port ?? 6767)
            let out = (try? capture("/usr/sbin/lsof", ["-iTCP:\(port)", "-sTCP:LISTEN", "-n", "-P"])) ?? ""
            return LoopbackAudit.parseLSOF(out).first?.address
        case .smfs:
            // A live NFS mount at the memory-path is the "address" for smfs.
            let mountPoint = (config.smfs.mountPoint as NSString).expandingTildeInPath
            let out = (try? capture("/sbin/mount", [])) ?? ""
            return out.contains(mountPoint) ? "127.0.0.1:nfs" : nil
        }
    }

    // MARK: - model residency (M0 Task 2: warm model, fail loudly if missing)

    /// Confirms the configured model (or its floor-tier fallback) is pulled,
    /// then issues a bounded warm-up generation so the weights are resident.
    /// Throws `modelNotLoaded` rather than silently downloading at query time.
    public func ensureModelResident() async throws -> String {
        let base = config.model.runtimeBaseURL
        for _ in 0..<40 {   // wait for the server socket before asking for tags
            if await boundAddress(.ollama) != nil { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        let (tagsData, _) = try await URLSession.shared.data(from: base.appending(path: "/api/tags"))
        let available = try OllamaTags.models(in: tagsData)
        guard let model = [config.model.synthesis, config.model.fallback].first(where: available.contains) else {
            throw LaunchError.modelNotLoaded(config.model.synthesis)
        }
        var req = URLRequest(url: base.appending(path: "/api/generate"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try OllamaWarmup.requestBody(model: model, keepAlive: config.model.keepAlive)
        req.timeoutInterval = 300   // first load streams weights from disk
        _ = try await URLSession.shared.data(for: req)
        return model
    }

    // MARK: - process helpers

    public enum LaunchError: Error, Equatable {
        case binaryNotFound(String)
        case modelNotLoaded(String)
    }

    func engineBinaryPath() -> String? {
        let candidates = [
            NSHomeDirectory() + "/.local/bin/supermemory-server",
            NSHomeDirectory() + "/.supermemory/bin/supermemory-server",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? which("supermemory-server")
    }

    func which(_ name: String) -> String? {
        let paths = (environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
            + [NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        return paths.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func logPath(_ name: String) -> String {
        let dir = NSHomeDirectory() + "/Library/Logs/Mnemo"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return "\(dir)/\(name).log"
    }

    @discardableResult
    func run(_ path: String, _ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    /// Spawn a long-running process detached from this one, logging to a file.
    func spawnDetached(_ path: String, _ args: [String], logPath: String) throws {
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let log = FileHandle(forWritingAtPath: logPath)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        if let log { p.standardOutput = log; p.standardError = log }
        try p.run()
    }

    public func capture(_ path: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
