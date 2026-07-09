import XCTest
@testable import MnemoOrchestrator

/// D-0404: Digest offline refusal paths (seed c46bdf955899).
final class D0404DigestTests: XCTestCase {
    private let seed = "c46bdf955899"

    func testUnsupportedAnswerEvents() {
        XCTAssertEqual(Digest.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }

    func testEmptyContextRefusal() {
        XCTAssertEqual(Prompt.context([]), "NO CONTEXT AVAILABLE.")
    }

    func testProperty_offlineEventsRenderable() {
        var rng = Phase2RNG(seed: seed)
        _ = rng.randomQuery(length: rng.nextInt(upperBound: 3) + 1)
        Phase2TechniqueSupport.assertEventsRenderable(Digest.unsupportedAnswerEvents())
        Phase2TechniqueSupport.assertEventsRenderable(Coverage.emptyEvidenceEvents())
    }
}
