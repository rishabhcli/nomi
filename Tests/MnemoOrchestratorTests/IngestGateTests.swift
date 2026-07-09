import XCTest
@testable import MnemoOrchestrator

final class IngestGateTests: XCTestCase {
    actor Counter { var n = 0; func next() -> Int { n += 1; return n } }
    struct EventuallyReady: Retrieving {
        let counter: IngestGateTests.Counter
        let hit: Retrieved
        func search(_ req: SearchRequest) async throws -> [Retrieved] {
            (await counter.next()) >= 3 ? [hit] : []   // empty twice, then ready
        }
    }
    func testWaitsUntilSearchable() async {
        let hit = Retrieved(memory: "x", similarity: 0.9, source: .init(docId: "d", path: "/p", title: "t", charStart: 0, charEnd: 1))
        let gate = IngestGate(retriever: EventuallyReady(counter: Counter(), hit: hit))
        let ok = await gate.waitUntilSearchable(probe: "x", timeout: .seconds(5))
        XCTAssertTrue(ok)
    }
    func testTimesOutWhenNeverReady() async {
        struct NeverReady: Retrieving { func search(_ r: SearchRequest) async throws -> [Retrieved] { [] } }
        let gate = IngestGate(retriever: NeverReady())
        let ok = await gate.waitUntilSearchable(probe: "x", timeout: .milliseconds(400))
        XCTAssertFalse(ok)
    }
}
