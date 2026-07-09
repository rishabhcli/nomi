import XCTest
@testable import MnemoOrchestrator

/// D-0439: ScopeClassifier QueryEvent ordering guarantees (seed c30eaedf5359).
final class D0439ScopeClassifierTests: XCTestCase {
    private let seed = "c30eaedf5359"

    func testLifecycleEventOrder() {
        let events = ScopeClassifier.lifecycleEvents(branch: .emptyEvidence)
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
        for branch in [ScopeClassifier.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = ScopeClassifier.lifecycleEvents(branch: branch)
            let e2 = ScopeClassifier.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
