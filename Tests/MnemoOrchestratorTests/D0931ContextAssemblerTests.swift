import XCTest
@testable import MnemoOrchestrator

/// D-0931: agentic grep deadlock prevention for ContextAssembler (seed 45b1085a08db).
final class D0931ContextAssemblerTests: XCTestCase {
    private let seed = "45b1085a08db"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(ContextAssembler.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
