import XCTest
@testable import MnemoOrchestrator

/// D-0509: memory supersession race conditions for Highlight (seed dece20d5a7c2).
final class D0509HighlightTests: XCTestCase {
    private let seed = "dece20d5a7c2"

    func testSupersession_raceSafe() {
        XCTAssertTrue(Highlight.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = Highlight.supersessionKey(id: "d", version: 1)
        let k2 = Highlight.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
