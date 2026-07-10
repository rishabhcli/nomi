import XCTest
@testable import MnemoOrchestrator

final class HopPlannerParseTests: XCTestCase {
    func testParsesSemanticDecision() {
        let d = LLMHopPlanner.parse(#"{"action":"semantic","query":"ops backup constraint","rationale":"find the other side"}"#)
        XCTAssertEqual(d, .semantic("ops backup constraint", rationale: "find the other side"))
    }

    func testParsesLiteralAndStop() {
        XCTAssertEqual(LLMHopPlanner.parse(#"{"action":"literal","query":"ERR-4711","rationale":"exact token"}"#),
                       .literal("ERR-4711", rationale: "exact token"))
        XCTAssertEqual(LLMHopPlanner.parse(#"{"action":"stop","rationale":"covered"}"#),
                       .stop(rationale: "covered"))
    }

    func testExtractsJSONEmbeddedInProse() {
        let d = LLMHopPlanner.parse("Sure! Here's my decision:\n```json\n{\"action\":\"stop\",\"rationale\":\"done\"}\n```")
        XCTAssertEqual(d, .stop(rationale: "done"))
    }

    func testGarbageFallsBackToStop() {
        XCTAssertEqual(LLMHopPlanner.parse("I think we should keep looking around"),
                       .stop(rationale: "planner output unparseable"))
    }

    func testPlannerUsesGeneratorOutput() async {
        let gen = FakeGenerator(tokens: [#"{"action":"semantic","query":"timeline note C","rationale":"third doc missing"}"#])
        let planner = LLMHopPlanner(generator: gen)
        let d = await planner.nextHop(question: "reconcile the timeline", evidence: [], hops: [])
        XCTAssertEqual(d, .semantic("timeline note C", rationale: "third doc missing"))
    }
}

final class A226RegressionTests: XCTestCase {
    func testA226_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m226", memory: "Forgotten fact 226.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m226",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m226b", memory: "Active fact 226.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m226b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = SyncEngine.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m226b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA226_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e226", memory: "TTL fact 226.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e226",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(SyncEngine.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A255RegressionTests: XCTestCase {
    func testA255_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s255", memory: "Synthesis 255.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s255",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(Digest.dreamingSafeSynthesis("Synthesis 255.", existing: existing,
                                                      constituents: ["fact 255"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(Digest.dreamingSafeSynthesis("New synthesis 255.", existing: existing,
                                                     constituents: ["fact 255"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A139RegressionTests: XCTestCase {
    func testA139_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d139", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(PersonalRanker.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(PersonalRanker.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA139_unsupportedAnswerEvent() {
        XCTAssertEqual(PersonalRanker.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A168RegressionTests: XCTestCase {
    func testA168_indexingTerminal() {
        let t = LLMHopPlanner.indexingTerminalState(path: "/f168.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f168.pdf")
    }
    func testA168_selfHealSafe() {
        XCTAssertEqual(LLMHopPlanner.ingestionSelfHealSafe(orphanIds: ["m168", ""]), ["m168"])
    }
}

final class A110RegressionTests: XCTestCase {
    func testA110_lifecycleEventsRenderable() {
        let events = ContainerCatalog.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q110", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}
final class A197RegressionTests: XCTestCase {
    func testA197_ingest() {
        XCTAssertEqual(LLMQueryRewriter.indexingTerminalState(path:"/a.pdf"),.indexing(path:"/a.pdf"))
        XCTAssertEqual(LLMQueryRewriter.ingestionSelfHealSafe(orphanIds:["x",""]),["x"])
    }
}

final class A81RegressionTests: XCTestCase {
    func testA81_lifecycleEventsRenderable() {
        let events = LLMQueryRewriter.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q81", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-023 invariant: LLMSynthesizer uses Generating only, not URLs.
final class LLMSynthesizerInvariantTests: XCTestCase {
    func testSynthesizerReturnsNilOnEmptyGeneratorOutput() async {
        struct EmptyGen: Generating {
            func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
                AsyncThrowingStream { $0.finish() }
            }
        }
        let synth = LLMSynthesizer(generator: EmptyGen())
        let result = await synth.synthesize([])
        XCTAssertNil(result, "empty generator output must not trap")
    }
}
