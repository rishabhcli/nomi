import XCTest
@testable import MnemoOrchestrator

/// D-0478: ContentHash TerminalState exhaustiveness (seed e7cd5cc6a03e).
final class D0478ContentHashTests: XCTestCase {
    private let seed = "e7cd5cc6a03e"

    func testIndexingTerminalState() {
        let ts = ContentHash.indexingTerminalState(path: "/docs/a.pdf")
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
            XCTAssertEqual(ContentHash.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
