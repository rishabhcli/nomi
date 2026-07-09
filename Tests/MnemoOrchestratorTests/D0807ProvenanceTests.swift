import XCTest
@testable import MnemoOrchestrator

/// D-0807: router escalation boundaries for Provenance (seed 97ae94a7373c).
final class D0807ProvenanceTests: XCTestCase {
    private let seed = "97ae94a7373c"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
