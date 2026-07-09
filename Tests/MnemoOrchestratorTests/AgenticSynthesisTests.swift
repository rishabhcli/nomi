import XCTest
@testable import MnemoOrchestrator

final class AgenticEvidencePromptTests: XCTestCase {
    func testEvidenceBecomesCitableContext() {
        let evidence = [
            Retrieved(memory: "Original start May 5.", similarity: 0,
                      source: .init(docId: "", path: "/timeline-a.md", title: "timeline-a.md")),
            Retrieved(memory: "Moved to May 19 (schema freeze slip).", similarity: 0,
                      source: .init(docId: "", path: "/timeline-b.md", title: "timeline-b.md")),
            Retrieved(memory: "Kicked off June 2.", similarity: 0,
                      source: .init(docId: "", path: "/timeline-c.md", title: "timeline-c.md")),
        ]
        let ctx = Prompt.context(evidence)
        XCTAssertTrue(ctx.contains("timeline-a.md"))
        XCTAssertTrue(ctx.contains("timeline-b.md"))
        XCTAssertTrue(ctx.contains("timeline-c.md"))
    }

    func testDistinctSourceCountAcrossEvidence() {
        let evidence = [
            Retrieved(memory: "a", similarity: 0, source: .init(docId: "", path: "/x.md", title: "x")),
            Retrieved(memory: "b", similarity: 0, source: .init(docId: "", path: "/x.md", title: "x")),
            Retrieved(memory: "c", similarity: 0, source: .init(docId: "", path: "/y.md", title: "y")),
        ]
        XCTAssertEqual(AgenticResult(evidence: evidence, hops: []).distinctSources, ["/x.md", "/y.md"])
    }
}
