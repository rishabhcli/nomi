import XCTest
@testable import MnemoOrchestrator

/// D-0378: ConflictDetector TerminalState exhaustiveness (seed faa0c581c628).
final class D0378ConflictDetectorTests: XCTestCase {
    private let seed = "faa0c581c628"

    func testIndexingTerminalState() {
        let ts = ConflictDetector.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(AgenticGrep.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(ConflictDetector.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
