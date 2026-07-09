import XCTest
@testable import MnemoOrchestrator

/// D-0318: LLMHopPlanner TerminalState exhaustiveness (seed 74bae27b06ea).
final class D0318LLMHopPlannerTests: XCTestCase {
    private let seed = "74bae27b06ea"

    func testIndexingTerminalState() {
        let ts = LLMHopPlanner.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(LLMHopPlanner.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(LLMHopPlanner.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
