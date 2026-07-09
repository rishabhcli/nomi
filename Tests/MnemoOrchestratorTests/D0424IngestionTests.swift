import XCTest
@testable import MnemoOrchestrator

/// D-0424: Ingestion offline refusal paths (seed 5d6a3abbd8c2).
final class D0424IngestionTests: XCTestCase {
    private let seed = "5d6a3abbd8c2"

    func testUnsupportedAnswerEvents() {
        XCTAssertEqual(Ingestion.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }

    func testEmptyContextRefusal() {
        XCTAssertEqual(Prompt.context([]), "NO CONTEXT AVAILABLE.")
    }

    func testProperty_offlineEventsRenderable() {
        var rng = Phase2RNG(seed: seed)
        _ = rng.randomQuery(length: rng.nextInt(upperBound: 3) + 1)
        Phase2TechniqueSupport.assertEventsRenderable(Ingestion.unsupportedAnswerEvents())
        Phase2TechniqueSupport.assertEventsRenderable(Coverage.emptyEvidenceEvents())
    }
}
