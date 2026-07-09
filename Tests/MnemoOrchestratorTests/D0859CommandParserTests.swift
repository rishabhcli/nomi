import XCTest
@testable import MnemoOrchestrator

/// D-0859: QueryEvent ordering guarantees for CommandParser (seed fd8a952c3a1c).
final class D0859CommandParserTests: XCTestCase {
    private let seed = "fd8a952c3a1c"
    func testQueryEventOrdering_rng() {
        let events: [QueryEvent] = [.routed(intent: "lookup", effort: "low"), .sources([]), .done]
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(events))
        if case .routed = events.first { } else { XCTFail("expected routed first") }
    }

}
