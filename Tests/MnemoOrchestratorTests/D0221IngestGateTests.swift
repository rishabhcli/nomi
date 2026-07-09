import XCTest
@testable import MnemoOrchestrator

/// D-0221: IngestGate property-based invariants (seed 2fe9312c7fdf).
final class D0221IngestGateTests: XCTestCase {
    private let seed = "2fe9312c7fdf"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("IngestGate", i: i))
            }
            XCTAssertTrue(IngestGate.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(IngestGate.propertyInvariantsHold([]))
    }
}
