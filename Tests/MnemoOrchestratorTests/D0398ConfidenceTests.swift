import XCTest
@testable import MnemoOrchestrator

/// D-0398: Confidence TerminalState exhaustiveness (seed 58f93bfe28ec).
final class D0398ConfidenceTests: XCTestCase {
    private let seed = "58f93bfe28ec"

    func testIndexingTerminalState() {
        let ts = Confidence.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(Confidence.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(Confidence.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
