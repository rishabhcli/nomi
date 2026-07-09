import XCTest
@testable import MnemoOrchestrator

/// D-0589: memory supersession race conditions for NotchReducer (seed 6d78f47313dc).
final class D0589NotchReducerTests: XCTestCase {
    private let seed = "6d78f47313dc"

    func testSupersession_raceSafe() {
        XCTAssertTrue(NotchReducer.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = NotchReducer.supersessionKey(id: "d", version: 1)
        let k2 = NotchReducer.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
