import XCTest
@testable import MnemoOrchestrator

/// D-0749: memory supersession race conditions for PersonalRanker (seed 182b7c581f7e).
final class D0749PersonalRankerTests: XCTestCase {
    private let seed = "182b7c581f7e"

    func testSupersession_raceSafe() {
        XCTAssertTrue(PersonalRanker.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = PersonalRanker.supersessionKey(id: "d", version: 1)
        let k2 = PersonalRanker.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
