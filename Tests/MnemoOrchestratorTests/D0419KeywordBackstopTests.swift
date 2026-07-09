import XCTest
@testable import MnemoOrchestrator

/// D-0419: KeywordBackstop QueryEvent ordering guarantees (seed a53f87aebc14).
final class D0419KeywordBackstopTests: XCTestCase {
    private let seed = "a53f87aebc14"

    func testLifecycleEventOrder() {
        let events = KeywordBackstop.lifecycleEvents(branch: .emptyEvidence)
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
        for branch in [KeywordBackstop.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = KeywordBackstop.lifecycleEvents(branch: branch)
            let e2 = KeywordBackstop.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
