import XCTest
@testable import MnemoOrchestrator

/// D-0461: Router property-based invariants (seed a2a2cffdfedf).
final class D0461RouterTests: XCTestCase {
    private let seed = "a2a2cffdfedf"

    func testWeakCoverageMonotonic() {
        XCTAssertTrue(Coverage.isWeak(topSimilarity: 0.0, count: 0))
        XCTAssertFalse(Coverage.isWeak(topSimilarity: 0.9, count: 5))
    }

    func testIngestionSelfHealFiltersEmpty() {
        XCTAssertEqual(Router.ingestionSelfHealSafe(orphanIds: ["a", "", "b"]), ["a", "b"])
    }

    func testProperty_invariantHoldsUnderRNG() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let sim = Double(rng.nextInt(upperBound: 100)) / 100.0
            let count = rng.nextInt(upperBound: 10)
            let weak = Coverage.isWeak(topSimilarity: sim, count: count)
            if count == 0 { XCTAssertTrue(weak) }
        }
    }
}
