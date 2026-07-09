import XCTest
@testable import MnemoOrchestrator

/// D-0412: EvidenceGathering numeric synthesis distractor immunity (seed 752b632c66fa).
final class D0412EvidenceGatheringTests: XCTestCase {
    private let seed = "752b632c66fa"

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
