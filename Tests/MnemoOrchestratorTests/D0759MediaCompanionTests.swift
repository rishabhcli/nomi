import XCTest
@testable import MnemoOrchestrator

/// D-0759: QueryEvent ordering guarantees for MediaCompanion (seed c0ef3d69d388).
final class D0759MediaCompanionTests: XCTestCase {
    private let seed = "c0ef3d69d388"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
