import XCTest
@testable import MnemoOrchestrator

/// D-0384: WorkScheduler offline refusal paths (seed 93f166ff9d72).
final class D0384WorkSchedulerTests: XCTestCase {
    private let seed = "93f166ff9d72"

    func testUnsupportedAnswerEvents() {
        XCTAssertEqual(ContextAssembler.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }

    func testEmptyContextRefusal() {
        XCTAssertEqual(Prompt.context([]), "NO CONTEXT AVAILABLE.")
    }

    func testProperty_offlineEventsRenderable() {
        var rng = Phase2RNG(seed: seed)
        _ = rng.randomQuery(length: rng.nextInt(upperBound: 3) + 1)
        Phase2TechniqueSupport.assertEventsRenderable(ContextAssembler.unsupportedAnswerEvents())
        Phase2TechniqueSupport.assertEventsRenderable(Coverage.emptyEvidenceEvents())
    }
}
