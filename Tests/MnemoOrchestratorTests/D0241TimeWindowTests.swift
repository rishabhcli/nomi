import XCTest
@testable import MnemoOrchestrator

/// D-0241: TimeWindow property-based invariants (seed 4231d5fe9ada).
final class D0241TimeWindowTests: XCTestCase {
    private let seed = "4231d5fe9ada"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("TimeWindow", i: i))
            }
            XCTAssertTrue(TimeWindow.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(TimeWindow.propertyInvariantsHold([]))
    }
}
