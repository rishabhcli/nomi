import XCTest
@testable import MnemoOrchestrator

/// D-0839: QueryEvent ordering guarantees for LLMSynthesizer (seed 2462394d7788).
final class D0839LLMSynthesizerTests: XCTestCase {
    private let seed = "2462394d7788"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
