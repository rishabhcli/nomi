import XCTest
@testable import MnemoOrchestrator

/// D-0987: router escalation boundaries for SyncEngine (seed 9b77e4d15428).
final class D0987SyncEngineTests: XCTestCase {
    private let seed = "9b77e4d15428"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
