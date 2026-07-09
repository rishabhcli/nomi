import XCTest
@testable import MnemoOrchestrator

/// D-0618: TerminalState exhaustiveness for EngineIntegration (seed ad024a576b09).
final class D0618EngineIntegrationTests: XCTestCase {
    private let seed = "ad024a576b09"

    func testTerminal_exhaustive() {
        XCTAssertTrue(EngineIntegration.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in EngineIntegration.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
