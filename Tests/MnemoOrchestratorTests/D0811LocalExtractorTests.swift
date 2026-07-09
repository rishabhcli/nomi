import XCTest
@testable import MnemoOrchestrator

/// D-0811: agentic grep deadlock prevention for LocalExtractor (seed 08379b72b37d).
final class D0811LocalExtractorTests: XCTestCase {
    private let seed = "08379b72b37d"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(LocalExtractor.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
