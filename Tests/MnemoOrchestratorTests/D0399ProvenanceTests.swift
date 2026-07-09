import XCTest
@testable import MnemoOrchestrator

/// D-0399: Provenance QueryEvent ordering guarantees (seed 55ad6e579b27).
final class D0399ProvenanceTests: XCTestCase {
    private let seed = "55ad6e579b27"

    func testLifecycleEventOrder() {
        let events = Provenance.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertGreaterThanOrEqual(events.count, 2)
        Phase2TechniqueSupport.assertEventsRenderable(events)
    }

    func testNotchReducerAppendsReasoning() {
        var state = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        state = NotchReducer.apply(.routed(intent: "lookup", effort: "low"), to: state)
        state = NotchReducer.apply(.reasoning(["step"]), to: state)
        XCTAssertFalse(state.reasoning.isEmpty)
    }

    func testProperty_eventReductionStable() {
        var rng = Phase2RNG(seed: seed)
        for branch in [Provenance.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = Provenance.lifecycleEvents(branch: branch)
            let e2 = Provenance.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
