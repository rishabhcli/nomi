import XCTest
@testable import MnemoOrchestrator

/// Shared timeline corpus for beats-Siri offline synthesis gates (prompts 051–080).
enum BeatsSiriFixtures {
    static let timelineA = Retrieved(
        memory: "Originally scheduled for May 5, 2023.",
        similarity: 0.82,
        source: .init(docId: "ta", path: "/timeline-a.md", title: "timeline-a.md", updatedAt: "2026-04-01T00:00:00Z"))
    static let timelineB = Retrieved(
        memory: "Slipped to May 19 because the schema freeze was late.",
        similarity: 0.80,
        source: .init(docId: "tb", path: "/timeline-b.md", title: "timeline-b.md", updatedAt: "2026-05-15T00:00:00Z"))
    static let timelineC = Retrieved(
        memory: "Kicked off June 2; the slip totaled four weeks.",
        similarity: 0.78,
        source: .init(docId: "tc", path: "/timeline-c.md", title: "timeline-c.md", updatedAt: "2026-06-30T00:00:00Z"))

    static var timelineEvidence: [Retrieved] { [timelineA, timelineB, timelineC] }

    static func timelineCards() -> [SourceCard] {
        timelineEvidence.map {
            SourceCard(title: $0.source.title, path: $0.source.path, docId: $0.source.docId,
                       snippet: $0.memory, relevance: $0.similarity, updatedAt: $0.source.updatedAt)
        }
    }

    /// Cross-doc synthesis answer with inline citations (offline, no egress).
    static let synthesizedAnswer =
        "The Aurora migration slipped four weeks from May 5 to June 2 [timeline-a.md] [timeline-c.md]."

    static func assertCrossDocSources(_ cards: [SourceCard], file: StaticString = #file, line: UInt = #line) {
        let ids = Set(cards.map(\.docId))
        XCTAssertTrue(ids.contains("ta") || ids.contains("tb") || ids.contains("tc"),
                      "expected timeline docs in sources, got \(ids)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(ids.count, 2, file: file, line: line)
    }

    static func assertVerifiedCitations(in answer: String, evidence: [Retrieved] = timelineEvidence,
                                        file: StaticString = #file, line: UInt = #line) async {
        let backend = StubVerifierBackend(similarity: { _, _ in 0.95 }, entails: { _, _ in true })
        let verdicts = await CitationVerifier(backend: backend).verify(answer: answer, evidence: evidence)
        XCTAssertFalse(verdicts.isEmpty, file: file, line: line)
        XCTAssertTrue(verdicts.allSatisfy(\.supported), "all sentences must verify offline", file: file, line: line)
    }
}
