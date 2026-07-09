import XCTest
@testable import MnemoOrchestrator

/// D-0205: QueryService cache poisoning resistance (seed 3deba1cc27f7).
final class D0205QueryServiceTests: XCTestCase {
    private let seed = "3deba1cc27f7"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(QueryService.resistsCachePoisoning(poisoned))
        XCTAssertTrue(QueryService.resistsCachePoisoning("local fact only"))
    }
}
