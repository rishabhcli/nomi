import XCTest
@testable import MnemoOrchestrator

/// D-0698: TerminalState exhaustiveness for PersonalRanker (seed 825b5314e611).
final class D0698PersonalRankerTests: XCTestCase {
    private let seed = "825b5314e611"

    func testTerminal_exhaustive() {
        XCTAssertTrue(PersonalRanker.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in PersonalRanker.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
