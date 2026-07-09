import XCTest
@testable import MnemoOrchestrator

/// D-0258: RouterEscalator TerminalState exhaustiveness (seed d2970980a6c7).
final class D0258RouterEscalatorTests: XCTestCase {
    private let seed = "d2970980a6c7"

    func testIndexingTerminalState() {
        let ts = RouterEscalator.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(RouterEscalator.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(RouterEscalator.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
