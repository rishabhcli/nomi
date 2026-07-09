import XCTest
@testable import MnemoOrchestrator

/// D-0907: router escalation boundaries for FollowUp (seed 6eb960e72fb7).
final class D0907FollowUpTests: XCTestCase {
    private let seed = "6eb960e72fb7"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
