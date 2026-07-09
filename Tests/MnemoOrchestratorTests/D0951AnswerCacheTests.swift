import XCTest
@testable import MnemoOrchestrator

/// D-0951: agentic grep deadlock prevention for AnswerCache (seed dd69d4265438).
final class D0951AnswerCacheTests: XCTestCase {
    private let seed = "dd69d4265438"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(AnswerCache.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
