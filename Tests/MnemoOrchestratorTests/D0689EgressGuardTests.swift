import XCTest
@testable import MnemoOrchestrator

/// D-0689: memory supersession race conditions for EgressGuard (seed 6c3d5d95c79e).
final class D0689EgressGuardTests: XCTestCase {
    private let seed = "6c3d5d95c79e"

    func testSupersession_raceSafe() {
        XCTAssertTrue(EgressGuard.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = EgressGuard.supersessionKey(id: "d", version: 1)
        let k2 = EgressGuard.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
