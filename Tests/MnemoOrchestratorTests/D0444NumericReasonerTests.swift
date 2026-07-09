import XCTest
@testable import MnemoOrchestrator

/// D-0444: NumericReasoner offline refusal paths (seed 772abeb79b17).
final class D0444NumericReasonerTests: XCTestCase {
    private let seed = "772abeb79b17"

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
