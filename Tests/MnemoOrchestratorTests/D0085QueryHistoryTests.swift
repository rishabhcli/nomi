import XCTest
@testable import MnemoOrchestrator

/// D-0085: QueryHistory cache poisoning resistance (seed 9588b21b2d90).
final class D0085QueryHistoryTests: XCTestCase {
    private let seed = "9588b21b2d90"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(QueryHistory.resistsCachePoisoning(poisoned))
        XCTAssertTrue(QueryHistory.resistsCachePoisoning("local fact only"))
    }
}
