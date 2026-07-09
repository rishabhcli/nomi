import XCTest
@testable import MnemoOrchestrator

/// D-0284: QueryRewriter offline refusal paths (seed 26a15f5efbfe).
final class D0284QueryRewriterTests: XCTestCase {
    private let seed = "26a15f5efbfe"

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
