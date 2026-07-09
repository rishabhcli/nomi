import XCTest
@testable import MnemoOrchestrator

/// D-0819: QueryEvent ordering guarantees for RouterEscalator (seed 8336180f58b8).
final class D0819RouterEscalatorTests: XCTestCase {
    private let seed = "8336180f58b8"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
