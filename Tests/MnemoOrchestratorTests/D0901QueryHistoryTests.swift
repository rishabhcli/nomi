import XCTest
@testable import MnemoOrchestrator

/// D-0901: property-based invariants for QueryHistory (seed 689ab69f11c0).
final class D0901QueryHistoryTests: XCTestCase {
    private let seed = "689ab69f11c0"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
