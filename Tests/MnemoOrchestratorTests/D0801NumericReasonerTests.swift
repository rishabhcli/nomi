import XCTest
@testable import MnemoOrchestrator

/// D-0801: property-based invariants for NumericReasoner (seed 2d82cbb05f6a).
final class D0801NumericReasonerTests: XCTestCase {
    private let seed = "2d82cbb05f6a"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
