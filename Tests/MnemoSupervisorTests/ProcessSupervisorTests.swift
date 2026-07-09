import XCTest
@testable import MnemoSupervisor
@testable import MnemoCore

let supervisorSampleConfig = """
[engine]
base_url = "http://127.0.0.1:6767"
byom = "ollama"
embeddings = "local"
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
}
