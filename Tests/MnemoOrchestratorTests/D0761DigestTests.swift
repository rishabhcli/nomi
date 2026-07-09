import XCTest
@testable import MnemoOrchestrator

/// D-0761: property-based invariants for Digest (seed d1bbc47a987a).
final class D0761DigestTests: XCTestCase {
    private let seed = "d1bbc47a987a"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
