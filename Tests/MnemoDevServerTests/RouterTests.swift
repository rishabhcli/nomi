import XCTest
import MnemoCore
@testable import MnemoDevServer

private actor AskRecorder {
    private(set) var queries: [String] = []
    func add(_ q: String) { queries.append(q) }
}

private final class FakeDataSource: DashboardDataSource, @unchecked Sendable {
    let trace = DevTrace()
    let recorder = AskRecorder()
    let snap: DashboardSnapshot
    init(_ snap: DashboardSnapshot) { self.snap = snap }
    func snapshot() async -> DashboardSnapshot { snap }
    func ask(_ query: String) async { await recorder.add(query) }
}

private func sampleSnapshot() -> DashboardSnapshot {
    func ps(_ n: String, _ a: String) -> ProcessState { ProcessState(name: n, isRunning: true, boundAddress: a) }
    let health = StackHealth(ollama: ps("ollama", "127.0.0.1:11434"),
                             engine: ps("engine", "127.0.0.1:6767"),
                             smfs: ps("smfs", "127.0.0.1:11111"))
    return DashboardSnapshot(
        health: .init(health),
        egress: .init(EgressMetrics(blockedCount: 0, blockedHosts: [], loopbackOK: true)),
        invariant: .init(ok: true, detail: "loopback-only"),
        sla: .init(firstTokenMs: 1500, sourcesRenderMs: 1000),
        model: .init(id: "gpt-oss:20b"),
        history: [])
}

final class RouterTests: XCTestCase {
    private let token = "tok123"
    private func req(_ raw: String) -> HTTPRequest { HTTPRequest.parse(Data(raw.utf8))! }

    private func makeRouter(_ ds: FakeDataSource) -> Router {
        Router(token: token, dataSource: ds, page: "<html>DASH __MNEMO_TOKEN__</html>")
    }

    func testUnauthorizedWithoutToken() async {
        let r = makeRouter(FakeDataSource(sampleSnapshot()))
        let outcome = await r.handle(req("GET /api/state HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"))
        guard case .unauthorized = outcome else { return XCTFail("expected unauthorized, got \(outcome)") }
    }

    func testStateReturnsSnapshotJSON() async throws {
        let r = makeRouter(FakeDataSource(sampleSnapshot()))
        let outcome = await r.handle(req("GET /api/state?token=tok123 HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"))
        guard case let .respond(resp) = outcome else { return XCTFail("expected respond") }
        XCTAssertEqual(resp.status, 200)
        let snap = try JSONDecoder().decode(DashboardSnapshot.self, from: resp.body)
        XCTAssertEqual(snap.model.id, "gpt-oss:20b")
        XCTAssertTrue(snap.health.allHealthyAndLoopback)
        XCTAssertEqual(snap.egress.blockedCount, 0)
    }

    func testAskDrivesDataSourceAndReturns202() async {
        let ds = FakeDataSource(sampleSnapshot())
        let r = makeRouter(ds)
        let outcome = await r.handle(req("POST /api/ask HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Mnemo-Token: tok123\r\nContent-Length: 18\r\n\r\n{\"query\":\"where?\"}"))
        guard case let .respond(resp) = outcome else { return XCTFail("expected respond") }
        XCTAssertEqual(resp.status, 202)
        let asked = await ds.recorder.queries
        XCTAssertEqual(asked, ["where?"])
    }

    func testEventsReturnsSSE() async {
        let r = makeRouter(FakeDataSource(sampleSnapshot()))
        let outcome = await r.handle(req("GET /events?token=tok123 HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"))
        guard case .sse = outcome else { return XCTFail("expected sse") }
    }

    func testRootServesPage() async {
        let r = makeRouter(FakeDataSource(sampleSnapshot()))
        let outcome = await r.handle(req("GET /?token=tok123 HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"))
        guard case let .respond(resp) = outcome else { return XCTFail("expected respond") }
        XCTAssertTrue(String(data: resp.body, encoding: .utf8)!.contains("DASH"))
    }

    func testUnknownRouteIs404() async {
        let r = makeRouter(FakeDataSource(sampleSnapshot()))
        let outcome = await r.handle(req("GET /nope?token=tok123 HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"))
        guard case let .respond(resp) = outcome else { return XCTFail("expected respond") }
        XCTAssertEqual(resp.status, 404)
    }
}
