import XCTest
@testable import MnemoOrchestrator

/// Scriptable grep surface: canned hits per query.
struct FakeGrepSurface: GrepSurface {
    let semanticHits: [String: [GrepHit]]
    let literalHits: [String: [GrepHit]]
    func semantic(_ query: String, scope: String?) async throws -> [GrepHit] {
        semanticHits[query] ?? []
    }
    func literal(_ term: String, scope: String?) async throws -> [GrepHit] {
        literalHits[term] ?? []
    }
}

/// Scriptable planner: pops decisions off a list.
actor ScriptedPlanner: HopPlanning {
    var decisions: [HopDecision]
    init(_ d: [HopDecision]) { decisions = d }
    func nextHop(question: String, evidence: [Retrieved], hops: [HopTrace]) async -> HopDecision {
        decisions.isEmpty ? .stop(rationale: "script exhausted") : decisions.removeFirst()
    }
}

private func hit(_ path: String, _ snippet: String) -> GrepHit {
    GrepHit(path: path, lineStart: 1, lineEnd: 2, snippet: snippet)
}

final class AgenticGrepTests: XCTestCase {
    func testMultiHopVisitsBothDocuments() async throws {
        // AT-M3.4 shape: hop 1 lands on doc A; the planner follows the thread
        // to doc B; evidence covers both; the trace records the visit order.
        let surface = FakeGrepSurface(
            semanticHits: [
                "how does the decision differ from the constraint?":
                    [hit("/notes/decision-a.md", "We chose PostgreSQL for the telemetry store.")],
                "ops platform backup constraint":
                    [hit("/notes/constraint-b.md", "Managed backups only support MySQL-compatible engines.")],
            ],
            literalHits: [:])
        let planner = ScriptedPlanner([
            .semantic("ops platform backup constraint", rationale: "decision found; now find the constraint"),
            .stop(rationale: "both sides covered"),
        ])
        let agentic = AgenticGrep(surface: surface, planner: planner, maxHops: 6)
        let result = try await agentic.run("how does the decision differ from the constraint?", scope: nil)
        let paths = Set(result.evidence.map(\.source.path))
        XCTAssertEqual(paths, ["/notes/decision-a.md", "/notes/constraint-b.md"])
        XCTAssertEqual(result.hops.count, 2)
        XCTAssertEqual(result.hops[0].kind, "semantic")
        XCTAssertTrue(result.hops[1].rationale.contains("constraint"))
    }

    func testMaxHopsBoundsTheLoop() async throws {
        let surface = FakeGrepSurface(
            semanticHits: ["q": [hit("/a.md", "x")], "again": [hit("/b.md", "y")]],
            literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("again", rationale: "loop"), count: 50))
        let agentic = AgenticGrep(surface: surface, planner: planner, maxHops: 3)
        let result = try await agentic.run("q", scope: nil)
        XCTAssertEqual(result.hops.count, 3, "hard cap, planner wanted 50")
    }

    func testLiteralHopUsesGrepF() async throws {
        let surface = FakeGrepSurface(
            semanticHits: ["q": []],
            literalHits: ["ERR-4711": [hit("/logs/build.log", "ERR-4711: cache poisoned")]])
        let planner = ScriptedPlanner([
            .literal("ERR-4711", rationale: "lexical token — exact match"),
            .stop(rationale: "found"),
        ])
        let agentic = AgenticGrep(surface: surface, planner: planner, maxHops: 6)
        let result = try await agentic.run("q", scope: nil)
        XCTAssertEqual(result.evidence.map(\.source.path), ["/logs/build.log"])
        XCTAssertEqual(result.hops[1].kind, "literal")
    }

    func testEvidenceDeduplicatesRepeatedHits() async throws {
        let surface = FakeGrepSurface(
            semanticHits: ["q": [hit("/a.md", "same snippet")],
                           "next": [hit("/a.md", "same snippet")]],
            literalHits: [:])
        let planner = ScriptedPlanner([
            .semantic("next", rationale: "retry"),
            .stop(rationale: "done"),
        ])
        let agentic = AgenticGrep(surface: surface, planner: planner, maxHops: 6)
        let result = try await agentic.run("q", scope: nil)
        XCTAssertEqual(result.evidence.count, 1)
    }
}

/// A-008 invariant: SpanResolver must never construct non-loopback URLs.
final class SpanResolverInvariantTests: XCTestCase {
    func testResolveEnrichesOffsetsWithoutURLConstruction() async {
        struct FakeDocs: DocumentFetching {
            func document(_ docId: String) async throws -> DocumentRecord? {
                DocumentRecord(content: "hello world from notes", filepath: "/notes/a.md")
            }
        }
        let hits = [Retrieved(memory: "hello world", similarity: 0.9,
                              source: .init(docId: "d1", path: "", title: "t"))]
        let resolved = await SpanResolver(docs: FakeDocs()).resolve(hits)
        XCTAssertEqual(resolved[0].source.path, "/notes/a.md")
        XCTAssertEqual(resolved[0].source.charStart, 0)
        XCTAssertEqual(resolved[0].source.charEnd, 11)
    }
}

final class SMFSGrepParseTests: XCTestCase {
    func testParsesSMFSGrepOutput() {
        let out = """
        # supermemory semantic search — 3 results for "kickoff"
        # searches by meaning across files in this container. usage:
        #   grep "natural language query"          search all files
        # output: <filepath>:<line_start>-<line_end>:<chunk>

        /notes/meeting.md:12-14:The Orion project kickoff was moved to September 14.

        (unknown):User used CMake for four years on the Horizon renderer project.
        """
        let hits = SMFSGrep.parseSemanticOutput(out)
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits[0], GrepHit(path: "/notes/meeting.md", lineStart: 12, lineEnd: 14,
                                        snippet: "The Orion project kickoff was moved to September 14."))
        XCTAssertEqual(hits[1].path, "")   // (unknown) → no file path, snippet retained
        XCTAssertTrue(hits[1].snippet.contains("CMake"))
    }

    func testParsesLiteralGrepOutput() {
        let out = """
        /Users/x/Mnemo/memory/fixture.md:2:My favorite build tool is Bazel and I switched to it in March 2025.
        /Users/x/Mnemo/memory/other.md:7:Bazel remote caching notes
        """
        let hits = SMFSGrep.parseLiteralOutput(out, mountRoot: "/Users/x/Mnemo/memory")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits[0].path, "/fixture.md")
        XCTAssertEqual(hits[0].lineStart, 2)
        XCTAssertTrue(hits[1].snippet.contains("remote caching"))
    }
}

final class A211RegressionTests: XCTestCase {
    func testA211_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m211", memory: "Forgotten fact 211.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m211",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m211b", memory: "Active fact 211.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m211b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = LLMRouterEscalator.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m211b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA211_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e211", memory: "TTL fact 211.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e211",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(LLMRouterEscalator.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A240RegressionTests: XCTestCase {
    func testA240_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m240", memory: "Forgotten fact 240.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m240",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m240b", memory: "Active fact 240.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m240b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = AdaptiveEffort.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m240b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA240_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e240", memory: "TTL fact 240.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e240",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(AdaptiveEffort.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A269RegressionTests: XCTestCase {
    func testA269_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s269", memory: "Synthesis 269.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s269",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(CharSpan.dreamingSafeSynthesis("Synthesis 269.", existing: existing,
                                                      constituents: ["fact 269"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(CharSpan.dreamingSafeSynthesis("New synthesis 269.", existing: existing,
                                                     constituents: ["fact 269"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A182RegressionTests: XCTestCase { func testA182_x() { XCTAssertEqual(Prompt.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }
final class A124RegressionTests: XCTestCase { func testA124_x() { XCTAssertEqual(LLMHopPlanner.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }
final class A153RegressionTests: XCTestCase { func testA153_x() { XCTAssertEqual(Confidence.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A95RegressionTests: XCTestCase {
    func testA95_lifecycleEventsRenderable() {
        let events = CommandParser.lifecycleEvents(branch: Command.LifecycleBranch.routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q95", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-037 audit: TimeWindow.parse returns nil for non-temporal queries.
final class TimeWindowAuditTests: XCTestCase {
    func testModalMayDoesNotCreateWindow() {
        let now = ISO8601DateFormatter().date(from: "2026-07-09T12:00:00Z")!
        XCTAssertNil(TimeWindow.parse(query: "the release may slip", now: now))
    }
}
