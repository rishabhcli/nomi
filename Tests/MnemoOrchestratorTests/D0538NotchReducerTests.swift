import XCTest
@testable import MnemoOrchestrator

/// D-0538: TerminalState exhaustiveness for NotchReducer (seed 026ffb7e7431).
final class D0538NotchReducerTests: XCTestCase {
    private let seed = "026ffb7e7431"

    func testTerminal_exhaustive() {
        XCTAssertTrue(NotchReducer.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in NotchReducer.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
