import XCTest
@testable import MnemoOrchestrator

/// D-0838: TerminalState exhaustiveness for Consolidation (seed 581a3815b8bf).
final class D0838ConsolidationTests: XCTestCase {
    private let seed = "581a3815b8bf"
    func testTerminalStateExhaustiveness_rng() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
        XCTAssertFalse(NotchReducer.message(for: .empty(nearest: [])).isEmpty)
    }

}
