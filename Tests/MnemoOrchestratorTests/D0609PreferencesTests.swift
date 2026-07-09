import XCTest
@testable import MnemoOrchestrator

/// D-0609: memory supersession race conditions for Preferences (seed 13f9bfd57ea3).
final class D0609PreferencesTests: XCTestCase {
    private let seed = "13f9bfd57ea3"

    func testSupersession_raceSafe() {
        XCTAssertTrue(Preferences.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = Preferences.supersessionKey(id: "d", version: 1)
        let k2 = Preferences.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
