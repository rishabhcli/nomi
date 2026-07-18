import XCTest
@testable import MnemoSupervisor
@testable import MnemoCore

let supervisorSampleConfig = """
[engine]
base_url = "http://127.0.0.1:6767"
byom = "ollama"
embeddings = "local"
timeout_ms = 30
[model]
runtime_base_url = "http://127.0.0.1:11434"
synthesis = "gpt-oss:20b"
fallback = "qwen3:4b"
keep_alive = "30m"
[smfs]
mount_point = "~/Mnemo/memory"
backing_store = "http://127.0.0.1:6767"
[sync]
poll_seconds = 30
[retrieval]
default_mode = "memories"
rerank = true
threshold = 0.35
limit = 12
"""

actor FakeLauncher: ProcessLauncher {
    var launched: [ManagedProcess] = []
    var terminated: [ManagedProcess] = []
    func launch(_ p: ManagedProcess) async throws { launched.append(p) }
    func terminate(_ p: ManagedProcess) async { terminated.append(p) }
    func boundAddress(_ p: ManagedProcess) async -> String? {
        switch p {
        case .ollama: "127.0.0.1:11434"
        case .engine: "127.0.0.1:6767"
        case .smfs: "127.0.0.1:2049"
        }
    }
}
struct AlwaysUp: HealthProbe { func isUp(_ url: URL) async -> Bool { true } }

actor DelayedUp: HealthProbe {
    var failuresRemaining: Int
    init(failures: Int) { failuresRemaining = failures }
    func isUp(_ url: URL) async -> Bool {
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            return false
        }
        return true
    }
}

actor MissingSMFSMountLauncher: ProcessLauncher {
    func launch(_ p: ManagedProcess) async throws {}
    func terminate(_ p: ManagedProcess) async {}
    func boundAddress(_ p: ManagedProcess) async -> String? {
        switch p {
        case .ollama: "127.0.0.1:11434"
        case .engine: "127.0.0.1:6767"
        case .smfs: nil
        }
    }
}

actor PersistenceFailureLauncher: ProcessLauncher {
    func launch(_ p: ManagedProcess) async throws {}
    func terminate(_ p: ManagedProcess) async {}
    func boundAddress(_ p: ManagedProcess) async -> String? {
        switch p {
        case .ollama: "127.0.0.1:11434"
        case .engine: "127.0.0.1:6767"
        case .smfs: "127.0.0.1:11111"
        }
    }
    func additionalUnhealthyReasons() async -> [String] {
        ["engine persistence snapshot failed"]
    }
}

final class ProcessSupervisorTests: XCTestCase {
    func testStartsInDependencyOrder() async throws {
        let launcher = FakeLauncher()
        let sup = ProcessSupervisor(config: try MnemoConfig.load(from: supervisorSampleConfig), launcher: launcher, probe: AlwaysUp())
        try await sup.startAll()
        let order = await launcher.launched
        XCTAssertEqual(order, [.ollama, .engine, .smfs])
    }
    func testHealthAllLoopback() async throws {
        let sup = ProcessSupervisor(config: try MnemoConfig.load(from: supervisorSampleConfig), launcher: FakeLauncher(), probe: AlwaysUp())
        try await sup.startAll()
        let h = await sup.health()
        XCTAssertTrue(h.allHealthyAndLoopback)
    }

    func testPersistenceFailureCannotBeMaskedByHealthyHTTP() async throws {
        let sup = ProcessSupervisor(
            config: try MnemoConfig.load(from: supervisorSampleConfig),
            launcher: PersistenceFailureLauncher(),
            probe: AlwaysUp()
        )

        let health = await sup.health()

        XCTAssertFalse(health.allHealthyAndLoopback)
        XCTAssertEqual(health.unhealthyReasons, ["engine persistence snapshot failed"])
    }
    func testRestartRelaunchesProcess() async throws {
        let launcher = FakeLauncher()
        let sup = ProcessSupervisor(config: try MnemoConfig.load(from: supervisorSampleConfig), launcher: launcher, probe: AlwaysUp())
        try await sup.startAll()
        try await sup.restart(.engine)
        let terminated = await launcher.terminated
        let launched = await launcher.launched
        XCTAssertEqual(terminated, [.engine])
        XCTAssertEqual(launched, [.ollama, .engine, .smfs, .engine])
    }

    func testRestartHonorsBackoffConfig() async throws {
        let text = supervisorSampleConfig + "\n[supervisor]\nrestart_backoff = 500\n"
        let cfg = try MnemoConfig.load(from: text)
        XCTAssertEqual(cfg.supervisor.restartBackoffMs, 500)
    }

    func testStartupUsesConfiguredTimeoutInsteadOfFiveSecondRace() async throws {
        let text = supervisorSampleConfig + "\n[health]\nprobe_interval = 1\n"
        let sup = ProcessSupervisor(
            config: try MnemoConfig.load(from: text),
            launcher: FakeLauncher(),
            probe: DelayedUp(failures: 20)
        )

        try await sup.startAll()
    }

    func testHealthyEngineDoesNotMaskMissingSMFSMount() async throws {
        let text = supervisorSampleConfig + "\n[health]\nprobe_interval = 1\n"
        let sup = ProcessSupervisor(
            config: try MnemoConfig.load(from: text),
            launcher: MissingSMFSMountLauncher(),
            probe: AlwaysUp()
        )

        do {
            try await sup.startAll()
            XCTFail("startAll must fail when the SMFS mount never becomes live")
        } catch let error as SupervisorError {
            XCTAssertEqual(error, .failedToStart(.smfs))
        }
    }
}
