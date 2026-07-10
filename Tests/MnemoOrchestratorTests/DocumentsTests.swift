import XCTest
@testable import MnemoOrchestrator

final class ItemStateTests: XCTestCase {
    func testEngineStatusMapping() {
        XCTAssertEqual(ItemState(engineStatus: "queued"), .queued)
        XCTAssertEqual(ItemState(engineStatus: "unknown"), .queued)
        XCTAssertEqual(ItemState(engineStatus: "extracting"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "chunking"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "embedding"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "indexing"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "done"), .ready)
        XCTAssertEqual(ItemState(engineStatus: "failed"), .error)
    }

    func testTerminalFlags() {
        XCTAssertTrue(ItemState.ready.isTerminal)
        XCTAssertTrue(ItemState.error.isTerminal)
        XCTAssertFalse(ItemState.queued.isTerminal)
        XCTAssertFalse(ItemState.processing.isTerminal)
    }
}

final class DocumentsDecodeTests: XCTestCase {
    // Captured from the live engine: POST /v3/documents/list
    static let listJSON = """
    {"memories":[{"connectionId":null,"containerTags":["mnemo"],"createdAt":"2026-07-08T17:22:10.125Z",
      "customId":null,"filepath":"/fixture.md","id":"m6eJLdtZcFFQ7B4dVBePXg",
      "metadata":{"lastEditedBy":"vk","source":"supermemoryfs"},"status":"done","summary":null,
      "title":"# Build tooling notes",
      "type":"text","updatedAt":"2026-07-08T17:23:26.452Z","url":null}],
     "pagination":{"currentPage":1,"limit":10,"totalItems":1,"totalPages":1}}
    """

    func testDecodesDocumentList() throws {
        let page = try JSONDecoder().decode(EngineClient.DocumentListPage.self, from: Data(Self.listJSON.utf8))
        XCTAssertEqual(page.memories.count, 1)
        let d = page.memories[0]
        XCTAssertEqual(d.id, "m6eJLdtZcFFQ7B4dVBePXg")
        XCTAssertEqual(d.filepath, "/fixture.md")
        XCTAssertEqual(d.status, "done")
        XCTAssertEqual(d.state, .ready)
        XCTAssertEqual(page.pagination.totalPages, 1)
    }
}

final class A229RegressionTests: XCTestCase {
    func testA229_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m229", memory: "Forgotten fact 229.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m229",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m229b", memory: "Active fact 229.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m229b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ConflictDetector.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m229b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA229_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e229", memory: "TTL fact 229.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e229",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ConflictDetector.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A113RegressionTests: XCTestCase {
    func testA113_lifecycleEventsRenderable() {
        let events = CharSpan.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q113", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .emptyEvidence")
    }
}

final class A142RegressionTests: XCTestCase {
    func testA142_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d142", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(TimelineBuilder.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(TimelineBuilder.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA142_unsupportedAnswerEvent() {
        XCTAssertEqual(TimelineBuilder.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}
final class A200RegressionTests: XCTestCase {
    func testA200_ingest() {
        XCTAssertEqual(AdaptiveEffort.indexingTerminalState(path:"/a.pdf"),.indexing(path:"/a.pdf"))
        XCTAssertEqual(AdaptiveEffort.ingestionSelfHealSafe(orphanIds:["x",""]),["x"])
    }
}

final class A258RegressionTests: XCTestCase {
    func testA258_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s258", memory: "Synthesis 258.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s258",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(Highlight.dreamingSafeSynthesis("Synthesis 258.", existing: existing,
                                                      constituents: ["fact 258"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(Highlight.dreamingSafeSynthesis("New synthesis 258.", existing: existing,
                                                     constituents: ["fact 258"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A171RegressionTests: XCTestCase { func testA171_x() { XCTAssertEqual(LLMRouterEscalator.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A84RegressionTests: XCTestCase {
    func testA84_lifecycleEventsRenderable() {
        let events = AdaptiveEffort.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q84", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-026: EgressGuard classifies loopback hosts for the M10 invariant.
final class EgressGuardAuditTests: XCTestCase {
    func testRejectsSpoofedLoopbackHosts() {
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
    }
}
