import XCTest
import MnemoCore
@testable import MnemoOrchestrator

// Self-contained fakes so this test compiles/runs independently of the rest of
// the orchestrator test target.
private struct TraceRetriever: Retrieving {
    let hits: [Retrieved]
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        req.searchMode == "memories" ? hits : []
    }
}
private struct TraceGenerator: Generating {
    let tokens: [String]
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in for t in tokens { c.yield(t) }; c.finish() }
    }
}
private struct TraceDocs: DocumentFetching {
    func document(_ docId: String) async throws -> DocumentRecord? { nil }
}

/// Phase 2: with a DevTrace attached, a query emits the deep per-stage trace the
/// dashboard renders — route, candidate scores, the assembled prompt, streamed
/// tokens, and the final metrics — all sharing one queryId.
final class QueryServiceTracingTests: XCTestCase {
    func testEmitsDeepTraceStagesWithData() async throws {
        let hit = Retrieved(memory: "I moved to SF in 2021.", similarity: 0.82,
            source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 0, charEnd: 5))
        let trace = DevTrace()
        let stream = await trace.subscribe()
        let svc = QueryService(
            retriever: TraceRetriever(hits: [hit]),
            generator: TraceGenerator(tokens: ["I ", "live ", "in SF."]),
            spans: SpanResolver(docs: TraceDocs()),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            trace: trace)

        for try await _ in svc.ask("where do I live?") {}

        var stages: [String] = []
        var queryIds = Set<String>()
        var sawCandidates = false, sawPrompt = false, sawToken = false, sawMetrics = false
        for await ev in stream {
            stages.append(ev.stage)
            queryIds.insert(ev.queryId)
            if ev.stage == "gather.search", case let .object(o)? = ev.data, o["candidates"] != nil { sawCandidates = true }
            if ev.stage == "assemble", case let .object(o)? = ev.data, o["system"] != nil { sawPrompt = true }
            if ev.stage == "generate", ev.phase == "token" { sawToken = true }
            if ev.stage == "done", case let .object(o)? = ev.data, o["metrics"] != nil { sawMetrics = true }
            if ev.stage == "done" { break }
        }

        XCTAssertTrue(stages.contains("scope"), "stages: \(stages)")
        XCTAssertTrue(stages.contains("cache"), "cache hit/miss must be traced")
        XCTAssertTrue(stages.contains("route"), "stages: \(stages)")
        XCTAssertTrue(sawCandidates, "gather.search must carry candidate scores")
        XCTAssertTrue(sawPrompt, "assemble must carry the raw system prompt")
        XCTAssertTrue(sawToken, "generate must stream tokens")
        XCTAssertTrue(sawMetrics, "done must carry end-of-query metrics")
        XCTAssertEqual(queryIds.count, 1, "all trace events for one query share a queryId")
    }

    func testNoTraceEmittedWhenTraceIsNil() async throws {
        // The invariant: normal runs (trace: nil) get zero new observability.
        let trace = DevTrace()
        let stream = await trace.subscribe()
        let hit = Retrieved(memory: "x", similarity: 0.9, source: .init(docId: "d1", path: "/p", title: "t"))
        let svc = QueryService(
            retriever: TraceRetriever(hits: [hit]),
            generator: TraceGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: TraceDocs()),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "")   // no trace

        for try await _ in svc.ask("where do I live?") {}
        await trace.emit(TraceEvent(queryId: "sentinel", seq: 999, atMs: 0, stage: "sentinel", phase: "info"))

        var first: TraceEvent?
        for await ev in stream { first = ev; break }
        XCTAssertEqual(first?.stage, "sentinel", "a nil-trace query must emit nothing onto the bus")
    }
}
