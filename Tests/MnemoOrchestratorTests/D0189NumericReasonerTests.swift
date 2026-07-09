import XCTest
@testable import MnemoOrchestrator

/// D-0189: NumericReasoner memory supersession race conditions (seed f0e782646455).
final class D0189NumericReasonerTests: XCTestCase {
    private let seed = "f0e782646455"

    func testSupersessionRaceSafe() {
        let k1 = NumericReasoner.supersessionKey(id: "a", version: 1)
        let k2 = NumericReasoner.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(NumericReasoner.supersessionRaceSafe())
    }
}
