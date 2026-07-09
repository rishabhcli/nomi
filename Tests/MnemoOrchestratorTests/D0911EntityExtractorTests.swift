import XCTest
@testable import MnemoOrchestrator

/// D-0911: agentic grep deadlock prevention for EntityExtractor (seed a6f7fa3be217).
final class D0911EntityExtractorTests: XCTestCase {
    private let seed = "a6f7fa3be217"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(EntityExtractor.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
