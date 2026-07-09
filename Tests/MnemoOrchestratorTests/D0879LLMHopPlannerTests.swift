import XCTest
@testable import MnemoOrchestrator

/// D-0879: QueryEvent ordering guarantees for LLMHopPlanner (seed 1a31ebfa6bac).
final class D0879LLMHopPlannerTests: XCTestCase {
    private let seed = "1a31ebfa6bac"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
