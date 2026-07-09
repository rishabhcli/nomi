import XCTest
@testable import MnemoOrchestrator

/// D-0549: memory supersession race conditions for ResponseStyle (seed 5d6114b85345).
final class D0549ResponseStyleTests: XCTestCase {
    private let seed = "5d6114b85345"

    func testSupersession_raceSafe() {
        XCTAssertTrue(ResponseStyle.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = ResponseStyle.supersessionKey(id: "d", version: 1)
        let k2 = ResponseStyle.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
