import XCTest
@testable import MnemoOrchestrator

/// D-0781: property-based invariants for Ingestion (seed ddf40571e3b2).
final class D0781IngestionTests: XCTestCase {
    private let seed = "ddf40571e3b2"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
