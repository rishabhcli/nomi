import XCTest
@testable import MnemoOrchestrator

/// D-0225: ConflictDetector cache poisoning resistance (seed 855a9df6bdf3).
final class D0225ConflictDetectorTests: XCTestCase {
    private let seed = "855a9df6bdf3"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(ConflictDetector.resistsCachePoisoning(poisoned))
        XCTAssertTrue(ConflictDetector.resistsCachePoisoning("local fact only"))
    }
}
