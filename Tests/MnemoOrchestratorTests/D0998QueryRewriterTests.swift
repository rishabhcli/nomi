import XCTest
@testable import MnemoOrchestrator

/// D-0998: TerminalState exhaustiveness for QueryRewriter (seed f6ab00417796).
final class D0998QueryRewriterTests: XCTestCase {
    private let seed = "f6ab00417796"
    func testTerminalStateExhaustiveness_rng() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
        XCTAssertFalse(NotchReducer.message(for: .empty(nearest: [])).isEmpty)
    }

}
