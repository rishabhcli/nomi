import XCTest
@testable import MnemoOrchestrator

final class CompanionPathResolutionTests: XCTestCase {
    func testCompanionDocResolvesToOriginalMediaPath() async throws {
        // A companion document has no engine filepath; its citation must point
        // at the ORIGINAL media file recorded in metadata.
        let hit = Retrieved(memory: "The Orion project kickoff was moved to September 14.",
                            similarity: 0.9,
                            source: .init(docId: "c1", path: "", title: "fixture-scanned.pdf"))
        let record = DocumentRecord(
            content: "# fixture-scanned.pdf\n\nThe Orion project kickoff was moved to September 14.",
            filepath: nil,
            metadata: [MediaCompanion.originalPathKey: "/fixture-scanned.pdf"])
        let resolver = SpanResolver(docs: FakeDocsStore(records: ["c1": record]))
        let out = await resolver.resolve([hit])
        XCTAssertEqual(out[0].source.path, "/fixture-scanned.pdf")
    }
}

final class SpanResolverTests: XCTestCase {
    actor FetchCounter {
        var count = 0
        func bump() { count += 1 }
    }

    struct FakeDocs: DocumentFetching {
        let records: [String: DocumentRecord]
        let counter: FetchCounter?
        func document(_ docId: String) async throws -> DocumentRecord? {
            await counter?.bump()
            return records[docId]
        }
    }

    func testResolvesRealOffsets() async throws {
        let doc = "Intro line.\n\nMy favorite build tool is Bazel.\n\nOutro."
        let fake = FakeDocs(records: ["d1": DocumentRecord(content: doc, filepath: "/f.md")], counter: nil)
        var hit = Retrieved(memory: "My favorite build tool is Bazel.", similarity: 0.9,
                            source: .init(docId: "d1", path: "/f.md", title: "f"))
        let resolved = await SpanResolver(docs: fake).resolve([hit])
        hit = resolved[0]
        let start = try XCTUnwrap(hit.source.charStart)
        let end = try XCTUnwrap(hit.source.charEnd)
        XCTAssertEqual(doc.substring(charRange: start..<end), "My favorite build tool is Bazel.")
    }

    func testFillsMissingPathFromDocumentRecord() async throws {
        let fake = FakeDocs(records: ["d1": DocumentRecord(content: "alpha", filepath: "/notes/f.md")], counter: nil)
        let hit = Retrieved(memory: "alpha", similarity: 0.9,
                            source: .init(docId: "d1", path: "", title: "t"))
        let resolved = await SpanResolver(docs: fake).resolve([hit])
        XCTAssertEqual(resolved[0].source.path, "/notes/f.md")
    }

    func testFetchesEachDocumentOnce() async throws {
        let counter = FetchCounter()
        let fake = FakeDocs(records: ["d1": DocumentRecord(content: "alpha beta gamma", filepath: nil)], counter: counter)
        let hits = [
            Retrieved(memory: "alpha", similarity: 0.9, source: .init(docId: "d1", path: "", title: "t")),
            Retrieved(memory: "gamma", similarity: 0.8, source: .init(docId: "d1", path: "", title: "t")),
        ]
        _ = await SpanResolver(docs: fake).resolve(hits)
        let fetches = await counter.count
        XCTAssertEqual(fetches, 1)
    }

    func testUnresolvableSpanStaysNil() async {
        let fake = FakeDocs(records: [:], counter: nil)
        let hits = [Retrieved(memory: "text", similarity: 0.9, source: .init(docId: "missing", path: "", title: "t"))]
        let resolved = await SpanResolver(docs: fake).resolve(hits)
        XCTAssertNil(resolved[0].source.charStart)
        XCTAssertNil(resolved[0].source.charEnd)
    }
}
