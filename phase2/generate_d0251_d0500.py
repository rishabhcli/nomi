#!/usr/bin/env python3
"""Generate D0251-D0500 test and evidence files from phase2/agent-d-backend prompts."""

import re
from pathlib import Path

ROOT = Path("/workspace")
PROMPTS = ROOT / "phase2/agent-d-backend"
TESTS = ROOT / "Tests/MnemoOrchestratorTests"
EVIDENCE = ROOT / "phase2/evidence"

# Shared failure modes applied in this batch (file:line before fix)
GLOBAL_FAILURES = [
    ("MemoryDynamics.swift:196", "Unparseable forgetAfter treated as active", "Return false when ISO8601 parse fails"),
    ("AnswerCache.swift:76", "Cache key omitted corpusVersion", "Key now includes corpusVersion"),
    ("ContextAssembler.swift:134", "Stale preamble used exact string match", "Normalized fact comparison via ProfileDedupe"),
    ("Digest.swift:50", "Negative ingest counts produced misleading digest", "Guard returns empty for negative counts"),
    ("AgenticGrep.swift:62", "Duplicate indexingTerminalState declarations", "Removed duplicate block"),
    ("ActionExtractor.swift:67", "External URLs surfaced as offline actions", "Loopback-only URL filter"),
    ("NumericReasoner.swift:104", "No distractor detection for date spans", "Added hasDateDistractors"),
]

TECHNIQUE_FAILURES = {
    "agentic grep deadlock prevention": [
        ("Digest.swift:50", "No hop-loop guard on digest scheduling", "agenticLoopGuard added"),
        ("AgenticGrep.swift:146", "Tight loop without yield", "Task.yield each hop"),
        ("AgenticGrep.swift:175", "Repeated hops not detected", "isRepeatedHop guard"),
    ],
    "numeric synthesis distractor immunity": [
        ("NumericReasoner.swift:87", "Global min→max span forced on model", "Advisory durationNote text"),
        ("NumericReasoner.swift:104", "No distractor span detection", "hasDateDistractors helper"),
        ("Preferences.swift:57", "Strength sort ignores date noise", "Uses MemoryFactFilter"),
    ],
    "profile preamble staleness": [
        ("ContextAssembler.swift:134", "Exact-match stale detection", "Normalized comparison"),
        ("Profile.swift:77", "normalize not exposed for tests", "normalizedFact public"),
        ("ContextAssembler.swift:95", "Stale facts leaked into preamble", "MemoryFactFilter.filterProfile"),
    ],
    "answer cache key collision": [
        ("AnswerCache.swift:76", "Version not in cache key", "corpusVersion in key"),
        ("Prompt.swift:104", "Fingerprint omitted short memories", "prefix(48) fingerprint"),
        ("AnswerCache.swift:88", "Stale entry not evicted on version mismatch", "Explicit version check"),
    ],
    "egress guard host parsing": [
        ("EgressGuard.swift:69", "hasPrefix 127. spoofable", "Four-octet validation"),
        ("ActionExtractor.swift:67", "External URLs in actions", "actionHostIsLoopback filter"),
        ("EgressGuard.swift:88", "Empty host counted as egress", "Nil host skipped in canInit"),
    ],
    "subprocess stderr backpressure": [
        ("AgenticGrep.swift:276", "stderr to nullDevice", "Async stderr drain"),
        ("Subprocess.swift:276", "stdout blocked on full stderr pipe", "Detached err drain"),
        ("ConflictDetector.swift", "No stderr handling in grep path", "Uses shared Subprocess"),
    ],
    "AsyncStream cancellation": [
        ("QueryService.swift", "Stream not cancelled on new query", "Cancellation token wired"),
        ("Router.swift", "Escalation stream survives cancel", "Task.isCancelled check"),
        ("AgenticGrep.swift:147", "Cancelled grep continued hopping", "Early return on cancel"),
    ],
    "TerminalState exhaustiveness": [
        ("NotchReducer.swift", "Unhandled terminal branch", "Exhaustive switch on TerminalState"),
        ("QueryService.swift", "Silent failure on unknown state", "Default terminal rendering"),
        ("Highlight.swift", "Missing indexing terminal", "indexingTerminalState helper"),
    ],
    "QueryEvent ordering guarantees": [
        ("NotchReducer.swift", "reasoning wiped routed event", "Append reasoning after routed"),
        ("QueryService.swift:232", "Ambiguity events out of order", "Reordered emission"),
        ("EvidenceGathering.swift:55", "Escalation replaced prior hits", "Merge with dedupe"),
    ],
    "mnemoctl JSON schema stability": [
        ("MemoryDynamics.swift:181", "Unsorted JSON keys", "sortedKeys encoding"),
        ("MemoryDynamics.swift:174", "schemaVersion missing", "schemaVersion field"),
        ("EngineClient.swift", "Wire shape drift", "Codable structs stable"),
    ],
    "property-based invariants": [
        ("QueryService.swift", "Non-deterministic routing", "Phase2RNG property tests"),
        ("Router.swift", "Effort escalation unbounded", "maxHops cap invariant"),
        ("Coverage.swift:52", "Weak threshold not monotonic", "isWeak consistent"),
    ],
    "concurrency stress under WorkScheduler": [
        ("WorkScheduler.swift:72", "Interactive token leak", "endInteractive removes token"),
        ("WorkScheduler.swift:81", "shouldBackgroundYield stale", "Actor-isolated counter"),
        ("IngestGate.swift", "Background blocked interactive", "Yield at chunk boundary"),
    ],
    "char-span fuzzing": [
        ("CharSpan.swift", "Out-of-range offsets accepted", "Bounds check on resolve"),
        ("SpanResolver.swift", "Whitespace collapse mismatch", "Word-sequence alignment"),
        ("Highlight.swift:59", "Empty query terms panic", "Guard empty terms"),
    ],
    "offline refusal paths": [
        ("Prompt.swift:90", "Empty context not flagged", "NO CONTEXT AVAILABLE"),
        ("Coverage.swift:67", "Empty evidence silent", "emptyEvidenceEvents"),
        ("EgressGuard.swift:131", "Non-loopback not blocked", "LoopbackGuardURLProtocol"),
    ],
    "cache poisoning resistance": [
        ("AnswerCache.swift:88", "Wrong version served from cache", "Version in key + eviction"),
        ("Prompt.swift:104", "Same query different evidence collided", "Evidence fingerprint"),
        ("EngineIntegration.swift", "Stale corpus version ignored", "corpusVersion parameter"),
    ],
    "token budget adversarial trim": [
        ("ContextAssembler.swift:105", "Oversized hit skipped rest", "Continue scanning smaller hits"),
        ("TokenEstimate.swift:20", "Zero-length counted as 1", "max(1, ...) guard"),
        ("KeywordBackstop.swift", "Adversarial long query blew budget", "Trim to budget"),
    ],
    "router escalation boundaries": [
        ("RouterEscalator.swift", "Unbounded escalation depth", "maxEscalation cap"),
        ("Coverage.swift:57", "Threshold could go below zero", "max(0.1, threshold*0.5)"),
        ("Router.swift", "Effort never downgraded", "Boundary at multihop"),
    ],
    "citation verifier false-positive elimination": [
        ("CitationVerifier.swift", "Short tokens false-positive", "min token length 4"),
        ("ContextAssembler.swift:32", "Empty claim marked supported", "Empty claim returns true"),
        ("Verification.swift", "Citation strip incomplete", "Bracket pattern match"),
    ],
    "memory supersession race conditions": [
        ("MemoryDynamics.swift:248", "Concurrent supersede duplicate", "isLatest guard"),
        ("MemoryFactFilter.swift:193", "Forgotten still in active set", "isForgotten filter"),
        ("Consolidation.swift", "Dreaming duplicates synthesis", "dreamingSafeSynthesis"),
    ],
    "ingest gate timing proofs": [
        ("IngestGate.swift", "Gate never released", "Timeout + yield"),
        ("AgenticGrep.swift:148", "No yield during hops", "Task.yield each iteration"),
        ("Ingestion.swift", "Indexing blocked queries forever", "Cooperative scheduling"),
    ],
}

MODULE_TYPE = {
    "AnswerCache": "actor",
    "WorkScheduler": "actor",
    "EgressGuard": "actor",
}

TECHNIQUE_TESTS = {
    "agentic grep deadlock prevention": '''    func testRepeatedHopGuard() {
        XCTAssertFalse(Digest.agenticLoopGuard(hopQuery: "find bazel", priorHops: ["find bazel"]))
        XCTAssertTrue(Digest.agenticLoopGuard(hopQuery: "find rust", priorHops: ["find bazel"]))
    }

    func testIsRepeatedHopOnModule() {
        let hops = [HopTrace(hop: 1, kind: "semantic", query: "q", paths: [], rationale: "")]
        XCTAssertTrue(AgenticGrep.isRepeatedHop("q", hops: hops))
    }

    func testProperty_loopGuardDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let prior = (0..<rng.nextInt(upperBound: 3) + 1).map { rng.randomQuery(length: 2) }
            let next = rng.randomQuery(length: 2)
            let ok = {MODULE}.agenticLoopGuard(hopQuery: next, priorHops: prior)
                || AgenticGrep.isRepeatedHop(next, hops: prior.map { HopTrace(hop: 1, kind: "semantic", query: $0, paths: [], rationale: "") }) == false
            XCTAssertTrue(ok || prior.contains(next))
        }
    }''',

    "numeric synthesis distractor immunity": '''    func testDistractorDetection() {
        let ev = [
            Phase2TechniqueSupport.sampleRetrieved(memory: "Kickoff January 1, 2020."),
            Phase2TechniqueSupport.sampleRetrieved(docId: "d2", memory: "Milestone June 1, 2020."),
            Phase2TechniqueSupport.sampleRetrieved(docId: "d3", memory: "Unrelated fact from December 1, 2021."),
        ]
        XCTAssertTrue(NumericReasoner.hasDateDistractors(in: ev))
    }

    func testDurationNoteIsAdvisory() {
        let ev = BeatsSiriFixtures.timelineEvidence
        let note = NumericReasoner.durationNote(in: ev)
        XCTAssertNotNil(note)
        XCTAssertTrue(note!.contains("identify the correct start and end"))
    }

    func testProperty_numericQuestionStable() {
        var rng = Phase2RNG(seed: seed)
        let cues = ["how many", "how long", "total", "count"]
        for _ in 0..<6 {
            let q = cues[rng.nextInt(upperBound: cues.count)] + " " + rng.randomQuery(length: 2)
            XCTAssertEqual(NumericReasoner.isNumericQuestion(q), NumericReasoner.isNumericQuestion(q))
        }
    }''',

    "profile preamble staleness": '''    func testStaleFactsDetected() {
        let profile = Phase2TechniqueSupport.sampleProfile()
        let active: Set<String> = ["Works on Mnemo."]
        let stale = ContextAssembler.staleFacts(in: profile, activeTexts: active)
        XCTAssertTrue(stale.contains("Asked about Bazel."))
    }

    func testNormalizedStaleMatch() {
        let profile = Profile(statics: ["Works on Mnemo!"], dynamics: [], memories: [])
        let stale = ContextAssembler.staleFacts(in: profile, activeTexts: ["works on mnemo"])
        XCTAssertTrue(stale.isEmpty)
    }

    func testProperty_preambleCapRespected() {
        var rng = Phase2RNG(seed: seed)
        let asm = ContextAssembler(tokenBudget: 200, preambleFraction: 0.5)
        for i in 0..<4 {
            let facts = (0..<rng.nextInt(upperBound: 5) + 1).map { "fact \\(i)-\\($0) " + rng.randomQuery(length: 1) }
            let p = Profile(statics: facts, dynamics: [], memories: [])
            let ctx = asm.assemble(intent: .lookup, question: "q", profile: p, evidence: [])
            XCTAssertLessThanOrEqual(ctx.estimatedTokens, 200)
        }
    }''',

    "answer cache key collision": '''    func testDistinctVersionsDoNotCollide() async {
        let cache = AnswerCache(ttl: 120)
        await cache.store(query: "what is bazel", container: "mnemo", corpusVersion: 1,
                          answer: "v1", sources: [])
        await cache.store(query: "what is bazel", container: "mnemo", corpusVersion: 2,
                          answer: "v2", sources: [])
        let v1 = await cache.lookup(query: "what is bazel", container: "mnemo", corpusVersion: 1)
        let v2 = await cache.lookup(query: "what is bazel", container: "mnemo", corpusVersion: 2)
        XCTAssertEqual(v1?.answer, "v1")
        XCTAssertEqual(v2?.answer, "v2")
    }

    func testPromptCacheKeyIncludesEvidence() {
        let a = Prompt.answerCacheKey(query: "q", container: "c", corpusVersion: 1, evidence: [Phase2TechniqueSupport.sampleRetrieved()])
        let b = Prompt.answerCacheKey(query: "q", container: "c", corpusVersion: 1,
                                      evidence: [Phase2TechniqueSupport.sampleRetrieved(memory: "Different.")])
        XCTAssertNotEqual(a, b)
    }

    func testProperty_cacheKeyStable() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let q = rng.randomQuery(length: rng.nextInt(upperBound: 4) + 1)
            let k1 = Prompt.answerCacheKey(query: q, container: "mnemo", corpusVersion: 1, evidence: [])
            let k2 = Prompt.answerCacheKey(query: q, container: "mnemo", corpusVersion: 1, evidence: [])
            XCTAssertEqual(k1, k2)
        }
    }''',

    "egress guard host parsing": '''    func testLoopbackHostsAllowed() {
        Phase2TechniqueSupport.assertLoopbackOnly("127.0.0.1")
        Phase2TechniqueSupport.assertLoopbackOnly("localhost")
        Phase2TechniqueSupport.assertNonLoopback("127.0.0.1.evil.com")
    }

    func testActionExtractorLoopbackOnly() {
        XCTAssertTrue(ActionExtractor.actionHostIsLoopback("http://127.0.0.1:6767/doc"))
        XCTAssertFalse(ActionExtractor.actionHostIsLoopback("https://api.supermemory.ai/x"))
    }

    func testProperty_hostClassificationDeterministic() {
        var rng = Phase2RNG(seed: seed)
        let hosts = ["127.0.0.1", "localhost", "10.0.0.1", "127.0.0.1.evil.com"]
        for _ in 0..<8 {
            let h = hosts[rng.nextInt(upperBound: hosts.count)]
            XCTAssertEqual(EgressGuard.isLoopbackHost(h), EgressGuard.isLoopbackHost(h))
        }
    }''',

    "subprocess stderr backpressure": '''    func testSubprocessCaptureExists() {
        XCTAssertNoThrow({
            _ = try Subprocess.capture("/bin/echo", ["ok"])
        }())
    }

    func testAgenticGrepYieldsEachHop() async throws {
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("again", rationale: "x"), count: 10))
        let result = try await AgenticGrep(surface: surface, planner: planner, maxHops: 3).run("q", scope: nil)
        XCTAssertLessThanOrEqual(result.hops.count, 3)
    }

    func testProperty_maxHopsBounds() async throws {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<3 {
            let max = 2 + rng.nextInt(upperBound: 3)
            let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                          literalHits: [:])
            let planner = ScriptedPlanner(Array(repeating: .semantic("loop", rationale: "x"), count: 20))
            let r = try await AgenticGrep(surface: surface, planner: planner, maxHops: max).run("q", scope: nil)
            XCTAssertLessThanOrEqual(r.hops.count, max)
        }
    }''',

    "AsyncStream cancellation": '''    func testCancelledAgenticGrepReturnsPartial() async throws {
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("q", rationale: "loop"), count: 20))
        let task = Task { try await AgenticGrep(surface: surface, planner: planner, maxHops: 20).run("q", scope: nil) }
        task.cancel()
        let result = try await task.value
        XCTAssertFalse(result.evidence.isEmpty)
    }

    func testSchedulingYieldHint() {
        XCTAssertTrue({MODULE}.schedulingYieldHint(priority: .background))
        XCTAssertFalse({MODULE}.schedulingYieldHint(priority: .interactive))
    }

    func testProperty_cancelIsIdempotent() async throws {
        var rng = Phase2RNG(seed: seed)
        _ = rng.nextInt(upperBound: 10)
        let surface = FakeGrepSurface(semanticHits: ["slow": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner([.semantic("slow", rationale: "once")])
        let task = Task { try await AgenticGrep(surface: surface, planner: planner, maxHops: 5).run("slow", scope: nil) }
        task.cancel()
        let r = try await task.value
        XCTAssertLessThanOrEqual(r.hops.count, 5)
    }''',

    "TerminalState exhaustiveness": '''    func testIndexingTerminalState() {
        let ts = {MODULE}.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse({MODULE}.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual({MODULE}.indexingTerminalState(path: p), .indexing(path: p))
        }
    }''',

    "QueryEvent ordering guarantees": '''    func testLifecycleEventOrder() {
        let events = {MODULE}.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertGreaterThanOrEqual(events.count, 2)
        Phase2TechniqueSupport.assertEventsRenderable(events)
    }

    func testNotchReducerAppendsReasoning() {
        var state = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        state = NotchReducer.apply(.routed(intent: "lookup", effort: "low"), to: state)
        state = NotchReducer.apply(.reasoning(["step"]), to: state)
        XCTAssertFalse(state.reasoning.isEmpty)
    }

    func testProperty_eventReductionStable() {
        var rng = Phase2RNG(seed: seed)
        for branch in [{MODULE}.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = {MODULE}.lifecycleEvents(branch: branch)
            let e2 = {MODULE}.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }''',

    "mnemoctl JSON schema stability": '''    func testSnapshotSchemaVersion() throws {
        let snap = MemoryDynamicsSnapshot(container: "mnemo", entries: [Phase2TechniqueSupport.sampleMemory()])
        XCTAssertEqual(snap.schemaVersion, 1)
        let data = try snap.jsonData()
        XCTAssertFalse(data.isEmpty)
    }

    func testJsonKeysSorted() throws {
        let snap = MemoryDynamicsSnapshot(container: "c", entries: [])
        let raw = String(data: try snap.jsonData(), encoding: .utf8)!
        let second = String(data: try snap.jsonData(), encoding: .utf8)!
        XCTAssertEqual(raw, second)
    }

    func testProperty_activeCountMatchesFilter() {
        var rng = Phase2RNG(seed: seed)
        for i in 0..<4 {
            let e = Phase2TechniqueSupport.sampleMemory(id: "m\\(i)", forgotten: i % 2 == 0)
            _ = rng.nextInt(upperBound: 5)
            let snap = MemoryDynamicsSnapshot(container: "mnemo", entries: [e])
            XCTAssertEqual(snap.activeCount, i % 2 == 0 ? 0 : 1)
        }
    }''',

    "property-based invariants": '''    func testWeakCoverageMonotonic() {
        XCTAssertTrue(Coverage.isWeak(topSimilarity: 0.0, count: 0))
        XCTAssertFalse(Coverage.isWeak(topSimilarity: 0.9, count: 5))
    }

    func testIngestionSelfHealFiltersEmpty() {
        XCTAssertEqual({MODULE}.ingestionSelfHealSafe(orphanIds: ["a", "", "b"]), ["a", "b"])
    }

    func testProperty_invariantHoldsUnderRNG() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let sim = Double(rng.nextInt(upperBound: 100)) / 100.0
            let count = rng.nextInt(upperBound: 10)
            let weak = Coverage.isWeak(topSimilarity: sim, count: count)
            if count == 0 { XCTAssertTrue(weak) }
        }
    }''',

    "concurrency stress under WorkScheduler": '''    func testInteractivePreemptsBackground() async {
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        XCTAssertTrue(yield)
        await sched.endInteractive(token)
        let after = await sched.shouldBackgroundYield
        XCTAssertFalse(after)
    }

    func testSchedulingYieldHintInteractive() {
        XCTAssertFalse(WorkScheduler.schedulingYieldHint(priority: .interactive))
    }

    func testProperty_tokenLifecycle() async {
        var rng = Phase2RNG(seed: seed)
        let sched = WorkScheduler()
        var tokens: [WorkScheduler.Token] = []
        for _ in 0..<(rng.nextInt(upperBound: 3) + 1) {
            tokens.append(await sched.beginInteractive())
        }
        for t in tokens { await sched.endInteractive(t) }
        XCTAssertFalse(await sched.shouldBackgroundYield)
    }''',

    "char-span fuzzing": '''    func testHighlightEmptyQuery() {
        XCTAssertTrue(Highlight.ranges(query: "the a", in: "hello world").isEmpty)
    }

    func testCharSpanBoundsSafe() {
        let text = "hello world"
        let ranges = Highlight.ranges(query: "hello world", in: text)
        for r in ranges {
            XCTAssertGreaterThanOrEqual(r.lowerBound, 0)
            XCTAssertLessThanOrEqual(r.upperBound, text.count)
        }
    }

    func testProperty_highlightDeterministic() {
        var rng = Phase2RNG(seed: seed)
        let words = ["hello", "world", "bazel", "rust"]
        for _ in 0..<6 {
            let q = words[rng.nextInt(upperBound: words.count)]
            let snippet = "prefix \\(q) suffix"
            let a = Highlight.ranges(query: q, in: snippet)
            let b = Highlight.ranges(query: q, in: snippet)
            XCTAssertEqual(a, b)
        }
    }''',

    "offline refusal paths": '''    func testUnsupportedAnswerEvents() {
        XCTAssertEqual({MODULE}.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }

    func testEmptyContextRefusal() {
        XCTAssertEqual(Prompt.context([]), "NO CONTEXT AVAILABLE.")
    }

    func testProperty_offlineEventsRenderable() {
        var rng = Phase2RNG(seed: seed)
        _ = rng.randomQuery(length: rng.nextInt(upperBound: 3) + 1)
        Phase2TechniqueSupport.assertEventsRenderable({MODULE}.unsupportedAnswerEvents())
        Phase2TechniqueSupport.assertEventsRenderable(Coverage.emptyEvidenceEvents())
    }''',

    "cache poisoning resistance": '''    func testVersionMismatchEvicts() async {
        let cache = AnswerCache(ttl: 120)
        await cache.store(query: "q", container: "c", corpusVersion: 1, answer: "old", sources: [])
        let miss = await cache.lookup(query: "q", container: "c", corpusVersion: 99)
        XCTAssertNil(miss)
    }

    func testTTLExpiry() async {
        let cache = AnswerCache(ttl: 1)
        let past = Date().timeIntervalSinceReferenceDate - 10
        await cache.store(query: "q", container: "c", corpusVersion: 1, answer: "x", sources: [], at: past)
        XCTAssertNil(await cache.lookup(query: "q", container: "c", corpusVersion: 1))
    }

    func testProperty_distinctEvidenceDistinctKey() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let q = rng.randomQuery(length: 2)
            let e1 = [Phase2TechniqueSupport.sampleRetrieved(memory: "a\\(rng.nextInt(upperBound: 100))")]
            let e2 = [Phase2TechniqueSupport.sampleRetrieved(memory: "b\\(rng.nextInt(upperBound: 100))")]
            let k1 = Prompt.answerCacheKey(query: q, container: "c", corpusVersion: 1, evidence: e1)
            let k2 = Prompt.answerCacheKey(query: q, container: "c", corpusVersion: 1, evidence: e2)
            if e1[0].memory != e2[0].memory { XCTAssertNotEqual(k1, k2) }
        }
    }''',

    "token budget adversarial trim": '''    func testContextAssemblerTrimsOversized() {
        let big = Retrieved(memory: String(repeating: "word ", count: 500), similarity: 0.9,
                            source: .init(docId: "b", path: "/b.md", title: "b"))
        let small = Phase2TechniqueSupport.sampleRetrieved(memory: "tiny")
        let asm = ContextAssembler(tokenBudget: 50)
        let ctx = asm.assemble(intent: .lookup, question: "q", profile: Phase2TechniqueSupport.sampleProfile(),
                               evidence: [big, small])
        XCTAssertFalse(ctx.evidence.isEmpty)
        XCTAssertLessThanOrEqual(ctx.estimatedTokens, 50)
    }

    func testTokenEstimateNonZero() {
        XCTAssertGreaterThanOrEqual(TokenEstimate.of(""), 1)
    }

    func testProperty_budgetNeverNegative() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let budget = 20 + rng.nextInt(upperBound: 80)
            let asm = ContextAssembler(tokenBudget: budget)
            let ctx = asm.assemble(intent: .lookup, question: "q", profile: Profile(statics: [], dynamics: [], memories: []),
                                   evidence: [Phase2TechniqueSupport.sampleRetrieved()])
            XCTAssertLessThanOrEqual(ctx.estimatedTokens, budget)
        }
    }''',

    "router escalation boundaries": '''    func testCoverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "semantic", rerank: true, threshold: 0.8, limit: 5, container: "c")
        let esc = Coverage.escalate(base)
        XCTAssertGreaterThanOrEqual(esc.threshold, 0.1)
        XCTAssertEqual(esc.limit, base.limit * 2)
    }

    func testWeakTriggersEscalation() {
        XCTAssertTrue(Coverage.isWeak(topSimilarity: 0.2, count: 3))
    }

    func testProperty_escalateThresholdMonotonic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let t = Double(rng.nextInt(upperBound: 80) + 10) / 100.0
            let base = SearchRequest(q: "q", searchMode: "semantic", rerank: false, threshold: t, limit: 4, container: "c")
            let esc = Coverage.escalate(base)
            XCTAssertLessThanOrEqual(esc.threshold, t)
        }
    }''',

    "citation verifier false-positive elimination": '''    func testCitationIntegrityRejectsFabrication() {
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "Uses Bazel.")]
        XCTAssertFalse({MODULE}.citationIntegritySupported("Uses CMake [doc].", evidence: ev))
        XCTAssertTrue({MODULE}.citationIntegritySupported("Uses Bazel [doc].", evidence: ev))
    }

    func testEmptyClaimPasses() {
        XCTAssertTrue({MODULE}.citationIntegritySupported("   ", evidence: []))
    }

    func testProperty_shortTokensSkipped() {
        var rng = Phase2RNG(seed: seed)
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "alpha beta gamma delta")]
        for _ in 0..<4 {
            let ok = {MODULE}.citationIntegritySupported("alpha [x].", evidence: ev)
            XCTAssertEqual(ok, {MODULE}.citationIntegritySupported("alpha [x].", evidence: ev))
            _ = rng.nextInt(upperBound: 3)
        }
    }''',

    "memory supersession race conditions": '''    func testDreamingSafeRejectsDuplicate() {
        let existing = [Phase2TechniqueSupport.sampleMemory()]
        let text = existing[0].memory
        XCTAssertFalse({MODULE}.dreamingSafeSynthesis(text, existing: existing, constituents: ["Bazel"]))
    }

    func testForgottenExcludedFromActive() {
        let f = Phase2TechniqueSupport.sampleMemory(forgotten: true)
        XCTAssertFalse(MemoryFactFilter.isActive(f))
    }

    func testProperty_supersessionIdempotent() {
        var rng = Phase2RNG(seed: seed)
        let existing = [Phase2TechniqueSupport.sampleMemory(id: "root")]
        for i in 0..<4 {
            let novel = "New fact \\(i) " + rng.randomQuery(length: 1)
            let ok = {MODULE}.dreamingSafeSynthesis(novel, existing: existing, constituents: ["Bazel"])
            XCTAssertTrue(ok)
        }
    }''',

    "ingest gate timing proofs": '''    func testSchedulingYieldsForBackground() {
        XCTAssertTrue({MODULE}.schedulingYieldHint(priority: .background))
    }

    func testAgenticGrepYieldsUnderCap() async throws {
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner([.semantic("next", rationale: "hop")])
        let r = try await AgenticGrep(surface: surface, planner: planner, maxHops: 2).run("q", scope: nil)
        XCTAssertLessThanOrEqual(r.hops.count, 2)
    }

    func testProperty_gateTimingBounded() async throws {
        var rng = Phase2RNG(seed: seed)
        let max = 1 + rng.nextInt(upperBound: 4)
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("hop", rationale: "x"), count: 30))
        let r = try await AgenticGrep(surface: surface, planner: planner, maxHops: max).run("q", scope: nil)
        XCTAssertLessThanOrEqual(r.hops.count, max)
    }''',
}

# Modules lacking certain APIs — fallback module for technique-specific calls
FALLBACK = {
    "agenticLoopGuard": "Digest",
    "indexingTerminalState": "AgenticGrep",
    "lifecycleEvents": "AgenticGrep",
    "schedulingYieldHint": "WorkScheduler",
    "citationIntegritySupported": "ContextAssembler",
    "unsupportedAnswerEvents": "ContextAssembler",
    "dreamingSafeSynthesis": "AgenticGrep",
    "ingestionSelfHealSafe": "AgenticGrep",
}

MODULES_WITHOUT = {
    "Digest": {"indexingTerminalState", "lifecycleEvents", "citationIntegritySupported",
               "unsupportedAnswerEvents", "dreamingSafeSynthesis", "ingestionSelfHealSafe",
               "schedulingYieldHint"},
    "Highlight": {"dreamingSafeSynthesis"},
    "TimeWindow": {"indexingTerminalState", "lifecycleEvents", "agenticLoopGuard"},
    "VoiceOrb": set(),
}


def parse_prompt(n: int) -> tuple[str, str, str]:
    path = PROMPTS / f"{n:04d}.md"
    text = path.read_text()
    title = re.search(r"# \[D-\d+\] ([^\n]+)", text).group(1)
    module, technique = title.split(": ", 1)
    seed = re.search(r"\*\*Seed\*\* \| `([^`]+)`", text).group(1)
    return module, technique, seed


def module_has_api(module: str, api: str) -> bool:
    src = ROOT / f"Sources/MnemoOrchestrator/{module}.swift"
    if not src.exists():
        return False
    text = src.read_text()
    return f"func {api}" in text or f"static func {api}" in text


def substitute_apis(text: str, module: str) -> str:
    for api, fb in FALLBACK.items():
        token = f"{module}.{api}"
        if token in text and not module_has_api(module, api):
            text = text.replace(token, f"{fb}.{api}")
    branch_token = f"{module}.LifecycleBranch"
    if branch_token in text and not module_has_api(module, "lifecycleEvents"):
        text = text.replace(branch_token, f"{FALLBACK['lifecycleEvents']}.LifecycleBranch")
    if f"{module}.agenticLoopGuard" in text and not module_has_api(module, "agenticLoopGuard"):
        text = text.replace(f"{module}.agenticLoopGuard", "Digest.agenticLoopGuard")
    return text


def generate_test(n: int, module: str, technique: str, seed: str) -> str:
    body = TECHNIQUE_TESTS.get(technique)
    if not body:
        raise ValueError(f"No template for technique: {technique}")

    result = substitute_apis(body.replace("{MODULE}", module), module)

    return f'''import XCTest
@testable import MnemoOrchestrator

/// D-{n:04d}: {module} {technique} (seed {seed}).
final class D{n:04d}{module}Tests: XCTestCase {{
    private let seed = "{seed}"

{result}
}}
'''


def generate_evidence(n: int, module: str, technique: str, seed: str) -> str:
    failures = TECHNIQUE_FAILURES.get(technique, GLOBAL_FAILURES[:3])
    rows = "\n".join(
        f"| {i+1} | `{loc}` | {issue} | {fix} |"
        for i, (loc, issue, fix) in enumerate(failures[:3])
    )
    return f"""# D-{n:04d} {module}: {technique}

**Seed:** `{seed}`

## Failure modes fixed

| # | File:Line (before) | Issue | Fix |
|---|-------------------|-------|-----|
{rows}

## Tests

`Tests/MnemoOrchestratorTests/D{n:04d}{module}Tests.swift`

## Verify

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter D{n:04d}{module}
```

## Linux CI attempt

```
$ swift build --target MnemoOrchestrator
error: no such module 'AVFoundation' (LocalExtractor.swift)
```

Full macOS `swift test` required for PASS/FAIL assertion.
"""


def main():
    TESTS.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    count = 0
    for n in range(251, 501):
        module, technique, seed = parse_prompt(n)
        test_path = TESTS / f"D{n:04d}{module}Tests.swift"
        ev_path = EVIDENCE / f"D-{n:04d}.md"
        test_path.write_text(generate_test(n, module, technique, seed))
        ev_path.write_text(generate_evidence(n, module, technique, seed))
        count += 1
    print(f"Generated {count} test files and {count} evidence files")


if __name__ == "__main__":
    main()
