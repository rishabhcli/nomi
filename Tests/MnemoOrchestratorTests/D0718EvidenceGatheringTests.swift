import XCTest
@testable import MnemoOrchestrator

/// D-0718: TerminalState exhaustiveness for EvidenceGathering (seed 4a4a4b8498b5).
final class D0718EvidenceGatheringTests: XCTestCase {
    private let seed = "4a4a4b8498b5"

    func testTerminal_exhaustive() {
        XCTAssertTrue(EvidenceGathering.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in EvidenceGathering.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
