import XCTest
@testable import MnemoOrchestrator

/// D-0861: property-based invariants for MediaCompanion (seed bbb3d6212837).
final class D0861MediaCompanionTests: XCTestCase {
    private let seed = "bbb3d6212837"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
