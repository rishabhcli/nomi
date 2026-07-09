import XCTest
@testable import MnemoOrchestrator

/// D-0081: QueryDecomposer property-based invariants (seed d1a7358b21f5).
final class D0081QueryDecomposerTests: XCTestCase {
    private let seed = "d1a7358b21f5"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("QueryDecomposer", i: i))
            }
            XCTAssertTrue(QueryDecomposer.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(QueryDecomposer.propertyInvariantsHold([]))
    }
}
