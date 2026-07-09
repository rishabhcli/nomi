import XCTest
@testable import MnemoOrchestrator

/// D-0361: EvidenceGathering property-based invariants (seed 4e2f868ebed8).
final class D0361EvidenceGatheringTests: XCTestCase {
    private let seed = "4e2f868ebed8"

    func testWeakCoverageMonotonic() {
        XCTAssertTrue(Coverage.isWeak(topSimilarity: 0.0, count: 0))
        XCTAssertFalse(Coverage.isWeak(topSimilarity: 0.9, count: 5))
    }

    func testIngestionSelfHealFiltersEmpty() {
        XCTAssertEqual(AgenticGrep.ingestionSelfHealSafe(orphanIds: ["a", "", "b"]), ["a", "b"])
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
