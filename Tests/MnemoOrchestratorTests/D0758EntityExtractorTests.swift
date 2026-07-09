import XCTest
@testable import MnemoOrchestrator

/// D-0758: TerminalState exhaustiveness for EntityExtractor (seed 77c1fa6415ee).
final class D0758EntityExtractorTests: XCTestCase {
    private let seed = "77c1fa6415ee"
    func testTerminalStateExhaustiveness_rng() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
        XCTAssertFalse(NotchReducer.message(for: .empty(nearest: [])).isEmpty)
    }

}
