import Foundation
import MnemoCore
import Darwin

extension SystemProcessLauncher {
    func engineBinaryPath() -> String? {
        let candidates = [
            NSHomeDirectory() + "/.supermemory/bin/supermemory-server",
            NSHomeDirectory() + "/.local/bin/supermemory-server",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? which("supermemory-server")
    }

    func which(_ name: String) -> String? {
        let paths = (environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
            + [NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        return paths.map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func logPath(_ name: String) -> String {
        let dir = NSHomeDirectory() + "/Library/Logs/Mnemo"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return "\(dir)/\(name).log"
    }

    func listeners(on port: Int) -> [ListeningSocket] {
        (try? checkedListeners(on: port)) ?? []
    }

    func checkedListeners(on port: Int) throws -> [ListeningSocket] {
        let out = try capture(
            "/usr/sbin/lsof",
            ["-iTCP:\(port)", "-sTCP:LISTEN", "-n", "-P"]
        )
        return LoopbackAudit.parseLSOF(out)
    }

    func processIdentity(_ pid: Int) throws -> ProcessIdentity {
        let textImages = try capture(
            "/usr/sbin/lsof",
            ["-a", "-p", String(pid), "-d", "txt", "-Fn"]
        )
        guard let executable = textImages.split(separator: "\n")
            .first(where: { $0.hasPrefix("n/") })
            .map({ String($0.dropFirst()) })
        else { throw LaunchError.commandFailed("inspect executable", -1) }
        let invocation = try processInvocation(pid)
        return ProcessIdentity(
            executablePath: executable,
            commandLine: invocation.arguments.joined(separator: " "),
            environmentDescription: invocation.environment.joined(separator: " "),
            arguments: invocation.arguments,
            environmentEntries: invocation.environment
        )
    }

    func processInvocation(_ pid: Int) throws -> (arguments: [String], environment: [String]) {
        var mib = [CTL_KERN, KERN_PROCARGS2, Int32(pid)]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0
        else { throw LaunchError.commandFailed("inspect process arguments", -1) }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0,
              size >= MemoryLayout<Int32>.size
        else { throw LaunchError.commandFailed("inspect process arguments", -1) }

        let argumentCount = buffer.withUnsafeBytes {
            Int($0.loadUnaligned(as: Int32.self))
        }
        var cursor = MemoryLayout<Int32>.size
        while cursor < size, buffer[cursor] != 0 { cursor += 1 }
        while cursor < size, buffer[cursor] == 0 { cursor += 1 }

        var values: [String] = []
        while cursor < size {
            let start = cursor
            while cursor < size, buffer[cursor] != 0 { cursor += 1 }
            if cursor > start,
               let value = String(bytes: buffer[start..<cursor], encoding: .utf8) {
                values.append(value)
            }
            cursor += 1
        }
        guard values.count >= argumentCount else {
            throw LaunchError.commandFailed("inspect process arguments", -1)
        }
        return (
            Array(values.prefix(argumentCount)),
            Array(values.dropFirst(argumentCount))
        )
    }

    func listenerDisposition(
        for process: ManagedProcess,
        on port: Int,
        expectedExecutable: String,
        requiredArguments: [String]? = nil,
        requireSandboxMarker: Bool? = nil
    ) throws -> ListenerDisposition {
        let sockets = listeners(on: port)
        var identities: [Int: ProcessIdentity] = [:]
        for pid in Set(sockets.map(\.pid)) {
            identities[pid] = try? processIdentity(pid)
        }
        return EngineLaunchPolicy.listenerDisposition(
            sockets,
            identities: identities,
            expectedExecutable: expectedExecutable,
            requiredArguments: requiredArguments ?? expectedArguments(for: process),
            requireSandboxMarker: requireSandboxMarker ?? (process != .smfs)
        )
    }

    func allListenersMatchExecutable(
        on port: Int,
        expectedExecutable: String,
        requiredArguments: [String]
    ) throws -> Bool {
        let sockets = listeners(on: port)
        guard !sockets.isEmpty else { return false }
        return try Set(sockets.map(\.pid)).allSatisfy { pid in
            let identity = try processIdentity(pid)
            return EngineLaunchPolicy.isManagedIdentity(
                identity,
                expectedExecutable: expectedExecutable,
                requiredArguments: requiredArguments,
                requireSandboxMarker: false
            )
        }
    }

    func brewServicePID(_ brew: String) -> Int? {
        guard let output = try? capture(
            brew,
            ["services", "info", "ollama", "--json"]
        ),
        let data = output.data(using: .utf8),
        let services = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
        let service = services.first,
        service["running"] as? Bool == true
        else { return nil }
        if let pid = service["pid"] as? Int { return pid }
        if let pid = service["pid"] as? NSNumber { return pid.intValue }
        return nil
    }

    func smfsMountOwnership(bin: String, mountPoint: String) -> SMFSMountOwnership? {
        guard let mountTable = try? capture("/sbin/mount", []),
              let daemonList = try? capture(bin, ["list"])
        else { return nil }
        return EngineLaunchPolicy.smfsMountOwnership(
            mountTable: mountTable,
            daemonList: daemonList,
            mountPoint: mountPoint
        )
    }

    func clearManagedListeners(
        _ process: ManagedProcess,
        on port: Int,
        expectedExecutable: String,
        requiredArguments: [String]? = nil,
        requireSandboxMarker: Bool? = nil
    ) async {
        let sockets = listeners(on: port)
        var identities: [Int: ProcessIdentity] = [:]
        for pid in Set(sockets.map(\.pid)) {
            identities[pid] = try? processIdentity(pid)
        }
        let managedPIDs = EngineLaunchPolicy.managedPIDs(
            among: sockets,
            identities: identities,
            expectedExecutable: expectedExecutable,
            requiredArguments: requiredArguments ?? expectedArguments(for: process),
            requireSandboxMarker: requireSandboxMarker ?? (process != .smfs)
        )
        await terminateManagedPIDs(managedPIDs, on: port)
    }

    func terminateManagedPIDs(_ pids: Set<Int>, on port: Int) async {
        for pid in pids { _ = try? run("/bin/kill", ["-TERM", String(pid)]) }
        for _ in 0..<30 {
            if listeners(on: port).allSatisfy({ !pids.contains($0.pid) }) { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        for pid in Set(listeners(on: port).map(\.pid)).intersection(pids) {
            _ = try? run("/bin/kill", ["-KILL", String(pid)])
        }
    }

    func waitForPortToClear(_ port: Int) async {
        for _ in 0..<30 {
            if listeners(on: port).isEmpty { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func requireVacantPort(_ port: Int, process: ManagedProcess) throws {
        let remaining = listeners(on: port)
        guard remaining.isEmpty else {
            throw LaunchError.portOccupied(process, port, Set(remaining.map(\.pid)).sorted())
        }
    }

    func launchEngine(_ binary: String) throws {
        try spawnDetached(
            "/usr/bin/sandbox-exec",
            ["-p", EngineLaunchPolicy.sandboxProfile, binary],
            logPath: logPath("engine"),
            environment: EngineLaunchPolicy.environment(config: config)
        )
    }

    func expectedArguments(for process: ManagedProcess) -> [String] {
        switch process {
        case .ollama: ["serve"]
        case .engine: []
        case .smfs:
            smfsRequiredArguments(
                mountPoint: (config.smfs.mountPoint as NSString).expandingTildeInPath
            )
        }
    }

    func smfsRequiredArguments(mountPoint: String) -> [String] {
        [
            "daemon-inner",
            "--container-tag", "mnemo",
            "--mount", mountPoint,
            "--api-url", config.smfs.backingStore.absoluteString,
            "--backend", "nfs",
        ]
    }

    @discardableResult
    func run(
        _ path: String,
        _ args: [String],
        environment: [String: String]? = nil
    ) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        if let environment { p.environment = environment }
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    func spawnDetached(
        _ path: String,
        _ args: [String],
        logPath: String,
        environment: [String: String]? = nil
    ) throws {
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let log = FileHandle(forWritingAtPath: logPath)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        if let environment { p.environment = environment }
        if let log { p.standardOutput = log; p.standardError = log }
        try p.run()
    }

    public func capture(_ path: String, _ args: [String]) throws -> String {
        let result = try captureResult(path, args)
        guard result.status == 0 else {
            throw LaunchError.commandFailed("\(path) \(args.joined(separator: " "))", result.status)
        }
        return result.output
    }

    func captureResult(_ path: String, _ args: [String]) throws -> (output: String, status: Int32) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        p.waitUntilExit()
        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return (output, p.terminationStatus)
    }
}
