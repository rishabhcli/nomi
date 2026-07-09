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

final class A227RegressionTests: XCTestCase {
    func testA227_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m227", memory: "Forgotten fact 227.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m227",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m227b", memory: "Active fact 227.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m227b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ContentHash.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m227b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA227_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e227", memory: "TTL fact 227.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e227",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ContentHash.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A140RegressionTests: XCTestCase {
    func testA140_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d140", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(NumericReasoner.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(NumericReasoner.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA140_unsupportedAnswerEvent() {
        XCTAssertEqual(NumericReasoner.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A111RegressionTests: XCTestCase {
    func testA111_lifecycleEventsRenderable() {
        let events = CitationVerifier.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q111", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}
final class A198RegressionTests: XCTestCase {
    func testA198_ingest() {
        XCTAssertEqual(QueryDecomposer.indexingTerminalState(path:"/a.pdf"),.indexing(path:"/a.pdf"))
        XCTAssertEqual(QueryDecomposer.ingestionSelfHealSafe(orphanIds:["x",""]),["x"])
    }
}
final class A169RegressionTests: XCTestCase { func testA169_x() { XCTAssertEqual(QueryService.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A256RegressionTests: XCTestCase {
    func testA256_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s256", memory: "Synthesis 256.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s256",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(Preferences.dreamingSafeSynthesis("Synthesis 256.", existing: existing,
                                                      constituents: ["fact 256"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(Preferences.dreamingSafeSynthesis("New synthesis 256.", existing: existing,
                                                     constituents: ["fact 256"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A82RegressionTests: XCTestCase {
    func testA82_lifecycleEventsRenderable() {
        let events = QueryDecomposer.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q82", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}
