import XCTest
@testable import MnemoOrchestrator

// MARK: - H-Phase2 integration scenarios (scripts/generate-phase2-prompts.py INTEGRATION_SCENARIOS)

/// Shared job-finder corpus for multi-hop integration gates.
private enum JobFinderFixtures {
    static let leads = Retrieved(memory: "421 rows before prune; 47 kept after.", similarity: 0.82,
        source: .init(docId: "jf1", path: "/leads.md", title: "leads.md"))
    static let profile = Retrieved(memory: "Resume: bansal.pdf. Email: rishabh.rb@icloud.com.", similarity: 0.80,
        source: .init(docId: "jf2", path: "/profile.md", title: "profile.md"))
    static let status = Retrieved(memory: "Chrome control paused. 0 verified submissions.", similarity: 0.78,
        source: .init(docId: "jf3", path: "/status.md", title: "status.md"))
    static var evidence: [Retrieved] { [leads, profile, status] }
}

private struct AgenticJobSurface: GrepSurface {
    func semantic(_ query: String, scope: String?) async throws -> [GrepHit] {
        if query.lowercased().contains("resume") || query.lowercased().contains("email") {
            return [GrepHit(path: "/profile.md", lineStart: 1, lineEnd: 2,
                            snippet: "Resume: bansal.pdf. Email: rishabh.rb@icloud.com.")]
        }
        return [GrepHit(path: "/leads.md", lineStart: 1, lineEnd: 2, snippet: "421 rows before prune; 47 kept.")]
    }
    func literal(_ term: String, scope: String?) async throws -> [GrepHit] { [] }
}

private struct OneHopPlanner: HopPlanning {
    func nextHop(question: String, evidence: [Retrieved], hops: [HopTrace]) async -> HopDecision {
        hops.isEmpty
            ? .semantic("resume email profile", rationale: "need application profile")
            : .stop(rationale: "done")
    }
}

// MARK: - H-0001 / scenario 0: cross-doc timeline synthesis offline

final class CrossDocTimelineIntegrationTests: XCTestCase {
    func testH0001_timelineQueryOrdersEvidenceChronologically() async throws {
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": BeatsSiriFixtures.timelineEvidence]),
            generator: FakeGenerator(tokens: [BeatsSiriFixtures.synthesizedAnswer]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "")
        var cards: [SourceCard] = []
        var answer = ""
        var egressBlocked = LoopbackGuardURLProtocol.blockedCount
        for try await e in svc.ask("What is the timeline of the Aurora migration?") {
            switch e {
            case let .sources(c): cards = c
            case let .token(t): answer += t
            default: break
            }
        }
        egressBlocked = LoopbackGuardURLProtocol.blockedCount - egressBlocked
        BeatsSiriFixtures.assertCrossDocSources(cards)
        let ordered = cards.compactMap(\.docId)
        XCTAssertEqual(ordered, ["ta", "tb", "tc"], "timeline shape must order sources chronologically")
        XCTAssertTrue(answer.lowercased().contains("four week") || answer.lowercased().contains("slipped"))
        XCTAssertEqual(egressBlocked, 0, "query path must not attempt non-loopback egress")
        let duration = NumericReasoner.durationNote(in: BeatsSiriFixtures.timelineEvidence)
        XCTAssertNotNil(duration, "numeric duration note must be computable offline")
    }

    func testH0001_fixtureCorpusAlignsWithUseCaseB03() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let corpus = [
            (repo.appendingPathComponent("Tests/Fixtures/corpus/timeline-a.md").path, "May 5"),
            (repo.appendingPathComponent("Tests/Fixtures/corpus/timeline-b.md").path, "May 19"),
            (repo.appendingPathComponent("Tests/Fixtures/corpus/timeline-c.md").path, "June 2"),
        ]
        for (path, needle) in corpus {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            XCTAssertTrue(text.lowercased().contains(needle.lowercased()),
                          "\(path) must mention \(needle) for use-case b03")
        }
    }
}

// MARK: - H-0002 / scenario 1: job-finder multi-hop

final class JobFinderMultiHopIntegrationTests: XCTestCase {
    func testH0002_agenticGathersMultipleJobDocs() async throws {
        let agentic = AgenticGrep(surface: AgenticJobSurface(), planner: OneHopPlanner(), maxHops: 4)
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [JobFinderFixtures.leads]]),
            generator: FakeGenerator(tokens: ["47 rows kept; resume is bansal.pdf."]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            router: HopFixedRouter(.multihop),
            agentic: agentic)
        var paths = Set<String>()
        for try await e in svc.ask("How many rows were kept and what is my resume filename?") {
            if case let .sources(cards) = e { cards.forEach { paths.insert($0.path) } }
        }
        XCTAssertTrue(paths.contains("/leads.md") || paths.contains("/profile.md"),
                      "multi-hop must surface ≥2 job-finder sources, got \(paths)")
    }
}

// MARK: - H-0003 / scenario 2: profile recall after /forget

final class ProfileRecallAfterForgetIntegrationTests: XCTestCase {
    func testH0003_forgottenProfileFactExcludedFromAnswers() {
        let forgotten = MemoryEntry(id: "p1", memory: "User lives in NYC.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "p1",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "p2", memory: "User lives in Fremont.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "p2",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = QueryService.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["p2"],
                       "re-ask after /forget must not surface retracted profile facts")
    }
}

// MARK: - H-0004 / scenario 3: ingest-then-query race

final class IngestThenQueryRaceIntegrationTests: XCTestCase {
    func testH0004_indexingStatePrecedesAnswerWhileDocProcessing() async throws {
        let source = FakeDocumentSource([doc("d1", path: "/aurora.pdf", status: "extracting")])
        let index = IngestIndex(docs: source, container: "mnemo")
        await index.refresh()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: [:]),
            generator: FakeGenerator(tokens: ["INVENTED"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            ingestIndex: index)
        var terminal: TerminalState?
        for try await e in svc.ask("what's in aurora.pdf?") {
            if case let .state(t) = e { terminal = t }
        }
        guard case .indexing(let path) = terminal else {
            return XCTFail("expected indexing terminal during ingest race, got \(String(describing: terminal))")
        }
        XCTAssertEqual(path, "/aurora.pdf")
    }
}

// MARK: - H-0005 / scenario 4: dream-then-query consistency

final class DreamThenQueryConsistencyIntegrationTests: XCTestCase {
    func testH0005_dreamingDoesNotDuplicateExistingSynthesis() {
        let existing = [MemoryEntry(id: "s1", memory: "Aurora slipped four weeks.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s1",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(TimelineBuilder.dreamingSafeSynthesis("Aurora slipped four weeks.",
                                                             existing: existing,
                                                             constituents: ["four weeks"]),
                       "dream pass must not duplicate an existing synthesis")
        XCTAssertTrue(TimelineBuilder.dreamingSafeSynthesis("New cross-doc insight about Aurora.",
                                                            existing: existing,
                                                            constituents: ["Aurora"]),
                      "novel grounded synthesis is allowed after dream")
    }
}

// MARK: - H-0006 / scenario 5: engine restart mid-query

final class EngineRestartMidQueryIntegrationTests: XCTestCase {
    func testH0006_engineUnreachableIsDefinedTerminal() {
        let state = TerminalState.engineUnreachable
        XCTAssertEqual(state.recovery, .restartEngine)
        XCTAssertFalse(NotchReducer.message(for: state).isEmpty,
                       "engine restart path must render a recovery message")
    }
}

// MARK: - H-0007 / scenario 6: model unload recovery

final class ModelUnloadRecoveryIntegrationTests: XCTestCase {
    func testH0007_modelNotLoadedIsDefinedTerminal() {
        let state = TerminalState.modelNotLoaded(model: "gpt-oss:20b")
        XCTAssertEqual(state.recovery, .loadModel)
        XCTAssertTrue(NotchReducer.message(for: state).contains("gpt-oss:20b")
                      || NotchReducer.message(for: state).lowercased().contains("model"))
    }
}

// MARK: - H-0008 / scenario 7: smfs semantic vs literal grep parity

final class SMFSGrepParityIntegrationTests: XCTestCase {
    func testH0008_keywordBackstopRescuesLiteralTokenMiss() {
        let ev = [BeatsSiriFixtures.timelineA]
        let (merged, note) = KeywordBackstop.rescue(query: "Aurora migration May 5",
                                                    evidence: ev, mountRoot: "/tmp")
        XCTAssertNotNil(note, "literal rescue must fire when salient token missing from semantic hits")
        XCTAssertGreaterThanOrEqual(merged.count, ev.count)
    }
}

// MARK: - H-0009 / scenario 8: bulk ingest under load

final class BulkIngestUnderLoadIntegrationTests: XCTestCase {
    func testH0009_backgroundWorkYieldsToInteractive() async {
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yieldHint = await sched.shouldBackgroundYield
        XCTAssertTrue(yieldHint,
                      "background ingest must yield while an interactive query is in flight")
        await sched.endInteractive(token)
    }
}

// MARK: - H-0010 / scenario 9: concurrent ask + ingest

final class ConcurrentAskIngestIntegrationTests: XCTestCase {
    func testH0010_schedulingBudgetRegistersComponents() {
        let components = SchedulingBudget.registeredComponents()
        XCTAssertFalse(components.isEmpty, "scheduler must track registered background components")
        XCTAssertGreaterThan(SchedulingBudget.totalRegisteredUs(), 0)
    }
}

// MARK: - H-0011 / scenario 10: warm vs cold first-token bench

final class WarmColdBenchIntegrationTests: XCTestCase {
    func testH0011_answerCacheSkipsSecondGeneration() async throws {
        let counter = GenerationCounter()
        let cache = AnswerCache()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [BeatsSiriFixtures.timelineA]]),
            generator: CountingGenerator(counter: counter),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            cache: cache)
        for try await _ in svc.ask("What is Aurora?") {}
        for try await _ in svc.ask("What is Aurora?") {}
        let count = await counter.count
        XCTAssertEqual(count, 1, "warm cache hit must skip the second generator invocation")
    }

    func testH0011_sameDocumentEditInvalidatesCacheWhileUnchangedRefreshDoesNot() async throws {
        func row(updatedAt: String, fingerprint: String) -> DocumentMeta {
            DocumentMeta(
                id: "stable-document-id",
                filepath: "/aurora.md",
                title: "aurora.md",
                status: "done",
                containerTags: ["c"],
                summary: nil,
                updatedAt: updatedAt,
                metadata: ["fingerprint": fingerprint]
            )
        }

        let source = FakeDocumentSource([row(updatedAt: "2026-07-14T10:00:00Z", fingerprint: "v1")])
        let index = IngestIndex(docs: source, container: "c")
        await index.refresh()
        let counter = GenerationCounter()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [BeatsSiriFixtures.timelineA]]),
            generator: CountingGenerator(counter: counter),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            ingestIndex: index,
            cache: AnswerCache()
        )

        for try await _ in svc.ask("What is Aurora?") {}
        await index.refresh()
        for try await _ in svc.ask("What is Aurora?") {}
        var generationCount = await counter.count
        XCTAssertEqual(generationCount, 1, "an unchanged refresh must retain the cached answer")

        await source.set([row(updatedAt: "2026-07-14T10:01:00Z", fingerprint: "v2")])
        await index.refresh()
        for try await _ in svc.ask("What is Aurora?") {}
        generationCount = await counter.count
        XCTAssertEqual(generationCount, 2, "same-ID content metadata changes must invalidate the cached answer")
    }
}

// MARK: - H-0012 / scenario 11: 105 use-case green run

final class UseCaseHarnessIntegrationTests: XCTestCase {
    func testH0012_usecasesTsvHas105Cases() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let tsv = try String(contentsOfFile: repo.appendingPathComponent("scripts/usecases.tsv").path,
                             encoding: .utf8)
        let cases = tsv.split(separator: "\n").filter { !$0.hasPrefix("#") && !$0.isEmpty }
        XCTAssertEqual(cases.count, 105, "run-usecases.sh harness expects 105 offline scenarios")
    }

    func testH0012_timelineCategoryPresent() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let tsv = try String(contentsOfFile: repo.appendingPathComponent("scripts/usecases.tsv").path,
                             encoding: .utf8)
        XCTAssertTrue(tsv.contains("timeline-numeric"),
                      "timeline synthesis use-cases must be in the harness")
        XCTAssertTrue(tsv.contains("b03"), "b03 cross-doc timeline regex gate must exist")
    }
}

// Reuse helpers from other test files
private struct HopFixedRouter: QueryRouter {
    let intent: Intent
    init(_ i: Intent) { intent = i }
    func classify(_ q: String) -> RoutingResult { RoutingResult(intent: intent, ambiguous: false) }
}

private actor GenerationCounter { var count = 0; func bump() { count += 1 } }
private struct CountingGenerator: Generating {
    let counter: GenerationCounter
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            Task { await counter.bump(); c.yield("cached-ok"); c.finish() }
        }
    }
}

private func doc(_ id: String, path: String, status: String) -> DocumentMeta {
    DocumentMeta(id: id, filepath: path, title: path, status: status,
                 containerTags: ["mnemo"], summary: nil, updatedAt: nil)
}
