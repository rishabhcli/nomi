import XCTest
@testable import MnemoOrchestrator

/// D-0598: TerminalState exhaustiveness for TimeWindow (seed fad6cda5c7de).
final class D0598TimeWindowTests: XCTestCase {
    private let seed = "fad6cda5c7de"

    func testTerminal_exhaustive() {
        XCTAssertTrue(TimeWindow.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in TimeWindow.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
