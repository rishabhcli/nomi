import XCTest
@testable import MnemoOrchestrator

/// D-0089: TimelineBuilder memory supersession race conditions (seed 4f288bab611e).
final class D0089TimelineBuilderTests: XCTestCase {
    private let seed = "4f288bab611e"

    func testSupersessionRaceSafe() {
        let k1 = TimelineBuilder.supersessionKey(id: "a", version: 1)
        let k2 = TimelineBuilder.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(TimelineBuilder.supersessionRaceSafe())
    }
}
