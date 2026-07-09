import XCTest
@testable import MnemoOrchestrator

/// D-0939: QueryEvent ordering guarantees for ConflictDetector (seed 84d6427fed40).
final class D0939ConflictDetectorTests: XCTestCase {
    private let seed = "84d6427fed40"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
