import XCTest
@testable import MnemoOrchestrator

/// D-0119: IngestGate QueryEvent ordering guarantees (seed f2bdeb848334).
final class D0119IngestGateTests: XCTestCase {
    private let seed = "f2bdeb848334"

    func testEventOrderingGuaranteed() {
        let events = IngestGate.orderedLifecycleEvents()
        XCTAssertEqual(events.last, .done)
        if let r = events.first { XCTAssertTrue(IngestGate.eventOrderingValid(events)) }
    }
}
