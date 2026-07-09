import XCTest
@testable import MnemoOrchestrator

/// D-0867: router escalation boundaries for ActionExtractor (seed 905df9d51c13).
final class D0867ActionExtractorTests: XCTestCase {
    private let seed = "905df9d51c13"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
