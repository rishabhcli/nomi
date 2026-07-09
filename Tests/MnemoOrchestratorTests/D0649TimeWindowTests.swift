import XCTest
@testable import MnemoOrchestrator

/// D-0649: memory supersession race conditions for TimeWindow (seed 12a5d1a382a2).
final class D0649TimeWindowTests: XCTestCase {
    private let seed = "12a5d1a382a2"

    func testSupersession_raceSafe() {
        XCTAssertTrue(TimeWindow.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = TimeWindow.supersessionKey(id: "d", version: 1)
        let k2 = TimeWindow.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
