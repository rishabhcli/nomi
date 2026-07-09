import XCTest
@testable import MnemoOrchestrator

/// D-0139: TimeWindow QueryEvent ordering guarantees (seed 1ae6fed28ec7).
final class D0139TimeWindowTests: XCTestCase {
    private let seed = "1ae6fed28ec7"

    func testEventOrderingGuaranteed() {
        let events = TimeWindow.orderedLifecycleEvents()
        XCTAssertEqual(events.last, .done)
        if let r = events.first { XCTAssertTrue(TimeWindow.eventOrderingValid(events)) }
    }
}
