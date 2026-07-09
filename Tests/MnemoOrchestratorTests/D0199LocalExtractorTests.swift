import XCTest
@testable import MnemoOrchestrator

/// D-0199: LocalExtractor QueryEvent ordering guarantees (seed 2d0f5cfff29c).
final class D0199LocalExtractorTests: XCTestCase {
    private let seed = "2d0f5cfff29c"

    func testEventOrderingGuaranteed() {
        let events = LocalExtractor.orderedLifecycleEvents()
        XCTAssertEqual(events.last, .done)
        if let r = events.first { XCTAssertTrue(LocalExtractor.eventOrderingValid(events)) }
    }
}
