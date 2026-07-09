import XCTest
@testable import MnemoOrchestrator

/// D-0304: Coverage offline refusal paths (seed 76b15deb6036).
final class D0304CoverageTests: XCTestCase {
    private let seed = "76b15deb6036"

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
