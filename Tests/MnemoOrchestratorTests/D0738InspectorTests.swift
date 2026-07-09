import XCTest
@testable import MnemoOrchestrator

/// D-0738: TerminalState exhaustiveness for Inspector (seed 934311df0433).
final class D0738InspectorTests: XCTestCase {
    private let seed = "934311df0433"

    func testTerminal_exhaustive() {
        XCTAssertTrue(Inspector.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in Inspector.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
