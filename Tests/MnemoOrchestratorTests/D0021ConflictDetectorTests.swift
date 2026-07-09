import XCTest
@testable import MnemoOrchestrator

/// D-0021: ConflictDetector property-based invariants (seed 2dbfb97e6da7).
final class D0021ConflictDetectorTests: XCTestCase {
    private let seed = "2dbfb97e6da7"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("ConflictDetector", i: i))
            }
            XCTAssertTrue(ConflictDetector.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(ConflictDetector.propertyInvariantsHold([]))
    }
}
