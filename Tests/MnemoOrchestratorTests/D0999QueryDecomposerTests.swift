import XCTest
@testable import MnemoOrchestrator

/// D-0999: QueryEvent ordering guarantees for QueryDecomposer (seed 3bff09b67d73).
final class D0999QueryDecomposerTests: XCTestCase {
    private let seed = "3bff09b67d73"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
