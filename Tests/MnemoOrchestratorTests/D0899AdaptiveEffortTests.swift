import XCTest
@testable import MnemoOrchestrator

/// D-0899: QueryEvent ordering guarantees for AdaptiveEffort (seed 64f5da70eff3).
final class D0899AdaptiveEffortTests: XCTestCase {
    private let seed = "64f5da70eff3"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
