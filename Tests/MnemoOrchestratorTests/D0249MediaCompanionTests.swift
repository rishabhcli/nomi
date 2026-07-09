import XCTest
@testable import MnemoOrchestrator

/// D-0249: MediaCompanion memory supersession race conditions (seed 91260a753d27).
final class D0249MediaCompanionTests: XCTestCase {
    private let seed = "91260a753d27"

    func testSupersessionRaceSafe() {
        let k1 = MediaCompanion.supersessionKey(id: "a", version: 1)
        let k2 = MediaCompanion.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(MediaCompanion.supersessionRaceSafe())
    }
}
