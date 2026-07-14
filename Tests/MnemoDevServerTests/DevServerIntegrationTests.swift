import XCTest
import MnemoCore
@testable import MnemoDevServer

private actor AskRec {
    private(set) var queries: [String] = []
    func add(_ q: String) { queries.append(q) }
}

private final class IntegrationDataSource: DashboardDataSource, @unchecked Sendable {
    let trace = DevTrace()
    let rec = AskRec()
    func snapshot() async -> DashboardSnapshot {
        func ps(_ n: String, _ a: String) -> ProcessState { ProcessState(name: n, isRunning: true, boundAddress: a) }
        let h = StackHealth(ollama: ps("ollama", "127.0.0.1:11434"),
                            engine: ps("engine", "127.0.0.1:6767"),
                            smfs: ps("smfs", "127.0.0.1:11111"))
        return DashboardSnapshot(
            health: .init(h),
            egress: .init(EgressMetrics(blockedCount: 0, blockedHosts: [], loopbackOK: true)),
            invariant: .init(ok: true, detail: "loopback-only"),
            sla: .init(firstTokenMs: 1500, sourcesRenderMs: 1000),
            model: .init(id: "gpt-oss:20b"),
            history: [])
    }
    func ask(_ query: String) async { await rec.add(query) }
}

private struct TimeoutError: Error {}

final class DevServerIntegrationTests: XCTestCase {

    private func startOnEphemeralPort(_ ds: DashboardDataSource, token: String) async throws -> (DevServer, UInt16) {
        let server = DevServer(port: 0, dataSource: ds, pageHTML: "<html>__MNEMO_TOKEN__</html>", token: token)
        try server.start()
        for _ in 0..<100 {
            if let p = server.boundPort(), p != 0 { return (server, p) }
            try await Task.sleep(for: .milliseconds(30))
        }
        server.stop()
        throw XCTSkip("DevServer did not bind a loopback port in time")
    }

    private func withTimeout<T: Sendable>(_ seconds: Double, _ op: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask { try await Task.sleep(for: .seconds(seconds)); throw TimeoutError() }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func testStateEndpointReturnsSnapshotJSON() async throws {
        let ds = IntegrationDataSource()
        let (server, port) = try await startOnEphemeralPort(ds, token: "itok")
        defer { server.stop() }
        let url = URL(string: "http://127.0.0.1:\(port)/api/state?token=itok")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
        let snap = try JSONDecoder().decode(DashboardSnapshot.self, from: data)
        XCTAssertEqual(snap.model.id, "gpt-oss:20b")
        XCTAssertTrue(snap.health.allHealthyAndLoopback)
    }

    func testStateEndpointRejectsMissingToken() async throws {
        let ds = IntegrationDataSource()
        let (server, port) = try await startOnEphemeralPort(ds, token: "itok")
        defer { server.stop() }
        let url = URL(string: "http://127.0.0.1:\(port)/api/state")!
        let (_, resp) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 401)
    }

    func testEventsStreamsSnapshotThenLiveTrace() async throws {
        let ds = IntegrationDataSource()
        let (server, port) = try await startOnEphemeralPort(ds, token: "itok")
        defer { server.stop() }
        let url = URL(string: "http://127.0.0.1:\(port)/events?token=itok")!

        let reader = Task { () -> Set<String> in
            var kinds = Set<String>()
            let (bytes, _) = try await URLSession.shared.bytes(from: url)
            for try await line in bytes.lines {
                if line.hasPrefix("event:") { kinds.insert(line.trimmingCharacters(in: .whitespaces)) }
                if kinds.contains("event: trace") { break }
            }
            return kinds
        }
        // Let the SSE stream open + deliver the snapshot, then push a live event.
        try await Task.sleep(for: .milliseconds(400))
        await ds.trace.emit(TraceEvent(queryId: "q", seq: 1, atMs: 1, stage: "route", phase: "end"))

        let kinds = try await withTimeout(6) { try await reader.value }
        reader.cancel()
        XCTAssertTrue(kinds.contains("event: snapshot"), "expected snapshot event, saw \(kinds)")
        XCTAssertTrue(kinds.contains("event: trace"), "expected live trace event, saw \(kinds)")
    }
}
