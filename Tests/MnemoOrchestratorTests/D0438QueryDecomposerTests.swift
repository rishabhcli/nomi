import XCTest
@testable import MnemoOrchestrator

/// D-0438: QueryDecomposer TerminalState exhaustiveness (seed e662274d6ebc).
final class D0438QueryDecomposerTests: XCTestCase {
    private let seed = "e662274d6ebc"

    func testIndexingTerminalState() {
        let ts = QueryDecomposer.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(QueryDecomposer.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(QueryDecomposer.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
