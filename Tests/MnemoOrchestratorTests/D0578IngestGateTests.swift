import XCTest
@testable import MnemoOrchestrator

/// D-0578: TerminalState exhaustiveness for IngestGate (seed 6b6fad3f8226).
final class D0578IngestGateTests: XCTestCase {
    private let seed = "6b6fad3f8226"

    func testTerminal_exhaustive() {
        XCTAssertTrue(IngestGate.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in IngestGate.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
