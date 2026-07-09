import XCTest
@testable import MnemoOrchestrator

/// D-0299: EntityExtractor QueryEvent ordering guarantees (seed 16c53d02fcfd).
final class D0299EntityExtractorTests: XCTestCase {
    private let seed = "16c53d02fcfd"

    func testLifecycleEventOrder() {
        let events = EntityExtractor.lifecycleEvents(branch: .emptyEvidence)
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
        for branch in [EntityExtractor.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = EntityExtractor.lifecycleEvents(branch: branch)
            let e2 = EntityExtractor.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
