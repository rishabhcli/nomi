import Foundation
import MnemoCore
import Darwin

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
            let port = config.model.runtimeBaseURL.port ?? 11434
            guard let bin = which("ollama") else { throw LaunchError.binaryNotFound("ollama") }
            var disposition = try listenerDisposition(
                for: .ollama,
                on: port,
                expectedExecutable: bin
            )
            if case let .occupied(sockets) = disposition,
               try allListenersMatchExecutable(
                   on: port,
                   expectedExecutable: bin,
                   requiredArguments: ["serve"]
               ),
               let brew = which("brew"),
               let servicePID = brewServicePID(brew),
               Set(sockets.map(\.pid)) == Set([servicePID]) {
                // A Homebrew-managed Ollama is the one intentional takeover:
                // stop the registered service, then re-inspect instead of
                // signaling whatever happened to own the port.
                _ = try? run(brew, ["services", "stop", "ollama"])
                await waitForPortToClear(port)
                disposition = try listenerDisposition(
                    for: .ollama,
                    on: port,
                    expectedExecutable: bin
                )
            }
            switch disposition {
            case .vacant:
                try spawnDetached(
                    "/usr/bin/sandbox-exec",
                    ["-p", EngineLaunchPolicy.sandboxProfile, bin, "serve"],
                    logPath: logPath("ollama"),
                    environment: EngineLaunchPolicy.ollamaEnvironment(config: config)
                )
            case .reusable:
                break
            case let .replaceableManaged(pids):
                await terminateManagedPIDs(pids, on: port)
                try requireVacantPort(port, process: .ollama)
                try spawnDetached(
                    "/usr/bin/sandbox-exec",
                    ["-p", EngineLaunchPolicy.sandboxProfile, bin, "serve"],
                    logPath: logPath("ollama"),
                    environment: EngineLaunchPolicy.ollamaEnvironment(config: config)
                )
            case let .occupied(sockets):
                throw LaunchError.portOccupied(.ollama, port, Set(sockets.map(\.pid)).sorted())
            }
            _ = try await ensureModelResident()
        case .engine:
            let port = config.engine.baseURL.port ?? 6767
            guard let bin = engineBinaryPath() else { throw LaunchError.binaryNotFound("supermemory-server") }
            switch try listenerDisposition(for: .engine, on: port, expectedExecutable: bin) {
            case .vacant:
                try launchEngine(bin)
            case .reusable:
                return
            case let .replaceableManaged(pids):
                await terminateManagedPIDs(pids, on: port)
                try requireVacantPort(port, process: .engine)
                try launchEngine(bin)
            case let .occupied(sockets):
                throw LaunchError.portOccupied(.engine, port, Set(sockets.map(\.pid)).sorted())
            }
        case .smfs:
            guard let bin = which("smfs") else { throw LaunchError.binaryNotFound("smfs") }
            let mountPoint = (config.smfs.mountPoint as NSString).expandingTildeInPath
            let port = 11111
            let mountIsLive = await boundAddress(.smfs) != nil
            if mountIsLive { return }
            try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
            let requiredArguments = smfsRequiredArguments(mountPoint: mountPoint)
            let disposition = try listenerDisposition(
                for: .smfs,
                on: port,
                expectedExecutable: bin,
                requiredArguments: requiredArguments,
                requireSandboxMarker: false
            )
            if case let .occupied(sockets) = disposition {
                throw LaunchError.portOccupied(.smfs, port, Set(sockets.map(\.pid)).sorted())
            }
            guard let mountOwnership = smfsMountOwnership(bin: bin, mountPoint: mountPoint)
            else { throw LaunchError.commandFailed("inspect SMFS mount ownership", -1) }
            if mountOwnership == .foreign {
                throw LaunchError.foreignMount(mountPoint)
            }
            if mountOwnership == .managed {
                let status = (try? run(bin, ["unmount", mountPoint])) ?? -1
                if status != 0 {
                    _ = try? run("/sbin/umount", ["-f", mountPoint])
                }
            }
            switch disposition {
            case .vacant:
                break
            case .reusable, .replaceableManaged:
                await clearManagedListeners(
                    .smfs,
                    on: port,
                    expectedExecutable: bin,
                    requiredArguments: requiredArguments,
                    requireSandboxMarker: false
                )
                try requireVacantPort(port, process: .smfs)
            case let .occupied(sockets):
                throw LaunchError.portOccupied(.smfs, port, Set(sockets.map(\.pid)).sorted())
            }
            let status = try run(
                bin,
                ["mount", "mnemo", "--path", mountPoint,
                 "--api-url", config.smfs.backingStore.absoluteString,
                 "--backend", "nfs"],
                environment: EngineLaunchPolicy.localProcessEnvironment()
            )
            guard status == 0 else { throw LaunchError.commandFailed("smfs mount", status) }
        }
    }

    public func terminate(_ p: ManagedProcess) async {
        switch p {
        case .ollama:
            if let bin = which("ollama") {
                await clearManagedListeners(
                    .ollama,
                    on: config.model.runtimeBaseURL.port ?? 11434,
                    expectedExecutable: bin
                )
            }
        case .engine:
            if let bin = engineBinaryPath() {
                await clearManagedListeners(
                    .engine,
                    on: config.engine.baseURL.port ?? 6767,
                    expectedExecutable: bin
                )
            }
        case .smfs:
            if let bin = which("smfs") {
                let mountPoint = (config.smfs.mountPoint as NSString).expandingTildeInPath
                let requiredArguments = smfsRequiredArguments(mountPoint: mountPoint)
                guard let disposition = try? listenerDisposition(
                    for: .smfs,
                    on: 11111,
                    expectedExecutable: bin,
                    requiredArguments: requiredArguments,
                    requireSandboxMarker: false
                ) else { return }
                if case .occupied = disposition { return }
                guard let mountOwnership = smfsMountOwnership(bin: bin, mountPoint: mountPoint),
                      mountOwnership != .foreign
                else { return }
                if mountOwnership == .managed {
                    let status = (try? run(bin, ["unmount", mountPoint])) ?? -1
                    if status != 0 { _ = try? run("/sbin/umount", ["-f", mountPoint]) }
                }
                await clearManagedListeners(
                    .smfs,
                    on: 11111,
                    expectedExecutable: bin,
                    requiredArguments: requiredArguments,
                    requireSandboxMarker: false
                )
            }
        }
    }

    public func boundAddress(_ p: ManagedProcess) async -> String? {
        switch p {
        case .ollama, .engine:
            let port = p == .ollama
                ? config.model.runtimeBaseURL.port ?? 11434
                : config.engine.baseURL.port ?? 6767
            let executable = p == .ollama ? which("ollama") : engineBinaryPath()
            guard let executable,
                  case let .reusable(socket) = try? listenerDisposition(
                      for: p,
                      on: port,
                      expectedExecutable: executable
                  )
            else { return nil }
            return socket.address
        case .smfs:
            // A mount-table entry alone can be a dead NFS mount. Require the
            // SMFS daemon registry and its loopback listener as well.
            let mountPoint = (config.smfs.mountPoint as NSString).expandingTildeInPath
            guard let bin = which("smfs"),
                  smfsMountOwnership(bin: bin, mountPoint: mountPoint) == .managed
            else { return nil }
            let listeners = (try? capture(
                "/usr/sbin/lsof",
                ["-iTCP:11111", "-sTCP:LISTEN", "-n", "-P"]
            )) ?? ""
            let sockets = LoopbackAudit.parseLSOF(listeners)
            guard !sockets.isEmpty,
                  sockets.allSatisfy({ LoopbackAudit.isLoopbackAddress($0.address) })
            else { return nil }
            for socket in sockets {
                guard let identity = try? processIdentity(socket.pid),
                      EngineLaunchPolicy.isManagedIdentity(
                          identity,
                          expectedExecutable: bin,
                          requiredArguments: smfsRequiredArguments(mountPoint: mountPoint),
                          requireSandboxMarker: false
                      )
                else { return nil }
            }
            return sockets[0].address
        }
    }

    /// Returns socket-table observations for the managed roots and their child
    /// processes. Callers can feed this into `StackEgressMonitor`; the result is
    /// process-wide observation, not syscall-level attempt interception.
    public func observedStackConnections() -> StackNetworkSnapshot {
        // Include the calling Mnemo process itself in addition to the three
        // managed service roots. URLProtocol blocks app HTTP egress; this also
        // observes raw sockets and child helpers that bypass URL loading.
        var roots: Set<Int> = [Int(getpid())]
        let specifications: [(ManagedProcess, Int, String?, Bool)] = [
            (.ollama, config.model.runtimeBaseURL.port ?? 11434, which("ollama"), true),
            (.engine, config.engine.baseURL.port ?? 6767, engineBinaryPath(), true),
            (.smfs, 11111, which("smfs"), false),
        ]
        for (process, port, executable, requireMarker) in specifications {
            guard let executable,
                  let sockets = try? checkedListeners(on: port),
                  !sockets.isEmpty
            else { return .unavailable(.managedProcessesNotFound) }
            var identities: [Int: ProcessIdentity] = [:]
            for pid in Set(sockets.map(\.pid)) {
                guard let identity = try? processIdentity(pid) else {
                    return .unavailable(.processInspectionFailed)
                }
                identities[pid] = identity
            }
            let managed = EngineLaunchPolicy.managedPIDs(
                among: sockets,
                identities: identities,
                expectedExecutable: executable,
                requiredArguments: expectedArguments(for: process),
                requireSandboxMarker: requireMarker
            )
            guard managed == Set(sockets.map(\.pid)) else {
                return .unavailable(.processInspectionFailed)
            }
            roots.formUnion(managed)
        }
        guard !roots.isEmpty else { return .unavailable(.managedProcessesNotFound) }
        guard let processList = try? capture("/bin/ps", ["-axo", "pid=,ppid="])
        else { return .unavailable(.processTreeInspectionFailed) }
        let pids = StackEgressAudit.processTreePIDs(roots: roots, processList: processList)
            .filter { kill(pid_t($0), 0) == 0 || errno == EPERM }
        let pidList = pids.sorted().map(String.init).joined(separator: ",")
        guard let socketResult = try? captureResult(
            "/usr/sbin/lsof",
            ["-n", "-P", "-a", "-p", pidList, "-i"]
        ) else { return .unavailable(.socketInspectionFailed) }
        let connections = StackEgressAudit.parseLSOF(socketResult.output)
        guard socketResult.status == 0 || !connections.isEmpty else {
            return .unavailable(.socketInspectionFailed)
        }
        return .observed(connections)
    }

    public func makeEgressMonitor() -> StackEgressMonitor {
        let launcher = self
        return StackEgressMonitor { launcher.observedStackConnections() }
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
        case commandFailed(String, Int32)
        case portOccupied(ManagedProcess, Int, [Int])
        case foreignMount(String)
    }
}
