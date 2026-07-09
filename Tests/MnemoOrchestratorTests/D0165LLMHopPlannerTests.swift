import XCTest
@testable import MnemoOrchestrator

/// D-0165: LLMHopPlanner cache poisoning resistance (seed abed803eae46).
final class D0165LLMHopPlannerTests: XCTestCase {
    private let seed = "abed803eae46"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(LLMHopPlanner.resistsCachePoisoning(poisoned))
        XCTAssertTrue(LLMHopPlanner.resistsCachePoisoning("local fact only"))
    }
}
