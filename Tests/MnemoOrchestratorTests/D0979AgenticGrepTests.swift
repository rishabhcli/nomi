import XCTest
@testable import MnemoOrchestrator

/// D-0979: QueryEvent ordering guarantees for AgenticGrep (seed 6c6ea4496b63).
final class D0979AgenticGrepTests: XCTestCase {
    private let seed = "6c6ea4496b63"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
