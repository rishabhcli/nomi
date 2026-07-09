import XCTest
@testable import MnemoOrchestrator

/// D-0831: agentic grep deadlock prevention for OllamaClient (seed eb7bd57c4374).
final class D0831OllamaClientTests: XCTestCase {
    private let seed = "eb7bd57c4374"
    func testDeadlockPrevention_rng() {
        var rng = Phase2RNG(seed: seed)
        let hops = (0..<5).map { _ in rng.randomQuery(length: 2) }
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: hops))
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: [hops.first ?? "q", hops.first ?? "q"]))
        XCTAssertTrue(AgenticGrep.isRepeatedHop(hops.first ?? "q", hops: [HopTrace(hop: 1, kind: "semantic", query: hops.first ?? "q", paths: [], rationale: "")]))
    }
    func testModuleDeadlockWrapper() {
        XCTAssertTrue(OllamaClient.agenticDeadlockSafe(hopQueries: ["a", "b"]))
    }

}
