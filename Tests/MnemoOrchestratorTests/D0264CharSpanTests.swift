import XCTest
@testable import MnemoOrchestrator

/// D-0264: CharSpan offline refusal paths (seed 3de9c5b25830).
final class D0264CharSpanTests: XCTestCase {
    private let seed = "3de9c5b25830"

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
