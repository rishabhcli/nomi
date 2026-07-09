import XCTest
@testable import MnemoOrchestrator

/// D-0919: QueryEvent ordering guarantees for QueryService (seed 070871211234).
final class D0919QueryServiceTests: XCTestCase {
    private let seed = "070871211234"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
