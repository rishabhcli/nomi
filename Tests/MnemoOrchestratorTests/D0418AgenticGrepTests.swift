import XCTest
@testable import MnemoOrchestrator

/// D-0418: AgenticGrep TerminalState exhaustiveness (seed b0859ac603b0).
final class D0418AgenticGrepTests: XCTestCase {
    private let seed = "b0859ac603b0"

    func testIndexingTerminalState() {
        let ts = AgenticGrep.indexingTerminalState(path: "/docs/a.pdf")
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
            XCTAssertEqual(AgenticGrep.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
