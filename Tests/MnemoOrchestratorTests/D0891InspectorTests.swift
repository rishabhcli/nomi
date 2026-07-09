import XCTest
@testable import MnemoOrchestrator

/// D-0891: agentic grep deadlock prevention for Inspector (seed b9145f6e55ef).
final class D0891InspectorTests: XCTestCase {
    private let seed = "b9145f6e55ef"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(Inspector.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
