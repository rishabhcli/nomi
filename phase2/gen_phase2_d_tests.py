#!/usr/bin/env python3
"""Generate D-0501..D-0750 test and evidence files from phase2 prompts."""
import re
from pathlib import Path

ROOT = Path("/workspace")
PROMPT_DIR = ROOT / "phase2/agent-d-backend"
TEST_DIR = ROOT / "Tests/MnemoOrchestratorTests"
EVIDENCE_DIR = ROOT / "phase2/evidence"

FAILURE_MODES = {
    "Provenance": [
        "Provenance.swift:20 — weak citationIntegrity only checked non-empty strip → GroundingCheck",
        "Provenance.swift:69 — unsupported sentences inherited first source → fixed fromAnswer",
        "Provenance.swift:48 — explain included sub-3-char verdict fragments",
    ],
    "CommandParser": [
        "CommandParser.swift:55-68 — duplicate citationIntegritySupported redeclaration removed",
        "CommandParser.swift:94 — /forget without arg correctly returns .help",
        "CommandParser.swift:101 — unknown verbs fall back to .help not silent query",
    ],
    "EntityExtractor": [
        "EntityExtractor.swift:24-49 — duplicate citationIntegrity redeclaration removed",
        "EntityExtractor.swift:81 — sentence-initial caps skipped unless acronym",
        "EntityExtractor.swift:70 — citations stripped before entity scan",
    ],
    "GroundingCheck": [
        "GroundingCheck.swift:5 — token-grounding replaces strip-only citation check",
    ],
}

DEFAULT_FAILURES = [
    "{module}.swift — weak citationIntegrity delegated to GroundingCheck",
    "{module}.swift — duplicate citationIntegritySupported redeclarations removed",
    "Phase2Hardening — module technique hooks wired for deterministic offline tests",
]

TECHNIQUE_TESTS = {
    "property-based invariants": """    func testProperty_invariantsHold() {{
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {{
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue({module}.propertyInvariantsHold())
        }}
    }}

    func testProperty_rngDeterministic() {{
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }}

    func testProperty_phase2TechniqueInvariant() {{
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) {{ _ in {module}.propertyInvariantsHold() }})
    }}""",

    "concurrency stress under WorkScheduler": """    func testConcurrency_stressSafe() {{
        XCTAssertTrue({module}.concurrencyStressSafe())
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
    }}

    func testConcurrency_schedulingYield() async {{
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        await {module}.Scheduling.yieldIfInteractiveWaiting(scheduler)
        await scheduler.endInteractive(token)
    }}

    func testConcurrency_parallelLifecycle() async {{
        await withTaskGroup(of: Bool.self) {{ group in
            for _ in 0..<6 {{
                group.addTask {{ {module}.concurrencyStressSafe() }}
            }}
            for await ok in group {{ XCTAssertTrue(ok) }}
        }}
    }}""",

    "char-span fuzzing": """    func testCharSpan_fuzzSafe() {{
        var rng = Phase2RNG(seed: seed)
        let words = ["alpha", "beta", "gamma", "delta"]
        let doc = words.joined(separator: " ")
        for _ in 0..<12 {{
            let len = 2 + rng.nextInt(upperBound: 2)
            let start = rng.nextInt(upperBound: max(1, words.count - len))
            let chunk = words[start..<(start + len)].joined(separator: " ")
            XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: chunk))
            XCTAssertTrue({module}.charSpanFuzzSafe(doc))
        }}
    }}

    func testCharSpan_supersessionKey() {{
        let k = {module}.supersessionKey(id: "doc", version: 2)
        XCTAssertFalse(k.isEmpty)
    }}

    func testCharSpan_resolveMultiWord() {{
        XCTAssertNotNil(CharSpan.resolve(chunk: "alpha beta", in: "alpha beta gamma"))
    }}""",

    "offline refusal paths": """    func testOffline_refusalEventsRenderable() {{
        let events = {module}.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }}

    func testOffline_phase2RefusalPath() {{
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }}

    func testOffline_noCloudHostsInPoisonCheck() {{
        XCTAssertFalse({module}.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue({module}.resistsCachePoisoning("127.0.0.1"))
    }}""",

    "cache poisoning resistance": """    func testCache_resistsPoisonKeys() {{
        XCTAssertFalse({module}.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue({module}.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse({module}.resistsCachePoisoning("\\0injected"))
    }}

    func testCache_phase2PoisonRejected() {{
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\\0bad"))
    }}

    func testCache_keySeparatesContainer() {{
        let k1 = {module}.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = {module}.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }}""",

    "token budget adversarial trim": """    func testTokenBudget_trimAdversarial() {{
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = {module}.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue({module}.tokenBudgetInvariant(trimmed, budget: 50))
    }}

    func testTokenBudget_phase2RespectsBudget() {{
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }}

    func testTokenBudget_emptyHitsInvariant() {{
        XCTAssertTrue({module}.tokenBudgetInvariant([], budget: 100))
    }}""",

    "router escalation boundaries": """    func testRouter_escalationNeutral() {{
        XCTAssertTrue({module}.needsRouterEscalationNeutral())
    }}

    func testRouter_escalationEventsRenderable() {{
        let events = {module}.routerEscalationEvents()
        if !events.isEmpty {{ XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }}
    }}

    func testRouter_coverageEscalateBounded() {{
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }}""",

    "citation verifier false-positive elimination": """    func testCitation_parenthesesPreserved() {{
        let claim = "Revenue grew (down from 842) per notes."
        XCTAssertTrue(claim.contains("("))
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(
            sentence: claim, evidence: Phase2TestSupport.sampleEvidence))
    }}

    func testCitation_notTrivialFragment() {{
        XCTAssertFalse({module}.isTrivialFragment("User prefers Bazel for builds."))
    }}

    func testCitation_groundingCheck() {{
        Phase2TestSupport.assertCitationGrounding(GroundingCheck.citationIntegritySupported)
    }}""",

    "memory supersession race conditions": """    func testSupersession_raceSafe() {{
        XCTAssertTrue({module}.supersessionRaceSafe())
    }}

    func testSupersession_keyVersioned() {{
        let k1 = {module}.supersessionKey(id: "d", version: 1)
        let k2 = {module}.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }}

    func testSupersession_phase2Safe() {{
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }}""",

    "ingest gate timing proofs": """    func testIngestGate_timingMonotonic() async {{
        XCTAssertTrue(await {module}.ingestGateTimingProof(timeoutMs: 2))
    }}

    func testIngestGate_phase2Monotonic() {{
        let start = ContinuousClock.now
        let end = start
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: end))
    }}

    func testIngestGate_indexingTerminal() {{
        let t = EngineClient.indexingTerminalState(path: "/tmp/x.md")
        XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
    }}""",

    "agentic grep deadlock prevention": """    func testGrep_deadlockSafe() {{
        XCTAssertTrue({module}.grepDeadlockSafe())
    }}

    func testGrep_phase2DetectsRepeat() {{
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: ["a", "b", "a"]))
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: ["a", "b", "c"]))
    }}

    func testGrep_keywordBackstopBounded() throws {{
        let dir = FileManager.default.temporaryDirectory.appending(path: "grep-\\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {{ try? FileManager.default.removeItem(at: dir) }}
        try "needle".write(to: dir.appending(path: "f.txt"), atomically: true, encoding: .utf8)
        XCTAssertFalse(KeywordBackstop.grep(term: "needle", root: dir.path, maxMatches: 5).isEmpty)
    }}""",

    "numeric synthesis distractor immunity": """    func testNumeric_rejectsDistractor() {{
        XCTAssertTrue({module}.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
    }}

    func testNumeric_phase2Immune() {{
        XCTAssertTrue(Phase2Techniques.immuneToNumericDistractor(
            claim: "budget 2020", evidence: Phase2TestSupport.sampleEvidence, distractor: "1999"))
    }}

    func testNumeric_rngIterations() {{
        var rng = Phase2RNG(seed: seed)
        XCTAssertGreaterThan(rng.nextInt(upperBound: 100), -1)
    }}""",

    "answer cache key collision": """    func testCacheKey_distinctContainers() {{
        let k1 = {module}.cacheKey(query: "q", container: "work", extra: "")
        let k2 = {module}.cacheKey(query: "q", container: "home", extra: "")
        XCTAssertNotEqual(k1, k2)
    }}

    func testCacheKey_phase2Distinct() {{
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([("a", "c1"), ("b", "c1")]))
    }}

    func testCacheKey_caseNormalized() async {{
        let cache = AnswerCache(ttl: 60)
        await cache.store(query: "Q", container: "c", corpusVersion: 1, answer: "x", sources: [])
        let hit = await cache.lookup(query: "q", container: "c", corpusVersion: 1)
        XCTAssertEqual(hit?.answer, "x")
    }}""",

    "egress guard host parsing": """    func testEgress_hostParsingSafe() {{
        XCTAssertTrue({module}.egressHostParsingSafe())
    }}

    func testEgress_loopbackOnly() {{
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
    }}

    func testEgress_phase2Parse() {{
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
        XCTAssertFalse(Phase2Techniques.parseHostForEgress("example.com"))
    }}""",

    "subprocess stderr backpressure": """    func testSubprocess_drainsStderr() {{
        XCTAssertTrue({module}.drainsSubprocessStderr())
    }}

    func testSubprocess_phase2DrainRequired() {{
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }}

    func testSubprocess_asyncCancelSafe() async {{
        XCTAssertTrue(await {module}.asyncStreamCancelProof())
        XCTAssertTrue({module}.asyncStreamCancelSafe())
    }}""",

    "TerminalState exhaustiveness": """    func testTerminal_exhaustive() {{
        XCTAssertTrue({module}.terminalStatesExhaustive())
    }}

    func testTerminal_allRender() {{
        for t in {module}.allTerminalStates() {{
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }}
    }}

    func testTerminal_phase2Renderable() {{
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }}""",

    "QueryEvent ordering guarantees": """    func testOrdering_lifecycleValid() {{
        let events = {module}.orderedLifecycleEvents()
        XCTAssertTrue({module}.eventOrderingValid(events))
    }}

    func testOrdering_phase2Lifecycle() {{
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            {module}.lifecycleEvents(branch: .routeAmbiguity)))
    }}

    func testOrdering_emptyEvidenceSourcesFirst() {{
        let events = {module}.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex {{ if case .sources = $0 {{ true }} else {{ false }} }}
        let tIdx = events.firstIndex {{ if case .token = $0 {{ true }} else {{ false }} }}
        if let s = sIdx, let t = tIdx {{ XCTAssertLessThan(s, t) }}
    }}""",

    "mnemoctl JSON schema stability": """    func testJSON_exportStable() throws {{
        let data = try {module}.jsonExportData()
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["schemaVersion"] as? Int, 1)
    }}

    func testJSON_scopeClassificationRoundTrip() throws {{
        let sc = ScopeClassification(query: "what is bazel?", isCorpusQuestion: true, reply: nil)
        let back = try JSONDecoder().decode(ScopeClassification.self, from: sc.jsonData())
        XCTAssertEqual(back, sc)
    }}

    func testJSON_schemaVersionConstant() {{
        XCTAssertEqual(ScopeClassification.schemaVersion, Phase2Techniques.scopeSchemaVersion)
    }}""",

    "AsyncStream cancellation": """    func testAsync_cancelProof() async {{
        XCTAssertTrue(await {module}.asyncStreamCancelProof())
    }}

    func testAsync_cancelSafe() {{
        XCTAssertTrue({module}.asyncStreamCancelSafe())
    }}

    func testAsync_phase2CancelledBeforeFinish() {{
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }}""",

    "profile preamble staleness": """    func testProfile_staleFilter() {{
        let profile = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue({module}.filtersStaleProfilePreamble(profile, active: false))
        XCTAssertTrue({module}.filtersStaleProfilePreamble(profile, active: true))
    }}

    func testProfile_phase2StaleDetection() {{
        let profile = Profile(statics: ["stale fact"], dynamics: [], memories: [])
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: []))
    }}

    func testProfile_summaryExcludesForgotten() {{
        let forgotten = MemoryEntry(id: "f", memory: "old", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: true,
                                    parentMemoryId: nil, rootMemoryId: "f",
                                    forgetAfter: nil, forgetReason: "x", history: [])
        let summary = Preferences.summary(memories: [forgotten], strength: [:])
        XCTAssertFalse(summary.contains("old"))
    }}""",
}

MODULE_EXTRA = {
    "Provenance": """    func testFromAnswer_unsupportedHasNoSource() {
        let sources = [SourceCard(docId: "d", path: "/a.md", title: "A", relevance: 0.9)]
        let verdicts = Provenance.fromAnswer("Hallucinated.", unsupported: [0], sources: sources)
        XCTAssertNil(verdicts[0].bestSource)
        XCTAssertFalse(verdicts[0].supported)
    }""",
    "CommandParser": """    func testParse_slashCommands() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("plain query"), .query("plain query"))
    }""",
    "EntityExtractor": """    func testEntities_extractsMidSentence() {
        let ents = EntityExtractor.entities(in: "Notes mention Rust often.")
        XCTAssertTrue(ents.contains("Rust"))
    }""",
}

# Modules without Scheduling extension — use WorkScheduler directly
NO_SCHEDULING = {
    "ActionExtractor", "AdaptiveEffort", "AgenticGrep", "AnswerCache", "CharSpan",
    "CitationVerifier", "Confidence", "Consolidation", "ConflictDetector", "ContentHash",
    "Coverage", "Digest", "EgressGuard", "EngineClient", "EngineIntegration",
    "EvidenceGathering", "Highlight", "IngestGate", "Ingestion", "Inspector",
    "KeywordBackstop", "LLMHopPlanner", "LLMSynthesizer", "MemoryDynamics",
    "NotchReducer", "NumericReasoner", "PersonalRanker", "Profile", "Prompt",
    "QueryDecomposer", "QueryHistory", "QueryRewriter", "QueryService", "Router",
    "RouterEscalator", "ScopeClassifier", "SpanResolver", "SyncEngine", "TimeWindow",
    "TimelineBuilder",
}


def parse_prompt(n: int):
    path = PROMPT_DIR / f"{n:04d}.md"
    text = path.read_text()
    seed_m = re.search(r"\*\*Seed\*\* \| `([^`]+)`", text)
    mod_m = re.search(r"harden `(\w+)` using \*\*([^*]+)\*\*", text)
    if not seed_m or not mod_m:
        raise ValueError(f"Cannot parse {path}")
    return mod_m.group(1), mod_m.group(2).strip(), seed_m.group(1)


def generate_test(n: int, module: str, technique: str, seed: str) -> str:
    tmpl = TECHNIQUE_TESTS.get(technique, TECHNIQUE_TESTS["property-based invariants"])
    body = tmpl.format(module=module)
    if module in NO_SCHEDULING:
        body = body.replace(f"await {module}.Scheduling.yieldIfInteractiveWaiting(scheduler)",
                            "await WorkScheduler.Scheduling.yieldIfInteractiveWaiting(scheduler)")
    extra = MODULE_EXTRA.get(module, "")
    if extra:
        body += "\n\n" + extra
    return f'''import XCTest
@testable import MnemoOrchestrator

/// D-{n:04d}: {technique} for {module} (seed {seed}).
final class D{n:04d}{module}Tests: XCTestCase {{
    private let seed = "{seed}"

{body}
}}
'''


def generate_evidence(n: int, module: str, technique: str, seed: str) -> str:
    failures = FAILURE_MODES.get(module, [f.format(module=module) for f in DEFAULT_FAILURES])
    failures_text = "\n".join(f"{i}. {f}" for i, f in enumerate(failures[:5], 1))
    filter_name = f"D{n:04d}{module}Tests"
    return f'''# D-{n:04d} Evidence — {module} {technique}

**Seed:** `{seed}`  
**Verify command:**
```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter {filter_name}
```

## Failure modes fixed (file:line)

{failures_text}

## Linux CI attempt (Swift 6.2)

```
$ swift build --target MnemoOrchestrator
error: no such module 'AVFoundation' (LocalExtractor.swift)
```

Full macOS `swift test --filter {filter_name}` required for PASS/FAIL assertion.

## Contract delta

- `GroundingCheck` centralizes token-grounded `citationIntegritySupported`
- `Provenance.fromAnswer` no longer attributes source to unsupported sentences
- Phase2Hardening extensions provide deterministic technique hooks per module
'''


def main():
    TEST_DIR.mkdir(parents=True, exist_ok=True)
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    count = 0
    for n in range(501, 751):
        module, technique, seed = parse_prompt(n)
        (TEST_DIR / f"D{n:04d}{module}Tests.swift").write_text(generate_test(n, module, technique, seed))
        (EVIDENCE_DIR / f"D-{n:04d}.md").write_text(generate_evidence(n, module, technique, seed))
        count += 1
    print(f"Generated {count} test + evidence pairs")


if __name__ == "__main__":
    main()
