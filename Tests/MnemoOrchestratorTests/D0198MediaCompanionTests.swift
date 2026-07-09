import XCTest
@testable import MnemoOrchestrator

/// D-0198: MediaCompanion TerminalState exhaustiveness (seed 860e7777f150).
final class D0198MediaCompanionTests: XCTestCase {
    private let seed = "860e7777f150"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(MediaCompanion.terminalStatesExhaustive())
        for t in MediaCompanion.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
