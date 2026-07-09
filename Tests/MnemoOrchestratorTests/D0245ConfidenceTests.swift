import XCTest
@testable import MnemoOrchestrator

/// D-0245: Confidence cache poisoning resistance (seed 024f34139e18).
final class D0245ConfidenceTests: XCTestCase {
    private let seed = "024f34139e18"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(Confidence.resistsCachePoisoning(poisoned))
        XCTAssertTrue(Confidence.resistsCachePoisoning("local fact only"))
    }
}
