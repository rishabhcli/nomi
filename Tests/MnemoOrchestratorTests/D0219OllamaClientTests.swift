import XCTest
@testable import MnemoOrchestrator

/// D-0219: OllamaClient QueryEvent ordering guarantees (seed f9554ababaed).
final class D0219OllamaClientTests: XCTestCase {
    private let seed = "f9554ababaed"

    func testEventOrderingGuaranteed() {
        let events = OllamaClient.orderedLifecycleEvents()
        XCTAssertEqual(events.last, .done)
        if let r = events.first { XCTAssertTrue(OllamaClient.eventOrderingValid(events)) }
    }
}
