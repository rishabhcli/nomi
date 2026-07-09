import XCTest
@testable import MnemoOrchestrator

/// D-0799: QueryEvent ordering guarantees for QueryHistory (seed 45ca5574c163).
final class D0799QueryHistoryTests: XCTestCase {
    private let seed = "45ca5574c163"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
