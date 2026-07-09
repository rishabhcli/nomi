import XCTest
@testable import MnemoOrchestrator

/// D-0779: QueryEvent ordering guarantees for Prompt (seed 29dd374e2820).
final class D0779PromptTests: XCTestCase {
    private let seed = "29dd374e2820"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
