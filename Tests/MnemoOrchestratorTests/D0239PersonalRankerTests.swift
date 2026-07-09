import XCTest
@testable import MnemoOrchestrator

/// D-0239: PersonalRanker QueryEvent ordering guarantees (seed 4f9d5b176cc6).
final class D0239PersonalRankerTests: XCTestCase {
    private let seed = "4f9d5b176cc6"

    func testEventOrderingGuaranteed() {
        let events = PersonalRanker.orderedLifecycleEvents()
        XCTAssertEqual(events.last, .done)
        if let r = events.first { XCTAssertTrue(PersonalRanker.eventOrderingValid(events)) }
    }
}
