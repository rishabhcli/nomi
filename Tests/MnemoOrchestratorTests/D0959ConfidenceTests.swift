import XCTest
@testable import MnemoOrchestrator

/// D-0959: QueryEvent ordering guarantees for Confidence (seed 857689c39618).
final class D0959ConfidenceTests: XCTestCase {
    private let seed = "857689c39618"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
