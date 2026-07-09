import XCTest
@testable import MnemoOrchestrator

/// D-0358: QueryService TerminalState exhaustiveness (seed e1a65d08b2b1).
final class D0358QueryServiceTests: XCTestCase {
    private let seed = "e1a65d08b2b1"

    func testIndexingTerminalState() {
        let ts = QueryService.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(QueryService.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(QueryService.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
