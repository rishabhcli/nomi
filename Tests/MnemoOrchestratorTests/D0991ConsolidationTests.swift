import XCTest
@testable import MnemoOrchestrator

/// D-0991: agentic grep deadlock prevention for Consolidation (seed e561c364100b).
final class D0991ConsolidationTests: XCTestCase {
    private let seed = "e561c364100b"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(Consolidation.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
