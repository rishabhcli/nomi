import XCTest
@testable import MnemoOrchestrator

/// D-0185: AdaptiveEffort cache poisoning resistance (seed 6669b833b963).
final class D0185AdaptiveEffortTests: XCTestCase {
    private let seed = "6669b833b963"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(AdaptiveEffort.resistsCachePoisoning(poisoned))
        XCTAssertTrue(AdaptiveEffort.resistsCachePoisoning("local fact only"))
    }
}
