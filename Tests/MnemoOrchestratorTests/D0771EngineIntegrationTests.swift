import XCTest
@testable import MnemoOrchestrator

/// D-0771: agentic grep deadlock prevention for EngineIntegration (seed a63c657b605f).
final class D0771EngineIntegrationTests: XCTestCase {
    private let seed = "a63c657b605f"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(EngineIntegration.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
