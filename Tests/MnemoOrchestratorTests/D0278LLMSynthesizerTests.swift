import XCTest
@testable import MnemoOrchestrator

/// D-0278: LLMSynthesizer TerminalState exhaustiveness (seed 42fad067f4f0).
final class D0278LLMSynthesizerTests: XCTestCase {
    private let seed = "42fad067f4f0"

    func testIndexingTerminalState() {
        let ts = LLMSynthesizer.indexingTerminalState(path: "/docs/a.pdf")
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
            XCTAssertEqual(LLMSynthesizer.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
