import XCTest
@testable import MnemoOrchestrator

/// D-0978: TerminalState exhaustiveness for CharSpan (seed ac711fa7ddf1).
final class D0978CharSpanTests: XCTestCase {
    private let seed = "ac711fa7ddf1"
    func testTerminalStateExhaustiveness_rng() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
        XCTAssertFalse(NotchReducer.message(for: .empty(nearest: [])).isEmpty)
    }

}
