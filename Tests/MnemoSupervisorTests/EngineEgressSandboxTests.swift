import XCTest
import Darwin
@testable import MnemoCore
@testable import MnemoSupervisor

final class EngineEgressSandboxTests: XCTestCase {
    func testEngineShutdownAllowsLargeLocalSnapshotToFlush() {
        XCTAssertEqual(EngineLaunchPolicy.engineShutdownGracePeriodMs, 60_000)
    }

    func testTerminationWaitsForOriginalProcessAfterListenerCloses() async throws {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "trap 'sleep 0.25; exit 0' TERM; printf ready; while :; do :; done",
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let ready = output.fileHandleForReading.readData(ofLength: 5)
        XCTAssertEqual(String(decoding: ready, as: UTF8.self), "ready")
        let pid = Int(process.processIdentifier)
        defer {
            if process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
        }
        let launcher = SystemProcessLauncher(
            config: try MnemoConfig.load(from: supervisorSampleConfig)
        )

        let startedAt = Date()
        await launcher.terminateManagedPIDs(
            [pid],
            on: 65_534,
            gracePeriodMs: 1_000
        )

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startedAt), 0.2)
        XCTAssertFalse(process.isRunning)
    }

    func testTerminationForceKillsOriginalProcessThatOutlivesGracePeriod() async throws {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "trap '' TERM; printf ready; while :; do :; done"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let ready = output.fileHandleForReading.readData(ofLength: 5)
        XCTAssertEqual(String(decoding: ready, as: UTF8.self), "ready")
        defer {
            if process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
        }
        let launcher = SystemProcessLauncher(
            config: try MnemoConfig.load(from: supervisorSampleConfig)
        )

        await launcher.terminateManagedPIDs(
            [Int(process.processIdentifier)],
            on: 65_534,
            gracePeriodMs: 100
        )

        XCTAssertFalse(process.isRunning)
    }

    func testDetachedSensitiveOutputIsRedactedAndOwnerOnly() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let logURL = root.appendingPathComponent("engine.log")
        try Data("stale output\n".utf8).write(to: logURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: logURL.path
        )

        let launcher = SystemProcessLauncher(
            config: try MnemoConfig.load(from: supervisorSampleConfig)
        )
        let fakeCredential = "sm_" + String(repeating: "x", count: 32)
        try launcher.spawnDetached(
            "/bin/sh",
            ["-c", "printf 'api key %s\\nready\\n' \"$FAKE_ENGINE_KEY\""],
            logPath: logURL.path,
            environment: ["FAKE_ENGINE_KEY": fakeCredential],
            redactSensitiveOutput: true
        )

        var contents = ""
        for _ in 0..<50 {
            contents = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            if contents.contains("ready") { break }
            Thread.sleep(forTimeInterval: 0.02)
        }

        XCTAssertTrue(contents.contains("api key [REDACTED]"))
        XCTAssertTrue(contents.contains("ready"))
        XCTAssertFalse(contents.contains(fakeCredential))
        XCTAssertFalse(contents.contains("stale output"))
        XCTAssertEqual(
            try FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? Int,
            0o700
        )
        XCTAssertEqual(
            try FileManager.default.attributesOfItem(atPath: logURL.path)[.posixPermissions] as? Int,
            0o600
        )
    }

    private func status(_ executable: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    func testProfileDeniesNonLoopbackNetworkAndAllowsLocalhost() {
        let profile = EngineLaunchPolicy.sandboxProfile

        XCTAssertTrue(profile.contains("(deny network-outbound)"))
        XCTAssertTrue(profile.contains("(deny network-inbound)"))
        XCTAssertTrue(profile.contains("(remote ip \"localhost:*\")"))
        XCTAssertTrue(profile.contains("(local ip \"localhost:*\")"))
        XCTAssertFalse(profile.contains("0.0.0.0"))

    }

    func testEnvironmentPinsLocalOllamaAndRemovesCloudProviders() throws {
        let config = try MnemoConfig.load(from: supervisorSampleConfig)
        let inherited = [
            "PATH": "/usr/bin",
            "MISTRAL_API_KEY": "must-not-survive",
            "GEMINI_API_KEY": "must-not-survive",
            "ANTHROPIC_API_KEY": "must-not-survive",
            "GOOGLE_APPLICATION_CREDENTIALS": "/tmp/cloud.json",
            "HTTPS_PROXY": "http://127.0.0.1:9999",
        ]

        let environment = EngineLaunchPolicy.environment(
            config: config,
            inherited: inherited,
            homeDirectory: "/Users/test"
        )

        XCTAssertEqual(environment["PATH"], "/usr/bin")
        XCTAssertEqual(environment["OPENAI_BASE_URL"], "http://127.0.0.1:11434/v1")
        XCTAssertEqual(environment["OPENAI_MODEL"], "gpt-oss:20b")
        XCTAssertEqual(environment["SUPERMEMORY_DATA_DIR"], "/Users/test/.supermemory/data")
        XCTAssertEqual(environment["SUPERMEMORY_DISABLE_TELEMETRY"], "1")
        XCTAssertEqual(environment["SUPERMEMORY_EMBEDDING_PROVIDER"], "local")
        XCTAssertEqual(environment["SUPERMEMORY_EMBEDDING_RAM_LIMIT"], "512mb")
        XCTAssertEqual(environment["SUPERMEMORY_INGEST_CONCURRENCY"], "1")
        XCTAssertEqual(environment["SUPERMEMORY_LOCAL_EMBEDDING_POOL_SIZE"], "1")
        XCTAssertEqual(environment["SUPERMEMORY_LOCAL_EMBEDDING_IDLE_TIMEOUT_MS"], "30000")
        XCTAssertEqual(environment["BUN_GARBAGE_COLLECTOR_LEVEL"], "1")
        XCTAssertEqual(environment["SUPERMEMORY_NO_UPDATE_CHECK"], "1")
        XCTAssertEqual(environment["SUPERMEMORY_RUN_CRONS_AT_BOOT"], "0")
        XCTAssertEqual(environment["PORT"], "6767")
        XCTAssertEqual(environment["SUPERMEMORY_PORT"], "6767")
        XCTAssertEqual(
            environment[EngineLaunchPolicy.markerKey],
            EngineLaunchPolicy.markerValue
        )
        XCTAssertNil(environment["MISTRAL_API_KEY"])
        XCTAssertNil(environment["GEMINI_API_KEY"])
        XCTAssertNil(environment["ANTHROPIC_API_KEY"])
        XCTAssertNil(environment["GOOGLE_APPLICATION_CREDENTIALS"])
        XCTAssertNil(environment["HTTPS_PROXY"], "a loopback proxy could tunnel around the sandbox")
    }

    func testListenerReuseRequiresMarkerLoopbackExecutableAndArguments() {
        let loopback = ListeningSocket(command: "supermemory", pid: 42, address: "127.0.0.1:6767")
        let wildcard = ListeningSocket(command: "supermemory", pid: 42, address: "*:6767")
        let expectedExecutable = "/usr/local/bin/supermemory-server"
        let marked = ProcessIdentity(
            executablePath: expectedExecutable,
            commandLine: "\(expectedExecutable) --local",
            environmentDescription: "\(EngineLaunchPolicy.markerKey)=\(EngineLaunchPolicy.markerValue)"
        )
        let spoofedExecutable = ProcessIdentity(
            executablePath: "/tmp/supermemory-server",
            commandLine: "\(expectedExecutable) --local",
            environmentDescription: marked.environmentDescription
        )

        XCTAssertTrue(EngineLaunchPolicy.canReuse(
            loopback,
            identity: marked,
            expectedExecutable: expectedExecutable,
            requiredArguments: ["--local"]
        ))
        XCTAssertFalse(EngineLaunchPolicy.canReuse(
            loopback,
            identity: ProcessIdentity(
                executablePath: expectedExecutable,
                commandLine: marked.commandLine,
                environmentDescription: "NOT_\(EngineLaunchPolicy.markerKey)=\(EngineLaunchPolicy.markerValue)"
            ),
            expectedExecutable: expectedExecutable,
            requiredArguments: ["--local"]
        ))
        XCTAssertFalse(EngineLaunchPolicy.canReuse(
            loopback,
            identity: spoofedExecutable,
            expectedExecutable: expectedExecutable,
            requiredArguments: ["--local"]
        ))
        XCTAssertFalse(EngineLaunchPolicy.canReuse(
            loopback,
            identity: marked,
            expectedExecutable: expectedExecutable,
            requiredArguments: ["--missing"]
        ))
        XCTAssertFalse(EngineLaunchPolicy.canReuse(
            wildcard,
            identity: marked,
            expectedExecutable: expectedExecutable,
            requiredArguments: ["--local"]
        ))
    }

    func testForeignListenerMakesWholePortOccupiedAndNeverReplaceable() {
        let expectedExecutable = "/usr/local/bin/supermemory-server"
        let managed = ListeningSocket(command: "supermemory", pid: 42, address: "127.0.0.1:6767")
        let foreign = ListeningSocket(command: "python", pid: 99, address: "127.0.0.1:6767")
        let marker = "\(EngineLaunchPolicy.markerKey)=\(EngineLaunchPolicy.markerValue)"
        let identities = [
            42: ProcessIdentity(
                executablePath: expectedExecutable,
                commandLine: expectedExecutable,
                environmentDescription: marker
            ),
            99: ProcessIdentity(
                executablePath: "/usr/bin/python3",
                commandLine: "python3 -m http.server 6767",
                environmentDescription: marker
            ),
        ]

        XCTAssertEqual(
            EngineLaunchPolicy.listenerDisposition(
                [managed, foreign],
                identities: identities,
                expectedExecutable: expectedExecutable
            ),
            .occupied([managed, foreign])
        )
        XCTAssertEqual(
            EngineLaunchPolicy.managedPIDs(
                among: [managed, foreign],
                identities: identities,
                expectedExecutable: expectedExecutable
            ),
            [42],
            "termination candidates must never include the foreign PID"
        )
    }

    func testAllListenersMustPassLoopbackAndIdentityChecks() {
        let expectedExecutable = "/usr/local/bin/supermemory-server"
        let loopback = ListeningSocket(command: "supermemory", pid: 42, address: "127.0.0.1:6767")
        let wildcard = ListeningSocket(command: "supermemory", pid: 42, address: "*:6767")
        let identity = ProcessIdentity(
            executablePath: expectedExecutable,
            commandLine: expectedExecutable,
            environmentDescription: "\(EngineLaunchPolicy.markerKey)=\(EngineLaunchPolicy.markerValue)"
        )

        XCTAssertEqual(
            EngineLaunchPolicy.listenerDisposition(
                [loopback, wildcard],
                identities: [42: identity],
                expectedExecutable: expectedExecutable
            ),
            .replaceableManaged(pids: [42])
        )
    }

    func testSMFSIdentityRejectsDuplicateBackingStoreOverride() {
        let executable = "/usr/local/bin/smfs"
        let identity = ProcessIdentity(
            executablePath: executable,
            commandLine: "",
            environmentDescription: "",
            arguments: [
                executable, "daemon-inner",
                "--api-url", "http://127.0.0.1:6767",
                "--api-url=https://api.supermemory.ai",
                "--backend", "nfs",
            ]
        )

        XCTAssertFalse(EngineLaunchPolicy.isManagedIdentity(
            identity,
            expectedExecutable: executable,
            requiredArguments: [
                "daemon-inner",
                "--api-url", "http://127.0.0.1:6767",
                "--backend", "nfs",
            ],
            requireSandboxMarker: false
        ))
    }

    func testSMFSIdentityAcceptsSingleEqualsStyleBackingStore() {
        let executable = "/usr/local/bin/smfs"
        let identity = ProcessIdentity(
            executablePath: executable,
            commandLine: "",
            environmentDescription: "",
            arguments: [
                executable, "daemon-inner",
                "--api-url=http://127.0.0.1:6767",
                "--backend=nfs",
            ]
        )

        XCTAssertTrue(EngineLaunchPolicy.isManagedIdentity(
            identity,
            expectedExecutable: executable,
            requiredArguments: [
                "daemon-inner",
                "--api-url", "http://127.0.0.1:6767",
                "--backend", "nfs",
            ],
            requireSandboxMarker: false
        ))
    }

    func testSMFSMountOwnershipRequiresLoopbackSourceAndRegistryEntry() {
        let mountPoint = "/Users/test/Mnemo/memory"
        let managedMount = "127.0.0.1:/ on \(mountPoint) (nfs, nodev, nosuid)"
        let registry = "mnemo 123 1m 0 \(mountPoint)"

        XCTAssertEqual(
            EngineLaunchPolicy.smfsMountOwnership(
                mountTable: managedMount,
                daemonList: registry,
                mountPoint: mountPoint
            ),
            .managed
        )
        XCTAssertEqual(
            EngineLaunchPolicy.smfsMountOwnership(
                mountTable: "/dev/disk9s1 on \(mountPoint) (apfs)",
                daemonList: registry,
                mountPoint: mountPoint
            ),
            .foreign
        )
        XCTAssertEqual(
            EngineLaunchPolicy.smfsMountOwnership(
                mountTable: managedMount,
                daemonList: "",
                mountPoint: mountPoint
            ),
            .foreign
        )
        XCTAssertEqual(
            EngineLaunchPolicy.smfsMountOwnership(
                mountTable: "",
                daemonList: "",
                mountPoint: mountPoint
            ),
            .absent
        )
    }

    func testOllamaEnvironmentPinsLoopbackAndDisablesCloud() throws {
        let config = try MnemoConfig.load(from: supervisorSampleConfig)
        let environment = EngineLaunchPolicy.ollamaEnvironment(
            config: config,
            inherited: ["PATH": "/usr/bin", "HTTP_PROXY": "http://127.0.0.1:9999"]
        )

        XCTAssertEqual(environment["OLLAMA_HOST"], "127.0.0.1:11434")
        XCTAssertEqual(environment["OLLAMA_NO_CLOUD"], "1")
        XCTAssertNil(environment["HTTP_PROXY"])
    }

    func testLiveChildProcessCannotOpenReachableExternalSocket() throws {
        let netcat = "/usr/bin/nc"
        guard FileManager.default.isExecutableFile(atPath: netcat) else {
            throw XCTSkip("netcat is unavailable")
        }
        guard try status(netcat, ["-z", "-w", "2", "1.1.1.1", "443"]) == 0 else {
            throw XCTSkip("external control socket is unreachable on this runner")
        }

        let blocked = try status(
            "/usr/bin/sandbox-exec",
            ["-p", EngineLaunchPolicy.sandboxProfile,
             netcat, "-z", "-w", "2", "1.1.1.1", "443"]
        )
        XCTAssertNotEqual(blocked, 0, "the sandbox must reject a socket the host can otherwise reach")
    }

    func testEgressAuditFlagsOnlyObservedNonLoopbackRemoteConnections() {
        let fixture = """
        COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        smfs      701 user   12u  IPv4  0x1      0t0  TCP 127.0.0.1:53390->127.0.0.1:6767 (ESTABLISHED)
        smfs      701 user   13u  IPv4  0x2      0t0  TCP 192.168.1.5:53391->1.1.1.1:443 (SYN_SENT)
        ollama    702 user   14u  IPv6  0x3      0t0  TCP [::1]:11434 (LISTEN)
        """

        let observed = StackEgressAudit.parseLSOF(fixture)
        XCTAssertEqual(observed.count, 2)
        XCTAssertEqual(StackEgressAudit.nonLoopback(observed).map(\.remoteAddress), ["1.1.1.1:443"])
    }

    func testEgressAuditIncludesNestedManagedChildren() {
        let processList = """
          10   1
          11  10
          12  11
          20   1
        """

        XCTAssertEqual(
            StackEgressAudit.processTreePIDs(roots: [10], processList: processList),
            [10, 11, 12]
        )
    }

    func testEgressMonitorCountsObservedConnectionLifetimesWithoutDoubleCountingSnapshots() async {
        actor Snapshots {
            var values: [StackNetworkSnapshot]
            init(_ values: [StackNetworkSnapshot]) { self.values = values }
            func next() -> StackNetworkSnapshot {
                guard !values.isEmpty else { return .observed([]) }
                return values.removeFirst()
            }
        }
        let external = ObservedNetworkConnection(
            command: "smfs",
            pid: 701,
            localAddress: "192.168.1.5:53391",
            remoteAddress: "1.1.1.1:443",
            state: "ESTABLISHED"
        )
        let connecting = ObservedNetworkConnection(
            command: external.command,
            pid: external.pid,
            localAddress: external.localAddress,
            remoteAddress: external.remoteAddress,
            state: "SYN_SENT"
        )
        let snapshots = Snapshots([
            .observed([external]),
            .observed([connecting]),
            .observed([]),
            .observed([external]),
            .unavailable(.socketInspectionFailed),
            .unavailable(.socketInspectionFailed),
        ])
        let monitor = StackEgressMonitor { await snapshots.next() }

        await monitor.sample()
        await monitor.sample()
        let firstCount = monitor.observedNonLoopbackConnections
        XCTAssertEqual(firstCount, 1)
        await monitor.sample()
        await monitor.sample()
        let secondCount = monitor.observedNonLoopbackConnections
        XCTAssertEqual(secondCount, 2)
        await monitor.sample()
        XCTAssertFalse(monitor.auditAvailable)
        XCTAssertEqual(monitor.auditFailureCount, 1)
        XCTAssertEqual(monitor.privacyViolationCount, 3)
        await monitor.sample()
        XCTAssertEqual(monitor.auditFailureCount, 2)
        XCTAssertEqual(monitor.privacyViolationCount, 4)
    }

    func testLiveManagedStackHasNoObservedNonLoopbackSocket() throws {
        let config = try MnemoConfig.load(from: supervisorSampleConfig)
        let snapshot = SystemProcessLauncher(config: config).observedStackConnections()
        if case let .unavailable(failure) = snapshot {
            if failure == .managedProcessesNotFound {
                throw XCTSkip("the local Mnemo stack is not running")
            }
            XCTFail("live stack audit unavailable: \(failure)")
            return
        }
        guard case let .observed(observed) = snapshot, !observed.isEmpty else {
            throw XCTSkip("the local Mnemo stack is not running")
        }

        XCTAssertTrue(
            StackEgressAudit.nonLoopback(observed).isEmpty,
            "managed roots and descendants must expose only loopback sockets"
        )
    }
}
