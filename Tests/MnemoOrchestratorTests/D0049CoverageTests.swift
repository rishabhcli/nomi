import XCTest
@testable import MnemoOrchestrator

/// D-0049: Coverage memory supersession race conditions (seed bf20cb7478d3).
final class D0049CoverageTests: XCTestCase {
    private let seed = "bf20cb7478d3"

    func testSupersessionRaceSafe() {
        let k1 = Coverage.supersessionKey(id: "a", version: 1)
        let k2 = Coverage.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(Coverage.supersessionRaceSafe())
    }
}
