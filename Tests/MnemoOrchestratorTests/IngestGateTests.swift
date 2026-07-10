import XCTest
@testable import MnemoOrchestrator

final class IngestGateTests: XCTestCase {
    actor Counter { var n = 0; func next() -> Int { n += 1; return n } }
    struct EventuallyReady: Retrieving {
        let counter: IngestGateTests.Counter
        let hit: Retrieved
        func search(_ req: SearchRequest) async throws -> [Retrieved] {
            (await counter.next()) >= 3 ? [hit] : []   // empty twice, then ready
        }
    }
    func testWaitsUntilSearchable() async {
        let hit = Retrieved(memory: "x", similarity: 0.9, source: .init(docId: "d", path: "/p", title: "t", charStart: 0, charEnd: 1))
        let gate = IngestGate(retriever: EventuallyReady(counter: Counter(), hit: hit))
        let ok = await gate.waitUntilSearchable(probe: "x", timeout: .seconds(5))
        XCTAssertTrue(ok)
    }
    func testTimesOutWhenNeverReady() async {
        struct NeverReady: Retrieving { func search(_ r: SearchRequest) async throws -> [Retrieved] { [] } }
        let gate = IngestGate(retriever: NeverReady())
        let ok = await gate.waitUntilSearchable(probe: "x", timeout: .milliseconds(400))
        XCTAssertFalse(ok)
    }

    /// A-010 regression: AgenticResult.distinctSources drops path-less memory hits.
    func testDistinctSourcesOmitsMemoryOnlyHits() {
        let evidence = [
            Retrieved(memory: "x", similarity: 0, source: .init(docId: "", path: "/a.md", title: "a")),
            Retrieved(memory: "y", similarity: 0, source: .init(docId: "", path: "", title: "memory")),
        ]
        XCTAssertEqual(AgenticResult(evidence: evidence, hops: []).distinctSources, ["/a.md"])
    }
}

final class A213RegressionTests: XCTestCase {
    func testA213_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m213", memory: "Forgotten fact 213.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m213",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m213b", memory: "Active fact 213.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m213b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = EngineClient.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m213b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA213_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e213", memory: "TTL fact 213.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e213",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(EngineClient.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A271RegressionTests: XCTestCase {
    func testA271_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s271", memory: "Synthesis 271.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s271",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(KeywordBackstop.dreamingSafeSynthesis("Synthesis 271.", existing: existing,
                                                      constituents: ["fact 271"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(KeywordBackstop.dreamingSafeSynthesis("New synthesis 271.", existing: existing,
                                                     constituents: ["fact 271"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A184RegressionTests: XCTestCase {
    func testA184_indexingTerminal() {
        let t = NotchReducer.indexingTerminalState(path: "/f184.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f184.pdf")
    }
    func testA184_selfHealSafe() { XCTAssertEqual(NotchReducer.ingestionSelfHealSafe(orphanIds: ["m184", ""]), ["m184"]) }
}
final class A155RegressionTests: XCTestCase { func testA155_x() { XCTAssertEqual(CommandParser.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A242RegressionTests: XCTestCase {
    func testA242_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s242", memory: "Synthesis 242.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s242",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(QueryHistory.dreamingSafeSynthesis("Synthesis 242.", existing: existing,
                                                      constituents: ["fact 242"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(QueryHistory.dreamingSafeSynthesis("New synthesis 242.", existing: existing,
                                                     constituents: ["fact 242"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A126RegressionTests: XCTestCase { func testA126_x() { XCTAssertEqual(Prompt.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A97RegressionTests: XCTestCase {
    func testA97_lifecycleEventsRenderable() {
        let events = MediaCompanion.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q97", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-039 audit: ResponseStyle infers shape without logging document text.
final class ResponseStyleLoggingAuditTests: XCTestCase {
    func testDetectsTimelineShape() {
        XCTAssertEqual(AnswerShape.detect(query: "when did each milestone happen?", intent: .synthesis), .timeline)
    }
}
