import XCTest
@testable import MnemoOrchestrator

/// D-0892: numeric synthesis distractor immunity for Profile (seed b3e03e6e2e74).
final class D0892ProfileTests: XCTestCase {
    private let seed = "b3e03e6e2e74"
    func testNumericDistractorImmunity_rng() {
        var rng = Phase2RNG(seed: seed)
        let evidence = [Retrieved(memory: "count is 42 items", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        let claim = rng.randomQuery(length: 3)
        XCTAssertTrue(Phase2Techniques.immuneToNumericDistractor(claim: claim, evidence: evidence, distractor: "99"))
        XCTAssertTrue(NumericReasoner.isNumericQuestion("how many items?"))
    }

}
