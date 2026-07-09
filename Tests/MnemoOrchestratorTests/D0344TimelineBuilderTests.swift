import XCTest
@testable import MnemoOrchestrator

/// D-0344: TimelineBuilder offline refusal paths (seed 91ebc674bf0e).
final class D0344TimelineBuilderTests: XCTestCase {
    private let seed = "91ebc674bf0e"

    func testUnsupportedAnswerEvents() {
        XCTAssertEqual(TimelineBuilder.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }

    func testEmptyContextRefusal() {
        XCTAssertEqual(Prompt.context([]), "NO CONTEXT AVAILABLE.")
    }

    func testProperty_offlineEventsRenderable() {
        var rng = Phase2RNG(seed: seed)
        _ = rng.randomQuery(length: rng.nextInt(upperBound: 3) + 1)
        Phase2TechniqueSupport.assertEventsRenderable(TimelineBuilder.unsupportedAnswerEvents())
        Phase2TechniqueSupport.assertEventsRenderable(Coverage.emptyEvidenceEvents())
    }
}
