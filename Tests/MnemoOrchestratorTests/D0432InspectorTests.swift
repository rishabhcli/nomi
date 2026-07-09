import XCTest
@testable import MnemoOrchestrator

/// D-0432: Inspector numeric synthesis distractor immunity (seed aed9aca2a2ba).
final class D0432InspectorTests: XCTestCase {
    private let seed = "aed9aca2a2ba"

    func testDistractorDetection() {
        let ev = [
            Phase2TechniqueSupport.sampleRetrieved(memory: "Kickoff January 1, 2020."),
            Phase2TechniqueSupport.sampleRetrieved(docId: "d2", memory: "Milestone June 1, 2020."),
            Phase2TechniqueSupport.sampleRetrieved(docId: "d3", memory: "Unrelated fact from December 1, 2021."),
        ]
        XCTAssertTrue(NumericReasoner.hasDateDistractors(in: ev))
    }

    func testDurationNoteIsAdvisory() {
        let ev = BeatsSiriFixtures.timelineEvidence
        let note = NumericReasoner.durationNote(in: ev)
        XCTAssertNotNil(note)
        XCTAssertTrue(note!.contains("identify the correct start and end"))
    }

    func testProperty_numericQuestionStable() {
        var rng = Phase2RNG(seed: seed)
        let cues = ["how many", "how long", "total", "count"]
        for _ in 0..<6 {
            let q = cues[rng.nextInt(upperBound: cues.count)] + " " + rng.randomQuery(length: 2)
            XCTAssertEqual(NumericReasoner.isNumericQuestion(q), NumericReasoner.isNumericQuestion(q))
        }
    }
}
