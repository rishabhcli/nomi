#!/usr/bin/env python3
"""
Generate 1500 chronologically ordered, domain-isolated agent prompts for Mnemo.
Three agents × 500 prompts each: backend, frontend, observability.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "agent-prompts"

# ── Agent metadata ──────────────────────────────────────────────────────────

@dataclass(frozen=True)
class Agent:
    id: str
    slug: str
    name: str
    owns: str
    forbidden: str
    verify_cmd: str


AGENTS = {
    "a": Agent(
        id="A",
        slug="agent-a-backend",
        name="Backend / Orchestrator",
        owns="`Sources/MnemoOrchestrator/**`, `Tests/MnemoOrchestratorTests/**`, query-related `mnemoctl` subcommands",
        forbidden="`Sources/MnemoApp/**` (views, Metal, AppKit shell), `MnemoSupervisor/**`, `MnemoCore/**` except reading config types",
        verify_cmd="DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter MnemoOrchestrator",
    ),
    "b": Agent(
        id="B",
        slug="agent-b-frontend",
        name="Frontend / Notch UI",
        owns="`Sources/MnemoApp/**`, UI logic tests (`NotchReducerTests`, `NotchShapeTests`, `VoiceOrbTests`, `StateMachineTests`, `NotchGeometryTests`)",
        forbidden="`QueryService` internals, `EngineClient`, `EgressGuard` implementation, process supervision, `mnemo.toml` schema changes",
        verify_cmd="DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter 'Notch|VoiceOrb|State'",
    ),
    "c": Agent(
        id="C",
        slug="agent-c-observability",
        name="Observability / Infra",
        owns="`MnemoCore/**`, `MnemoSupervisor/**`, `mnemo.toml`, `scripts/**`, infra `mnemoctl` commands, structured logging",
        forbidden="Answer-quality heuristics, citation verification logic, UI motion tokens, Liquid Glass rendering",
        verify_cmd="DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter 'MnemoCore|MnemoSupervisor' && .build/debug/mnemoctl audit",
    ),
}

INVARIANT_BLOCK = """## Non-negotiable invariants (P0 — build-breaking if violated)

1. **Loopback only** — every bind/listen/connect target is `127.0.0.1`. Never `0.0.0.0`, never LAN, never cloud hosts in runtime paths.
2. **No cloud backing store** — `smfs.backing_store` must equal `engine.base_url`.
3. **Local model only** — all generation via Ollama; no hosted-inference fallback.
4. **Egress measured at zero** — non-loopback connection attempts during a query must remain **0**.
5. **No telemetry** — no analytics, crash reporters, or usage stats that egress.
6. **No silent failures** — every terminal state renders defined output; empty screens are bugs.

**Litmus test:** unplug the network — this task's outcome must still hold."""

PROCESS_BLOCK = """## Required process

1. Read `CLAUDE.md` before touching code.
2. Use `superpowers:systematic-debugging` if investigating a failure.
3. Use `superpowers:test-driven-development` — write or extend the acceptance test **first**, watch it fail, then implement.
4. Use `superpowers:verification-before-completion` — capture command output as evidence before claiming done.
5. One purpose only — if you discover unrelated issues, note them; do not fix them in this prompt."""

# ── Phase definitions (chronological within each agent) ─────────────────────

PHASES_A = [
    (1, 40, "Foundation", "Read codebase, establish mental model, add missing smoke tests"),
    (41, 80, "P0/P1 Correctness", "Fix data-loss risks, grounding bugs, egress edge cases"),
    (81, 120, "Query Lifecycle", "Router, decomposition, effort, state machine events"),
    (121, 160, "Retrieval & Citations", "Engine client, agentic grep, verifier, spans"),
    (161, 200, "Ingestion & Sync", "IngestIndex, gates, self-heal, content hash"),
    (201, 240, "Memory Dynamics", "Supersession, TTL, contradiction, inspector ledger"),
    (241, 280, "Consolidation", "Dreaming, synthesis dedup, cold archive, profile promotion"),
    (281, 320, "Intelligence & Expressiveness", "Timeline, numeric reasoner, follow-ups, style"),
    (321, 360, "Concurrency & Latency", "WorkScheduler, first-token SLA, context trimming"),
    (361, 400, "CLI & Integration", "mnemoctl subcommands, engine wiring, fixtures"),
    (401, 440, "Regression Hardening", "BugfixRegressionTests, use-case failures, edge cases"),
    (441, 500, "Polish & Beats-Siri", "Helpfulness, smarter-than-Siri criteria, final gates"),
]

PHASES_B = [
    (1, 40, "Foundation", "Understand notch architecture, reducer contract, panel lifecycle"),
    (41, 80, "State Machine Rendering", "Every TerminalState and QueryEvent phase renders beautifully"),
    (81, 120, "Liquid Glass", "Real glassEffect APIs, single container, morph IDs"),
    (121, 160, "Motion & Animation", "Springs, blur-morph, Reduce Motion, glitch elimination"),
    (161, 200, "Notch Geometry", "Physical + virtual notch, multi-display, runtime NSScreen"),
    (201, 240, "Voice Orb & Dictation", "Metal shader 120fps, mic envelope, on-device Speech"),
    (241, 280, "Reasoning & Observability UI", "Surface .reasoning, .understanding, provenance beautifully"),
    (281, 320, "Source Cards & Citations UI", "Sub-second source render, char-span preview, Finder open"),
    (321, 360, "Recovery & Onboarding", "One-tap recovery for every terminal state"),
    (361, 400, "Accessibility", "VoiceOver, Increase Contrast, keyboard navigation"),
    (401, 440, "Interaction Polish", "Hover dwell, hotkey summon, in-flight query lock"),
    (441, 500, "Demo Fidelity", "UI torture, beats-siri surface, M12 acceptance checklist"),
]

PHASES_C = [
    (1, 40, "Foundation", "Config invariants, stack health, audit tooling"),
    (41, 80, "Structured Logging", "Query-id tracing, latency breakdown, local-only logs"),
    (81, 120, "Config Wiring", "Unparsed mnemo.toml sections → MnemoConfig"),
    (121, 160, "Egress & Privacy", "Guard hardening, privacy indicator contract, airplane parity"),
    (161, 200, "Process Supervision", "Ollama warmup, engine restart, smfs mount health"),
    (201, 240, "Metrics & SLA", "first_token_ms, sources_render_ms, bench automation"),
    (241, 280, "Harness & CI", "run-usecases isolation, smoke, acceptance scripts"),
    (281, 320, "mnemoctl Commands", "Every subcommand documented, tested, observable output"),
    (321, 360, "Documentation Recovery", "PLAN.md, UI.md, Shared/ alignment"),
    (361, 400, "Debug & Diagnostics", "Debug hooks, geometry logs, headless verification"),
    (401, 440, "Integration Probes", "Live stack health, document error rate, extraction failures"),
    (441, 500, "Operational Excellence", "CI gates, release checklist, observability dashboard hooks"),
]

# ── Task generators ─────────────────────────────────────────────────────────

BACKEND_FILES = [
    "QueryService.swift", "Router.swift", "RouterEscalator.swift", "EvidenceGathering.swift",
    "EngineClient.swift", "EngineIntegration.swift", "CitationVerifier.swift", "SpanResolver.swift",
    "CharSpan.swift", "AgenticGrep.swift", "KeywordBackstop.swift", "LLMHopPlanner.swift",
    "ContextAssembler.swift", "Prompt.swift", "OllamaClient.swift", "Ingestion.swift",
    "IngestGate.swift", "SyncEngine.swift", "ContentHash.swift", "MemoryDynamics.swift",
    "ConflictDetector.swift", "Consolidation.swift", "LLMSynthesizer.swift", "Inspector.swift",
    "Profile.swift", "EgressGuard.swift", "WorkScheduler.swift", "NotchReducer.swift",
    "QueryRewriter.swift", "QueryDecomposer.swift", "ScopeClassifier.swift", "AdaptiveEffort.swift",
    "AnswerCache.swift", "QueryHistory.swift", "PersonalRanker.swift", "NumericReasoner.swift",
    "TimeWindow.swift", "TimelineBuilder.swift", "ResponseStyle.swift", "FollowUp.swift",
    "Confidence.swift", "Provenance.swift", "CommandParser.swift", "EntityExtractor.swift",
    "MediaCompanion.swift", "LocalExtractor.swift", "Digest.swift", "Preferences.swift",
    "Coverage.swift", "Highlight.swift", "ActionExtractor.swift", "CorpusSuggester.swift",
]

BACKEND_TESTS = [
    "QueryServiceTests", "QueryLifecycleTests", "StateMachineTests", "RouterTests",
    "CitationVerifierTests", "EngineClientTests", "EngineIntegrationTests", "AgenticGrepTests",
    "IngestIndexTests", "IngestGateTests", "SyncEngineTests", "MemoryDynamicsTests",
    "ConsolidationTests", "InspectorTests", "EgressGuardTests", "EgressHostAndCitationTests",
    "SchedulerTests", "BugfixRegressionTests", "HelpfulnessTests", "SmarterThanSiriTests",
    "IntelligenceTests", "ExpressivenessTests", "HopPlannerTests", "SpanResolverTests",
    "CharSpanTests", "DocumentsTests", "ProfileTests", "CommandParserTests", "NotchReducerTests",
]

BACKEND_BUGS = [
    ("SelfHeal.orphanedMemoryIds deletes source-less consolidation memories", "SyncEngine.swift", "P1", "Exempt syntheses, promoted facts, and manual `memory add` entries from orphan GC; add regression test proving they survive `sync self-heal`."),
    ("SuppressionLedger exact-text match resurrects re-ingested facts", "Inspector.swift", "P2", "Implement normalized/fuzzy keying so semantically identical facts stay suppressed after re-extraction with different wording."),
    ("LexicalContradiction only handles location/employment predicates", "MemoryDynamics.swift", "P2", "Extend contradiction detection to temporal, numeric, and relationship predicates without false-positive supersession storms."),
    ("ColdArchive never archives never-retrieved memories", "Consolidation.swift", "P2", "Add conservative cold-archive policy for stale, never-retrieved memories with opt-out via config `[dreaming].archive_never_retrieved`."),
    ("QueryService abs(q0.hashValue) traps on Int.min", "QueryService.swift", "P3", "Replace with overflow-safe hashing for cache keys."),
    ("AgenticGrep returns (unknown) filepaths from SMFS", "AgenticGrep.swift", "P3", "Map SMFS semantic hits to real filesystem paths via ingest index."),
    ("First-token P95 2.9–3.5s vs 1500ms SLA", "QueryService.swift", "P2", "Profile and reduce prefill latency without sacrificing grounding quality."),
    ("38% engine documents in error state", "EngineIntegration.swift", "P2", "Surface per-document extraction failures and retry policy without blocking interactive queries."),
]

FRONTEND_FILES = [
    "NotchSurfaceView.swift", "SurfaceBlocks.swift", "NotchViewModel.swift", "NotchController.swift",
    "NotchPanel.swift", "NotchShape.swift", "Motion.swift", "HoverDetector.swift", "Dictation.swift",
    "VoiceOrbView.swift", "VoiceOrb.metal", "Narrator.swift", "AppCommandHandler.swift",
    "BackgroundSync.swift", "CorpusControl.swift", "DebugHooks.swift", "main.swift",
    "NotchGeometry+NSScreen.swift",
]

FRONTEND_EVENTS = [
    ".routed", ".understanding", ".sources", ".token", ".citation", ".retrying",
    ".suggestions", ".entities", ".related", ".reasoning", ".state", ".done",
]

FRONTEND_TERMINAL = [
    ".indexing", ".empty", ".emptyCorpus", ".modelNotLoaded", ".engineUnreachable", ".unsupportedAnswer",
]

OBS_CONFIG_KEYS = [
    ("dreaming", "enabled", "Wire `[dreaming]` section into MnemoConfig and Consolidator scheduling."),
    ("dreaming", "interval_hours", "Expose dream interval; validate > 0 at startup."),
    ("privacy", "show_egress_indicator", "Drive privacy dot visibility from config."),
    ("ui", "summon_hotkey", "Load global hotkey from config instead of hardcoding."),
    ("ui", "glass_prominence", "Expose glass style token from config."),
    ("sla", "sources_render_ms", "Add automated test that sources render within SLA."),
    ("sla", "first_token_ms", "Wire bench thresholds to config validation warnings."),
    ("sync", "queue_max", "Enforce background sync queue cap from config."),
]

OBS_COMMANDS = [
    "start", "stop", "restart-engine", "audit", "health", "ask", "ingest-status",
    "watch-ingest", "profile", "agentic", "media-sync", "memory", "backstop", "entity",
    "preferences", "digest", "sync", "dream", "inspect", "egress-check", "bench",
    "containers", "processing", "upload", "context", "forget-scope", "chunks", "hash",
]

OBS_SCRIPTS = [
    "smoke.sh", "airplane-parity.sh", "run-usecases.sh", "ui-torture.sh",
    "bulk-ingest.sh", "drain-watchdog.sh", "build-app.sh", "analyze-frames.py",
]


def phase_for(n: int, phases: list) -> tuple[str, str]:
    for start, end, name, desc in phases:
        if start <= n <= end:
            return name, desc
    return "Final", "Completion gates"


def priority_for(n: int, agent: str) -> str:
    if n <= 80:
        return "P0" if n <= 40 else "P1"
    if n <= 200:
        return "P1"
    if n <= 360:
        return "P2"
    return "P3"


# ── Per-agent prompt builders ─────────────────────────────────────────────────

def build_backend_prompt(n: int) -> dict:
    phase, phase_desc = phase_for(n, PHASES_A)
    pri = priority_for(n, "a")
    f = BACKEND_FILES[(n - 1) % len(BACKEND_FILES)]
    t = BACKEND_TESTS[(n - 1) % len(BACKEND_TESTS)]

    if 41 <= n <= 48:
        bug = BACKEND_BUGS[n - 41]
        title = f"Fix: {bug[0]}"
        objective = bug[3]
        target = f"`Sources/MnemoOrchestrator/{bug[1]}`"
        test = f"Add or extend `Tests/MnemoOrchestratorTests/{t}.swift`"
    elif n <= 40:
        objectives = [
            f"Read `{f}` end-to-end and document every public entry point in a code comment block at file top (max 15 lines). Add one missing unit test in `{t}.swift` for an uncovered branch.",
            f"Audit `{f}` for force-unwraps, `try!`, and silent empty catch blocks — eliminate any that could surface as empty UI on the query path.",
            f"Verify `{f}` never constructs a URL with a non-loopback host. Add invariant assertion test in `InvariantTests` or `{t}.swift`.",
            f"Ensure `{f}` logs nothing at info level that could contain user document text. Redact or downgrade to debug.",
            f"Add doc comment to every public type in `{f}` explaining its single responsibility and which milestone (M1–M12) it serves.",
        ]
        objective = objectives[(n - 1) % len(objectives)]
        title = f"Foundation audit: {f}"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/{t}.swift`"
    elif 81 <= n <= 120:
        objective = (
            f"Harden query lifecycle in `{f}`: every failure mode must emit a `QueryEvent` "
            f"that `NotchReducer` can render — never swallow errors. Add lifecycle test in `{t}.swift` "
            f"covering prompt #{n}'s specific branch (route ambiguity, empty evidence, or retry)."
        )
        title = f"Query lifecycle: {f} event completeness"
        target = f"`Sources/MnemoOrchestrator/{f}` + `NotchReducer.swift`"
        test = f"`Tests/MnemoOrchestratorTests/{t}.swift` or `QueryLifecycleTests.swift`"
    elif 121 <= n <= 160:
        objective = (
            f"Raise retrieval/citation quality in `{f}`: char-offset spans must resolve to real corpus text; "
            f"unsupported sentences must reach `.unsupportedAnswer`. Add deterministic fixture test in `{t}.swift`."
        )
        title = f"Grounding: {f} citation integrity"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/CitationVerifierTests.swift` or `{t}.swift`"
    elif 161 <= n <= 200:
        objective = (
            f"Improve ingestion/sync in `{f}`: indexing terminal state must include accurate path/progress; "
            f"self-heal must never delete user memories. Test with `Tests/Fixtures/corpus/` in `{t}.swift`."
        )
        title = f"Ingestion: {f} reliability"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/IngestIndexTests.swift` or `{t}.swift`"
    elif 201 <= n <= 240:
        objective = (
            f"Strengthen memory dynamics in `{f}`: supersession in-place, TTL expiry, contradiction detection. "
            f"Prove with `{t}.swift` that re-asked queries reflect forgotten facts after `/forget`."
        )
        title = f"Memory: {f} dynamics"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/MemoryDynamicsTests.swift` or `{t}.swift`"
    elif 241 <= n <= 280:
        objective = (
            f"Consolidation pass in `{f}`: dreaming must not duplicate syntheses, must cite constituents, "
            f"and must remain subject to M5 verification. Regression in `{t}.swift`."
        )
        title = f"Consolidation: {f} dreaming safety"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/ConsolidationTests.swift`"
    elif 281 <= n <= 320:
        objective = (
            f"Expressiveness in `{f}`: timeline/table/bullet shaping for cross-doc synthesis; "
            f"beat Siri's PCC-dependent synthesis offline. Add case to `SmarterThanSiriTests` or `{t}.swift`."
        )
        title = f"Intelligence: {f} expressiveness"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/SmarterThanSiriTests.swift`"
    elif 321 <= n <= 360:
        objective = (
            f"Concurrency/latency in `{f}`: interactive queries preempt `.utility` background work; "
            f"measure first-token contribution. Extend `SchedulerTests` / `m11-slo-report.txt` fixture."
        )
        title = f"Latency: {f} scheduling"
        target = f"`Sources/MnemoOrchestrator/{f}` + `WorkScheduler.swift`"
        test = f"`Tests/MnemoOrchestratorTests/SchedulerTests.swift`"
    elif 361 <= n <= 400:
        objective = (
            f"Wire `{f}` behavior through `mnemoctl` for headless acceptance: human-readable progress, "
            f"JSON `--format` option, exit codes documented. Mirror AT-M* naming."
        )
        title = f"CLI: expose {f} via mnemoctl"
        target = f"`Sources/mnemoctl/main.swift` + `{f}`"
        test = "Run `.build/debug/mnemoctl ask` with fixture corpus offline"
    elif 401 <= n <= 440:
        objective = (
            f"Regression hardening for `{f}`: add case to `BugfixRegressionTests.swift` for a fixed "
            f"2026-07-09 audit item or `{t}.swift` edge case #{n}. Must fail on prior commit, pass now."
        )
        title = f"Regression: {f} edge case #{n}"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/BugfixRegressionTests.swift`"
    else:
        objective = (
            f"Beats-Siri gate for `{f}`: cross-document offline synthesis with verified citations "
            f"and zero egress. Capture evidence via `mnemoctl ask --verify` transcript for prompt #{n}."
        )
        title = f"Beats-Siri: {f} offline synthesis"
        target = f"`Sources/MnemoOrchestrator/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/SmarterThanSiriTests.swift`"

    return {
        "title": title,
        "objective": objective,
        "target": target,
        "test": test,
        "phase": phase,
        "phase_desc": phase_desc,
        "priority": pri,
    }


def build_frontend_prompt(n: int) -> dict:
    phase, phase_desc = phase_for(n, PHASES_B)
    pri = priority_for(n, "b")
    f = FRONTEND_FILES[(n - 1) % len(FRONTEND_FILES)]

    if n <= 40:
        objectives = [
            f"Map every `@State` / `@Published` in `{f}` to a `NotchReducer` phase — eliminate orphan UI state that can desync from backend events.",
            f"Audit `{f}` for hand-rolled blur/vibrancy — replace with real `glassEffect` / `GlassEffectContainer` per CLAUDE.md.",
            f"Ensure `{f}` honors Reduce Motion: replace springs with opacity cross-fade when `accessibilityReduceMotion` is true.",
            f"Verify `{f}` never blocks main thread > 16ms during expand/collapse — profile and fix.",
            f"Add VoiceOver labels to every interactive control in `{f}` via `Narrator` or `.accessibilityLabel`.",
        ]
        objective = objectives[(n - 1) % len(objectives)]
        title = f"Foundation: {f} architecture audit"
        target = f"`Sources/MnemoApp/{f}`"
        test = f"`Tests/MnemoOrchestratorTests/NotchReducerTests.swift` (logic) + manual hover check"
    elif 41 <= n <= 80:
        term = FRONTEND_TERMINAL[(n - 41) % len(FRONTEND_TERMINAL)]
        objective = (
            f"Render terminal state `{term}` in `SurfaceBlocks.swift` with a beautiful, calm layout: "
            f"iconography, recovery CTA, and plain-language copy. Must match Liquid Glass aesthetic. "
            f"No empty panels — every sub-case of `{term}` gets distinct copy."
        )
        title = f"Terminal UI: {term} rendering excellence"
        target = "`Sources/MnemoApp/SurfaceBlocks.swift` + `NotchReducer.swift` messages"
        test = "`Tests/MnemoOrchestratorTests/StateMachineTests.swift` + screenshot via `DebugHooks`"
    elif 81 <= n <= 120:
        objective = (
            f"Liquid Glass fidelity in `{f}`: single `GlassEffectContainer`, `glassEffectID` morph "
            f"from notch collar to input tray, `.buttonStyle(.glass)`. Glass must not sample glass."
        )
        title = f"Liquid Glass: {f} material correctness"
        target = f"`Sources/MnemoApp/{f}`"
        test = "Visual check + `scripts/ui-torture.sh` frame analysis"
    elif 121 <= n <= 160:
        objective = (
            f"Motion spec in `{f}`: springs summon=0.36/0.84, grow=0.32/0.88, collapse=0.30/0.90; "
            f"blur-morph on content swap; one `.animation` on `SurfaceGeometry` — eliminate glitch double-animation."
        )
        title = f"Motion: {f} spring token compliance"
        target = f"`Sources/MnemoApp/Motion.swift` + `{f}`"
        test = "`scripts/analyze-frames.py` on torture capture"
    elif 161 <= n <= 200:
        objective = (
            f"Notch geometry in `{f}`: read `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea` at runtime; "
            f"virtual notch on external displays; multi-monitor hover handoff without duplicate panels."
        )
        title = f"Geometry: {f} runtime notch rect"
        target = f"`Sources/MnemoApp/{f}` + `NotchGeometry+NSScreen.swift`"
        test = "`Tests/MnemoOrchestratorTests/NotchGeometryTests.swift`"
    elif 201 <= n <= 240:
        objective = (
            f"Voice pipeline in `{f}`: on-device `SpeechAnalyzer` only; Metal orb at 120fps; "
            f"`MicEnvelope` attack/release smooth; press-hold affordance obvious; audio never egresses."
        )
        title = f"Voice: {f} dictation + orb polish"
        target = f"`Sources/MnemoApp/{f}` + `VoiceOrb.metal`"
        test = "`Tests/MnemoOrchestratorTests/VoiceOrbTests.swift`"
    elif 241 <= n <= 280:
        evt = FRONTEND_EVENTS[(n - 241) % len(FRONTEND_EVENTS)]
        objective = (
            f"**Observability UI:** beautifully surface `QueryEvent{evt}` in the notch answer zone — "
            f"animated reasoning trace, retrieval hops, verification progress. User must *see* what Mnemo "
            f"is doing without raw logs. Design: collapsible timeline, subtle glass chips, auto-dismiss on `.done`."
        )
        title = f"Reasoning UI: display {evt} beautifully"
        target = "`Sources/MnemoApp/SurfaceBlocks.swift` + `NotchSurfaceView.swift`"
        test = "Manual: submit query, confirm reasoning visible before answer completes"
    elif 281 <= n <= 320:
        objective = (
            f"Source cards in `{f}`: render within `sources_render_ms` SLA; char-span preview on hover; "
            f"Finder reveal on click; citation chips inline in markdown answer."
        )
        title = f"Sources UI: {f} citation cards"
        target = f"`Sources/MnemoApp/SurfaceBlocks.swift`"
        test = "Time-to-first-source-card < 1000ms measured in UI test hook"
    elif 321 <= n <= 360:
        objective = (
            f"Recovery UX in `{f}`: one-tap actions for every `TerminalState` recovery enum "
            f"(waitAndRetry, broaden, addFiles, loadModel, restartEngine) — wired to `AppCommandHandler`."
        )
        title = f"Recovery: {f} one-tap repair flows"
        target = f"`Sources/MnemoApp/AppCommandHandler.swift` + `{f}`"
        test = "`Tests/MnemoOrchestratorTests/StateMachineTests.swift`"
    elif 361 <= n <= 400:
        objective = (
            f"Accessibility in `{f}`: VoiceOver reads answer + citations in logical order; "
            f"Increase Contrast raises glass border visibility; ESC dismiss announced."
        )
        title = f"A11y: {f} inclusive design"
        target = f"`Sources/MnemoApp/Narrator.swift` + `{f}`"
        test = "VoiceOver rotor navigation manual checklist"
    elif 401 <= n <= 440:
        objective = (
            f"Interaction polish in `{f}`: hover dwell before collapse; in-flight query lock prevents "
            f"duplicate summon; single-instance enforcement; global hotkey summon from config."
        )
        title = f"Interaction: {f} hover/summon hardening"
        target = f"`Sources/MnemoApp/NotchController.swift` + `HoverDetector.swift`"
        test = "Regression: rapid hover-out/in during streaming — no duplicate panel"
    else:
        objective = (
            f"M12 demo fidelity in `{f}`: run `scripts/m12-acceptance.md` checklist item #{n - 440}; "
            f"capture evidence; fix any FAIL. Target: beats-siri surface quality offline."
        )
        title = f"M12 acceptance: {f} demo gate #{n - 440}"
        target = f"`Sources/MnemoApp/{f}` + `scripts/m12-acceptance.md`"
        test = "`scripts/ui-torture.sh` + manual AT-M12 checklist"

    return {
        "title": title,
        "objective": objective,
        "target": target,
        "test": test,
        "phase": phase,
        "phase_desc": phase_desc,
        "priority": pri,
    }


def build_observability_prompt(n: int) -> dict:
    phase, phase_desc = phase_for(n, PHASES_C)
    pri = priority_for(n, "c")
    cmd = OBS_COMMANDS[(n - 1) % len(OBS_COMMANDS)]
    script = OBS_SCRIPTS[(n - 1) % len(OBS_SCRIPTS)]

    if n <= 40:
        objectives = [
            "Validate `MnemoConfig.swift` rejects cloud hosts, LAN binds, and backing-store mismatch at startup with tested exit codes 3/0.",
            "Extend `LoopbackAudit.swift` to parse `lsof` output for Rivet/smfs edge ports; document in `mnemoctl audit` help.",
            "Ensure `StackHealth.swift` aggregates ollama+engine+smfs with actionable unhealthy reasons.",
            "Add version stamp to `MnemoCore/Placeholder.swift` from git tag or build flag — surface in `mnemoctl health`.",
            "Harden `TOML.swift` parser against malformed `mnemo.toml` — fail closed with line numbers.",
        ]
        objective = objectives[(n - 1) % len(objectives)]
        title = f"Foundation: config/audit gate #{n}"
        target = "`Sources/MnemoCore/` + `Sources/MnemoSupervisor/LoopbackAudit.swift`"
        test = "`Tests/MnemoCoreTests/InvariantTests.swift` + `mnemoctl audit`"
    elif 41 <= n <= 80:
        facets = [
            "query_id", "route_intent", "effort_tier", "retrieval_hop_count",
            "first_token_ms", "total_ms", "egress_blocked_count", "verification_pass_rate",
            "context_token_count", "model_id", "terminal_state",
        ]
        facet = facets[(n - 41) % len(facets)]
        objective = (
            f"Implement structured logging of `{facet}` to `~/Library/Logs/Mnemo/app.jsonl` "
            f"(one JSON object per query, no document body at info level). Add redaction tests."
        )
        title = f"Structured log: emit {facet}"
        target = "New `Sources/MnemoCore/StructuredLog.swift` + wire in `QueryService` via protocol"
        test = "Parse log file after `mnemoctl ask`; assert field present"
    elif 81 <= n <= 88:
        cfg = OBS_CONFIG_KEYS[n - 81]
        objective = cfg[2]
        title = f"Config wire: [{cfg[0]}] {cfg[1]}"
        target = f"`mnemo.toml` + `Sources/MnemoCore/MnemoConfig.swift`"
        test = "`Tests/MnemoCoreTests/ConfigTests.swift`"
    elif 89 <= n <= 120:
        extra_keys = [
            "engine.timeout_ms", "model.keepalive", "ingest.poll_interval",
            "retrieval.max_hops", "verification.strict_mode", "profile.max_facts",
            "ui.panel_level", "smfs.mount_path", "logging.level", "logging.rotation_mb",
            "bench.warmup_runs", "bench.sample_size", "health.probe_interval",
            "supervisor.restart_backoff", "dreaming.max_synthesis_tokens",
            "privacy.block_on_egress", "sync.self_heal_enabled", "ingest.max_file_mb",
            "retrieval.chunk_limit", "context.max_tokens", "router.escalation_threshold",
            "media.retry_count", "inspector.suppression_ttl_days",
        ]
        key = extra_keys[(n - 89) % len(extra_keys)]
        objective = (
            f"Parse and validate `mnemo.toml` key `{key}`: wire into `MnemoConfig`, "
            f"fail startup if invalid, expose via `mnemoctl health --verbose`."
        )
        title = f"Config: wire {key}"
        target = "`Sources/MnemoCore/MnemoConfig.swift` + `mnemo.toml`"
        test = "`Tests/MnemoCoreTests/ConfigTests.swift`"
    elif 121 <= n <= 160:
        objective = (
            f"Egress observability #{n - 120}: strengthen `EgressGuard` measurement; "
            f"ensure `mnemoctl egress-check` prints blocked host list; "
            f"`scripts/airplane-parity.sh` step maps to this invariant."
        )
        title = f"Privacy: egress measurement hardening #{n - 120}"
        target = "`Sources/MnemoOrchestrator/EgressGuard.swift` (read-only contract) + `mnemoctl`"
        test = "`Tests/MnemoOrchestratorTests/EgressGuardTests.swift` + `airplane-parity.sh`"
    elif 161 <= n <= 200:
        objective = (
            f"Supervision reliability: `ProcessSupervisor` + `SystemProcessLauncher` — "
            f"restart policy for engine/Ollama crash, log rotation in `~/Library/Logs/Mnemo/`, "
            f"warmup confirmation before marking healthy."
        )
        title = f"Supervisor: process health probe #{n - 160}"
        target = "`Sources/MnemoSupervisor/ProcessSupervisor.swift`"
        test = "`Tests/MnemoSupervisorTests/ProcessSupervisorTests.swift`"
    elif 201 <= n <= 240:
        objective = (
            f"SLA metric #{n - 200}: automate `mnemoctl bench` threshold comparison against "
            f"`mnemo.toml [sla]`; emit PASS/FAIL report artifact to `Tests/Fixtures/`."
        )
        title = f"Metrics: SLA automation #{n - 200}"
        target = "`Sources/mnemoctl/main.swift` bench subcommand + `mnemo.toml [sla]`"
        test = "Compare output to `Tests/Fixtures/m11-slo-report.txt` format"
    elif 241 <= n <= 280:
        objective = (
            f"Harness #{n - 240}: fix `scripts/{script}` — isolated build dir for `run-usecases.sh`, "
            f"no mid-run binary clobber; green 105-case run; capture log artifact."
        )
        title = f"Harness: {script} reliability"
        target = f"`scripts/{script}`"
        test = f"Run ./{script} and capture exit 0 + output"
    elif 281 <= n <= 320:
        objective = (
            f"`mnemoctl {cmd}`: add `--verbose` reasoning trace for user observability; "
            f"document flags in `--help`; integration test with stub engine; stable JSON schema."
        )
        title = f"CLI observability: {cmd} command polish"
        target = f"`Sources/mnemoctl/main.swift` ({cmd} subcommand)"
        test = f".build/debug/mnemoctl {cmd} --help && offline invocation"
    elif 321 <= n <= 360:
        sections = [
            "M0 bootstrap acceptance tests (AT-M0.*)",
            "M1 thin slice (AT-M1.*)",
            "M2 ingestion (AT-M2.*)",
            "M3 retrieval (AT-M3.*)",
            "M4 query lifecycle (AT-M4.*)",
            "M5 grounding (AT-M5.*)",
            "M6 memory dynamics (AT-M6.*)",
            "M7 sync (AT-M7.*)",
            "M8 consolidation (AT-M8.*)",
            "M9 inspector (AT-M9.*)",
            "M10 offline privacy (AT-M10.*)",
            "M11 concurrency (AT-M11.*)",
            "M12 notch UI (AT-M12.*)",
            "UI.md motion tokens",
            "Appendix A config schema",
            "Appendix B observability metrics",
            "Appendix C testing strategy",
            "Appendix D dependency graph",
            "Global data model / Shared types",
            "BS-M12 beats-Siri criteria",
        ]
        sec = sections[(n - 321) % len(sections)]
        objective = (
            f"Documentation recovery: reconstruct `{sec}` in `PLAN.md` or `UI.md` from "
            f"`docs/superpowers/plans/`, code comments, and tests. No placeholders."
        )
        title = f"Docs: restore {sec}"
        target = "`PLAN.md` or `UI.md` (create if missing)"
        test = "No broken internal links; peer review checklist"
    elif 361 <= n <= 400:
        objective = (
            f"Diagnostics #{n - 360}: extend `DebugHooks.swift` contract — geometry snapshots, "
            f"reasoning event stream to `/tmp/mnemo-geometry.log`, headless PNG captures for CI."
        )
        title = f"Debug hooks: headless verification #{n - 360}"
        target = "`Sources/MnemoApp/DebugHooks.swift` (contract only) + infra runner script"
        test = "`MNEMO_DEBUG_HOOKS=1` run + log parse"
    elif 401 <= n <= 440:
        objective = (
            f"Live stack probe #{n - 400}: script checks engine document error rate, "
            f"extraction failures, smfs mount health — report JSON for user dashboard."
        )
        title = f"Integration probe: stack health #{n - 400}"
        target = f"`scripts/smoke.sh` extension or new `scripts/stack-report.sh`"
        test = "Offline stack returns structured JSON report"
    else:
        objective = (
            f"Operational gate #{n - 440}: CI pipeline step — `swift test` + `mnemoctl audit` + "
            f"`egress-check` + isolated `run-usecases.sh`; publish badge artifact."
        )
        title = f"CI gate: operational excellence #{n - 440}"
        target = "`.github/workflows/` or `scripts/ci.sh`"
        test = "Simulated CI run exit 0"

    return {
        "title": title,
        "objective": objective,
        "target": target,
        "test": test,
        "phase": phase,
        "phase_desc": phase_desc,
        "priority": pri,
    }


def render_prompt(agent: Agent, n: int, spec: dict) -> str:
    return f"""# [{agent.id}-{n:03d}] {spec['title']}

| Field | Value |
|-------|-------|
| **Queue position** | {n} of 500 (chronological — do not skip) |
| **Agent** | {agent.id} — {agent.name} |
| **Phase** | {spec['phase']} — {spec['phase_desc']} |
| **Priority** | {spec['priority']} |
| **Parallel safe** | Yes — isolated from Agents {'B, C' if agent.id == 'A' else 'A, C' if agent.id == 'B' else 'A, B'} |

---

## Single purpose

{spec['objective']}

---

## Scope

**You own:** {agent.owns}

**Do NOT modify:** {agent.forbidden}

**Primary targets:** {spec['target']}

---

{INVARIANT_BLOCK}

---

{PROCESS_BLOCK}

---

## Acceptance criteria

- [ ] The single purpose above is fully achieved — no scope creep
- [ ] New/changed behavior has automated test coverage: {spec['test']}
- [ ] `swift build` clean with Xcode-beta toolchain
- [ ] Offline verification captured (command + output in commit message or PR)
- [ ] No new file >400 lines without justification
- [ ] Loopback/egress invariants still pass

## Verification commands

```bash
# Agent-specific
{agent.verify_cmd}

# Universal invariant checks
.build/debug/mnemoctl audit
.build/debug/mnemoctl egress-check
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build
```

---

## References

- `CLAUDE.md` — operating manual
- `README.md` — product intent
- `BACKEND-TEST-REPORT.md` — known bugs and verified fixes (2026-07-09)
- `mnemo.toml` — configuration source of truth
- `docs/superpowers/plans/` — milestone plans

---

*Generated for Mnemo parallel agent orchestration. Execute strictly in queue order.*
"""


BUILDERS: dict[str, Callable[[int], dict]] = {
    "a": build_backend_prompt,
    "b": build_frontend_prompt,
    "c": build_observability_prompt,
}


def main() -> None:
    manifest = {"agents": [], "total_prompts": 1500, "generated_at": "2026-07-09"}

    for key, agent in AGENTS.items():
        agent_dir = OUT / agent.slug
        agent_dir.mkdir(parents=True, exist_ok=True)
        agent_manifest = {"id": agent.id, "slug": agent.slug, "prompts": []}

        for n in range(1, 501):
            spec = BUILDERS[key](n)
            filename = f"{n:03d}.md"
            content = render_prompt(agent, n, spec)
            (agent_dir / filename).write_text(content, encoding="utf-8")
            agent_manifest["prompts"].append({
                "n": n,
                "file": filename,
                "title": spec["title"],
                "phase": spec["phase"],
                "priority": spec["priority"],
            })

        manifest["agents"].append(agent_manifest)

    # Master README
    readme = """# Mnemo Agent Prompt Queue — 1500 Prompts

Three parallel agents execute **500 prompts each** in strict chronological order (`001.md` → `500.md`).
Agents work simultaneously on **isolated domains** to avoid merge conflicts and workflow disruption.

## Agent assignment

| Agent | Directory | Domain | Prompts |
|-------|-----------|--------|---------|
| **A** | [`agent-a-backend/`](agent-a-backend/) | Query orchestrator, retrieval, memory, citations | 001–500 |
| **B** | [`agent-b-frontend/`](agent-b-frontend/) | Notch UI, Liquid Glass, voice orb, reasoning display | 001–500 |
| **C** | [`agent-c-observability/`](agent-c-observability/) | Logging, config, supervision, CI, metrics, docs | 001–500 |

## Execution rules

1. **Chronological** — each agent processes prompts in numeric order; never skip ahead.
2. **One purpose** — each prompt has exactly one objective; note unrelated issues but do not fix them.
3. **Parallel safe** — respect scope boundaries in each prompt's "Do NOT modify" section.
4. **Offline first** — every change must hold with network physically off.
5. **Evidence required** — capture verification command output before marking complete.

## Phase progression (all agents)

Each agent's 500 prompts follow 12 chronological phases:

| Prompts | Agent A | Agent B | Agent C |
|---------|---------|---------|---------|
| 001–040 | Foundation audits | UI architecture | Config/audit gates |
| 041–080 | P0/P1 bug fixes | Terminal state rendering | Structured logging |
| 081–120 | Query lifecycle | Liquid Glass | Config wiring |
| 121–160 | Retrieval/citations | Motion/animation | Egress/privacy |
| 161–200 | Ingestion/sync | Notch geometry | Process supervision |
| 201–240 | Memory dynamics | Voice orb/dictation | SLA metrics |
| 241–280 | Consolidation | **Reasoning UI** | Harness/CI scripts |
| 281–320 | Intelligence | Source cards UI | mnemoctl polish |
| 321–360 | Latency/scheduling | Recovery UX | Documentation recovery |
| 361–400 | CLI integration | Accessibility | Debug hooks |
| 401–440 | Regression hardening | Interaction polish | Live stack probes |
| 441–500 | Beats-Siri gates | M12 demo fidelity | CI operational gates |

## Cross-agent coordination

- **Shared contracts** (do not change without coordination):
  - `QueryEvent` / `TerminalState` enum cases
  - `mnemo.toml` schema
  - `NotchReducer` public API
- **Agent C** wires config keys; **Agent A** consumes them; **Agent B** renders them.
- **Agent A** emits `.reasoning` events; **Agent B** displays them (prompts 241–280).
- **Agent C** builds logging; **Agent B** may read log format for debug UI only.

## Queue manifest

See [`manifest.json`](manifest.json) for machine-readable index of all 1500 prompts.

## Regenerating

```bash
python3 scripts/generate-agent-prompts.py
```
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    total = sum(len(list((OUT / a.slug).glob("*.md"))) for a in AGENTS.values())
    print(f"Generated {total} prompt files in {OUT}")


if __name__ == "__main__":
    main()
