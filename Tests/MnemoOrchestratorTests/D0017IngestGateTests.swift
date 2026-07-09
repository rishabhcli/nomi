import XCTest
@testable import MnemoOrchestrator

/// D-0017: IngestGate AsyncStream cancellation (seed 402ba36fd5c9).
final class D0017IngestGateTests: XCTestCase {
    private let seed = "402ba36fd5c9"

    actor SlowCounter { var n = 0; func bump() -> Int { n += 1; return n } }

    struct SlowReady: Retrieving {
        let counter: SlowCounter
        func search(_ req: SearchRequest) async throws -> [Retrieved] {
            _ = await counter.bump()
            try await Task.sleep(for: .milliseconds(100))
            return await counter.bump() >= 3
                ? [Retrieved(memory: "ready", similarity: 0.9,
                             source: SourceLocator(docId: "d", path: "/p", title: "t"))]
                : []
        }
    }

    func testWaitUntilSearchableHonoursCancellation() async {
        let gate = IngestGate(retriever: SlowReady(counter: SlowCounter()))
        let task = Task { await gate.waitUntilSearchable(probe: "x", timeout: .seconds(10)) }
        try? await Task.sleep(for: .milliseconds(150))
        task.cancel()
        let ok = await task.value
        XCTAssertFalse(ok)
    }

    func testSearchableStreamTerminates() async {
        struct Instant: Retrieving {
            func search(_ req: SearchRequest) async throws -> [Retrieved] {
                [Retrieved(memory: "x", similarity: 0.9, source: SourceLocator(docId: "d", path: "/p", title: "t"))]
            }
        }
        let gate = IngestGate(retriever: Instant())
        var results: [Bool] = []
        for await ok in gate.searchableStream(probe: "x", timeout: .seconds(1)) {
            results.append(ok)
        }
        XCTAssertEqual(results, [true])
    }

    func testSearchableStreamCancelsCleanly() async {
        let gate = IngestGate(retriever: SlowReady(counter: SlowCounter()))
        let stream = gate.searchableStream(probe: "x", timeout: .seconds(5))
        let task = Task {
            var out: [Bool] = []
            for await v in stream { out.append(v) }
            return out
        }
        try? await Task.sleep(for: .milliseconds(120))
        task.cancel()
        _ = await task.result
    }

    func testProperty_timeoutReturnsFalse() async {
        struct Never: Retrieving { func search(_ r: SearchRequest) async throws -> [Retrieved] { [] } }
        let gate = IngestGate(retriever: Never())
        let ok = await gate.waitUntilSearchable(probe: "probe", timeout: .milliseconds(300))
        XCTAssertFalse(ok)
    }
}
