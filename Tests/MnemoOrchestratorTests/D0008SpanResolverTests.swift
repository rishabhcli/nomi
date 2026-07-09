import XCTest
@testable import MnemoOrchestrator

/// D-0008: SpanResolver citation verifier false-positive elimination (seed 3dcedb5dff2a).
final class D0008SpanResolverTests: XCTestCase {
    private let seed = "3dcedb5dff2a"

    func testLowConfidenceSpanNotApplied() async {
        let doc = "alpha beta gamma delta epsilon"
        let fake = FakeDocsStore(records: ["d1": DocumentRecord(content: doc, filepath: "/f.md")])
        let hit = Retrieved(memory: "alpha", similarity: 0.9,
                            source: SourceLocator(docId: "d1", path: "/f.md", title: "f"))
        let out = await SpanResolver(docs: fake).resolve([hit])
        XCTAssertNil(out[0].source.charStart, "single-token match is too weak")
    }

    func testHighConfidenceSpanApplied() async {
        let doc = "Intro.\n\nMy favorite build tool is Bazel.\n\nEnd."
        let fake = FakeDocsStore(records: ["d1": DocumentRecord(content: doc, filepath: "/f.md")])
        let hit = Retrieved(memory: "favorite build tool is Bazel", similarity: 0.9,
                            source: SourceLocator(docId: "d1", path: "/f.md", title: "f"))
        let out = await SpanResolver(docs: fake).resolve([hit])
        XCTAssertNotNil(out[0].source.charStart)
        XCTAssertNotNil(out[0].source.charEnd)
    }

    func testSpanConfidenceRejectsSingleWord() {
        XCTAssertEqual(SpanResolver.spanConfidence(chunk: "alpha", matchedText: "alpha"), 0)
    }

    func testSpanConfidenceAcceptsMultiWord() {
        let c = SpanResolver.spanConfidence(chunk: "build tool Bazel", matchedText: "build tool Bazel")
        XCTAssertGreaterThanOrEqual(c, 0.6)
    }

    func testProperty_fuzzShortChunksRarelyResolve() {
        var rng = Phase2RNG(seed: seed)
        let doc = "one two three four five six seven eight nine ten"
        for _ in 0..<15 {
            let len = 1 + rng.nextInt(upperBound: 3)
            let start = rng.nextInt(upperBound: max(1, doc.count - len))
            let end = min(doc.count, start + len)
            let slice = String(doc[doc.index(doc.startIndex, offsetBy: start)..<doc.index(doc.startIndex, offsetBy: end)])
            if slice.split(separator: " ").count < 2 {
                XCTAssertNil(CharSpan.resolve(chunk: slice, in: doc))
            }
        }
    }
}
