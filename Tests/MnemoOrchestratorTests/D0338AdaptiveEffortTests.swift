import XCTest
@testable import MnemoOrchestrator

/// D-0338: AdaptiveEffort TerminalState exhaustiveness (seed b99096b1525c).
final class D0338AdaptiveEffortTests: XCTestCase {
    private let seed = "b99096b1525c"

    func testIndexingTerminalState() {
        let ts = AdaptiveEffort.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(AdaptiveEffort.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(AdaptiveEffort.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
