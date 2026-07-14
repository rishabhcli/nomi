import XCTest
@testable import MnemoOrchestrator

// MARK: - G-0001 EvidenceGathering: mutation testing mindset

private struct ContainerRetriever: Retrieving {
    let main: [Retrieved]
    let chat: [Retrieved]
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        req.container == "c-chat" ? chat : main
    }
}

private func egHit(_ id: String, _ text: String, _ sim: Double,
                   charStart: Int? = nil, charEnd: Int? = nil) -> Retrieved {
    Retrieved(memory: text, similarity: sim,
              source: .init(docId: id, path: "/\(id).md", title: id,
                            charStart: charStart, charEnd: charEnd))
}

private struct DecompThenEscalateRetriever: Retrieving {
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        if req.searchMode == "hybrid", req.limit == 24 {
            return [egHit("d3", "One broad hybrid hit.", 0.85)]
        }
        if req.q.lowercased().contains("build tool") {
            return [egHit("d1", "Bazel is the build tool.", 0.30)]
        }
        if req.q.lowercased().contains("adopt") {
            return [egHit("d2", "Adopted in March 2025.", 0.35)]
        }
        return []
    }
}

private struct MemoryPlusChunkRetriever: Retrieving, DocumentSearching {
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        [egHit("d1", "distilled memory summary", 0.40)]
    }
    func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        [Retrieved(memory: "verbatim chunk with TOKEN-XYZZY", similarity: 0.90,
                   source: .init(docId: "d1", path: "/d1.md", title: "d1",
                                 charStart: 100, charEnd: 140))]
    }
}

private enum ProbeError: Error { case boom }

private struct ThrowingDocRetriever: Retrieving, DocumentSearching {
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        [egHit("memory", "memory fallback remains usable", 0.75)]
    }
    func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        throw ProbeError.boom
    }
}

private actor DocumentProbeRecorder {
    private(set) var count = 0
    func record() { count += 1 }
}

private struct HybridDocumentRetriever: Retrieving, DocumentSearching {
    let recorder: DocumentProbeRecorder
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        [egHit("hybrid", "hybrid already returned the document passage", 0.88)]
    }
    func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        await recorder.record()
        return []
    }
}

private actor FallbackProbeRecorder {
    private(set) var modes: [String] = []
    private(set) var documentProbes = 0
    func recordMode(_ mode: String) { modes.append(mode) }
    func recordDocumentProbe() { documentProbes += 1 }
}

private struct MemoryFallbackHybridRetriever: Retrieving, DocumentSearching {
    let recorder: FallbackProbeRecorder
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        await recorder.recordMode(req.searchMode)
        return req.searchMode == "hybrid"
            ? [egHit("hybrid", "hybrid fallback returned the passage", 0.88)]
            : []
    }
    func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        await recorder.recordDocumentProbe()
        return []
    }
}

private struct CancellingDocumentRetriever: Retrieving, DocumentSearching {
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        [egHit("seed", "seed memory", 0.8)]
    }
    func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        throw CancellationError()
    }
}

private struct ThrowingGrepSurface: GrepSurface {
    func semantic(_ query: String, scope: String?) async throws -> [GrepHit] { throw ProbeError.boom }
    func literal(_ term: String, scope: String?) async throws -> [GrepHit] { [] }
}

private struct StopPlanner: HopPlanning {
    func nextHop(question: String, evidence: [Retrieved], hops: [HopTrace]) async -> HopDecision {
        .stop(rationale: "done")
    }
}

final class G0001EvidenceGatheringTests: XCTestCase {
    func testEscalationMergesIntoDecomposedHitsInsteadOfReplacing() async throws {
        let svc = QueryService(
            retriever: DecompThenEscalateRetriever(),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "")
        let gathered = try await svc.gatherEvidence(
            "what is my build tool and when did I adopt it?", intent: .synthesis)
        let ids = Set(gathered.hits.map(\.source.docId))
        XCTAssertTrue(ids.contains("d1"), "sub-question A evidence must survive escalation")
        XCTAssertTrue(ids.contains("d2"), "sub-question B evidence must survive escalation")
        XCTAssertTrue(ids.contains("d3"), "broadened hybrid hit must be included")
        XCTAssertTrue(gathered.broadened)
    }

    func testDocumentChunkNotDroppedWhenMemorySharesDocId() async throws {
        let svc = QueryService(
            retriever: MemoryPlusChunkRetriever(),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", documentSearchEnabled: true)
        let gathered = try await svc.gatherEvidence("find TOKEN-XYZZY", intent: .lookup)
        XCTAssertTrue(
            gathered.hits.contains { $0.memory.contains("TOKEN-XYZZY") },
            "chunk-level evidence must not be deduped away by a memory on the same docId")
    }

    func testHybridSearchDoesNotRepeatTheDocumentEndpoint() async throws {
        let recorder = DocumentProbeRecorder()
        let svc = QueryService(
            retriever: HybridDocumentRetriever(recorder: recorder),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "hybrid", rerank: true,
                                     threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", documentSearchEnabled: true)

        _ = try await svc.gatherEvidence("find the passage", intent: .lookup)

        let probeCount = await recorder.count
        XCTAssertEqual(probeCount, 0)
    }

    func testMemoriesToHybridFallbackDoesNotRepeatTheDocumentEndpoint() async throws {
        let recorder = FallbackProbeRecorder()
        let svc = QueryService(
            retriever: MemoryFallbackHybridRetriever(recorder: recorder),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", documentSearchEnabled: true)

        _ = try await svc.gatherEvidence("find the passage", intent: .lookup)

        let modes = await recorder.modes
        let probeCount = await recorder.documentProbes
        XCTAssertEqual(Array(modes.prefix(2)), ["memories", "hybrid"])
        XCTAssertEqual(probeCount, 0,
                       "hybrid fallback already searched document chunks")
    }

    func testDocumentSearchCancellationPropagates() async throws {
        let svc = QueryService(
            retriever: CancellingDocumentRetriever(),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", documentSearchEnabled: true)

        do {
            _ = try await svc.gatherEvidence("find the seed", intent: .lookup)
            XCTFail("document-search cancellation must not be downgraded to an unavailable probe")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testShortQueryEchoIsExcludedFromChatRecall() async throws {
        let q = "why slip?"
        let svc = QueryService(
            retriever: ContainerRetriever(
                main: [egHit("d1", "Aurora slipped two weeks.", 0.9)],
                chat: [egHit("t1", "[USER]\n\(q)\n[ASSISTANT]\nno idea", 0.95)]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: false, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            chatRecallEnabled: true)
        var sources: [SourceCard] = []
        for try await e in svc.ask(q) { if case let .sources(c) = e { sources = c } }
        XCTAssertFalse(
            sources.contains { $0.title == QueryService.chatRecallTitle },
            "transcript echo of the current short query must not become evidence")
    }

    func testDocumentSearchFailureLeavesRoomForLocalFallback() async throws {
        let svc = QueryService(
            retriever: ThrowingDocRetriever(),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", documentSearchEnabled: true)
        let gathered = try await svc.gatherEvidence("only in chunks", intent: .lookup)
        XCTAssertEqual(gathered.hits.map(\.source.docId), ["memory"])
        XCTAssertTrue(gathered.steps.contains("Document search unavailable for this sub-question"))
    }

    func testAgenticFailurePropagatesOnMultihop() async throws {
        let agentic = AgenticGrep(surface: ThrowingGrepSurface(), planner: StopPlanner(), maxHops: 4)
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [egHit("m1", "seed", 0.55)]]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            router: FixedRouter(.multihop),
            agentic: agentic)
        do {
            _ = try await svc.gatherEvidence("cross-file question", intent: .multihop)
            XCTFail("agentic errors must not be swallowed")
        } catch is ProbeError { }
    }
}

// MARK: - G-0002 CitationVerifier: regression fixture expansion

final class G0002CitationVerifierTests: XCTestCase {
    let evidence = [
        Retrieved(memory: "My favorite build tool is Bazel and I switched in March 2025.",
                  similarity: 0.9, source: .init(docId: "d1", path: "/f.md", title: "Build notes")),
    ]

    func testSubThreeCharClaimsAreStillVerified() async {
        let backend = StubVerifierBackend(similarity: { _, _ in 0.0 }, entails: { _, _ in false })
        let verifier = CitationVerifier(backend: backend, simThreshold: 0.5)
        let v1 = await verifier.verify(answer: "Ox [bogus]", evidence: evidence)
        XCTAssertFalse(v1[0].supported, "2-char stripped claim must not auto-pass")
    }

    func testAllUnsupportedUsesStrippedClaimLength() async {
        let backend = StubVerifierBackend(similarity: { _, _ in 0.0 }, entails: { _, _ in false })
        let verdicts = await CitationVerifier(backend: backend)
            .verify(answer: "Q. Z.", evidence: evidence)
        XCTAssertTrue(CitationVerifier.allUnsupported(verdicts),
                      "wholly ungrounded answer must reach unsupportedAnswer")
    }

    func testKeepsHonorificAndInitialAbbreviations() {
        XCTAssertEqual(
            Sentences.split("I met Dr. Smith at the office."),
            ["I met Dr. Smith at the office."])
        XCTAssertEqual(
            Sentences.split("See Fig. 3 in the appendix."),
            ["See Fig. 3 in the appendix."])
    }

    func testDreamingRejectsSynthesisWithoutConstituents() {
        let existing = [MemoryEntry(id: "m1", memory: "Bazel is the build tool.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m1",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(
            CitationVerifier.dreamingSafeSynthesis(
                "Invented synthesis with no grounding.", existing: existing, constituents: []))
    }

    func testInvalidForgetAfterIsNotActive() {
        let entry = MemoryEntry(id: "bad-ttl", memory: "Should have expired.", version: 1,
                                isLatest: true, isForgotten: false, isStatic: false,
                                parentMemoryId: nil, rootMemoryId: "bad-ttl",
                                forgetAfter: "not-a-date", forgetReason: nil, history: [])
        XCTAssertFalse(CitationVerifier.memoryDynamicsActive(entry))
    }
}

// MARK: - G-0003 AgenticGrep: BS-M12 transcript audit

final class G0003AgenticGrepTests: XCTestCase {
    func testResolveUnknownHitsPicksLongestTitleMatch() {
        let docs = [
        DocumentMeta(id: "o1", filepath: "/orion.md", title: "Orion", status: "done",
                     containerTags: nil, summary: nil, updatedAt: nil),
        DocumentMeta(id: "k1", filepath: "/kickoff.md", title: "Orion project kickoff", status: "done",
                     containerTags: nil, summary: nil, updatedAt: nil),
        ]
        let hit = GrepHit(path: "", lineStart: nil, lineEnd: nil,
                          snippet: "The Orion project kickoff was moved")
        let resolved = SMFSGrep.resolveUnknownHits([hit], docs: docs)
        XCTAssertEqual(resolved[0].path, "/kickoff.md",
                       "longest title match must win to avoid flaky path assignment")
    }

    func testChunkTextWithColonsParsesCorrectly() {
        let out = "/notes/a.md:10-12:ratio is 3:1 for the build"
        let hits = SMFSGrep.parseSemanticOutput(out)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].snippet, "ratio is 3:1 for the build")
    }
}

// MARK: - G-0004 ContextAssembler: invariant property tests

final class G0004ContextAssemblerTests: XCTestCase {
    func testProfileMemoriesIncludedInAssembledEvidence() {
        let profileMemory = Retrieved(memory: "User's Mnemo container is tagged personal.", similarity: 0.88,
                                      source: .init(docId: "pm", path: "/p.md", title: "profile"))
        let profile = Profile(statics: [], dynamics: [], memories: [profileMemory])
        let ctx = ContextAssembler(tokenBudget: 4000).assemble(
            intent: .lookup, question: "container?", profile: profile, evidence: [])
        XCTAssertEqual(ctx.evidence.count, 1)
        XCTAssertTrue(ctx.evidence[0].memory.contains("personal"))
    }
}

// MARK: - G-0005 EgressGuard: egress injection attempts

final class G0005EgressGuardTests: XCTestCase {
    func testEgressViolationPersistsAcrossQueryWindows() async {
        let g = EgressGuard()
        let w1 = await g.beginQueryWindow()
        await g.recordAttempt(host: "api.supermemory.ai")
        let n1 = await g.outboundNonLoopbackAttempts
        XCTAssertEqual(n1, 1)
        let clean1 = await g.isClean()
        XCTAssertFalse(clean1)
        await g.endWindow(w1)

        let w2 = await g.beginQueryWindow()
        let n2 = await g.outboundNonLoopbackAttempts
        XCTAssertEqual(n2, 1,
                       "beginQueryWindow must not reset session egress count")
        let clean2 = await g.isClean()
        XCTAssertFalse(clean2)
        let indicator = await PrivacyIndicator.from(g)
        XCTAssertEqual(indicator, .egressDetected(count: 1))
        await g.endWindow(w2)
    }
}

// MARK: - Phase 2 module property invariants (G-0006..G-1000 audit harness)

final class Phase2ModulePropertyTests: XCTestCase {
    func testLoopbackSpoofHostnamesRejected() {
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.attacker.net"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
    }

    func testCommandParserSlashCommandsNeverEmpty() {
        for cmd in ["/help", "/clear", "/inspect", "/profile", "/more", "/why", "/preferences"] {
            if case .command(let c) = CommandParser.parse(cmd) {
                XCTAssertNotEqual(String(describing: c), "")
            } else {
                XCTFail("\(cmd) must parse as command")
            }
        }
    }

    func testScopeClassifierGreetingsBypassRetrieval() {
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("hi"))
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("thanks"))
        XCTAssertTrue(ScopeClassifier.isCorpusQuestion("what is my build tool?"))
    }

    func testQueryDecomposerDoesNotSplitNonClauses() {
        XCTAssertEqual(QueryDecomposer.split("Bazel and CMake").count, 1)
    }

    func testTimeWindowNeverStrandsOnEmptyFilter() {
        let old = Retrieved(memory: "old fact", similarity: 0.5,
                            source: .init(docId: "d", path: "/f.md", title: "f",
                                          updatedAt: "2000-01-01T00:00:00Z"))
        let w = TimeWindow.parse(query: "yesterday", now: Date())!
        XCTAssertFalse(TimeWindow.filter([old], to: w).isEmpty)
    }

    func testCoverageEscalateRelaxesThreshold() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true, threshold: 0.4, limit: 10, container: "c")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
        XCTAssertLessThan(esc.threshold, base.threshold)
        XCTAssertGreaterThan(esc.limit, base.limit)
    }

    func testConversationIdNeverTrapsOnIntMin() {
        // Regression for abs(hashValue) trap — must not crash.
        _ = QueryService.conversationId(for: String(repeating: "x", count: 64))
    }

    func testG1000CommandParserEntityRequiresArgument() {
        XCTAssertEqual(CommandParser.parse("/entity Orion"), .command(.entity("Orion")))
        XCTAssertEqual(CommandParser.parse("/entity"), .command(.help))
    }
}
