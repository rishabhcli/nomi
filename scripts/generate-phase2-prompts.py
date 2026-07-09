#!/usr/bin/env python3
"""
Generate Phase 2: 6000 unique senior-level agent prompts (6 agents × 1000).
Designed for ~50× the depth of Phase 1. Agents commit ONCE at prompt 1000.
"""

from __future__ import annotations

import hashlib
import json
import textwrap
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "phase2"

NO_COMMIT = """## Git discipline (mandatory)

**Do NOT run `git commit` or `git push` until prompt 1000/1000 is complete.**

- Accumulate all code, tests, and evidence locally across the full queue.
- You may use `git stash` / branches locally, but zero per-prompt commits.
- At **1000/1000 only**: one atomic commit per agent:
  - `git add -A && git commit -m "{agent_id}: Phase 2 complete ({agent_id}-001..{agent_id}-1000)"`
  - Then one push.

Phase 1 flooded history with 500+ meaningless commits — that is forbidden here."""

EFFORT = """## Effort contract (~50× Phase 1)

Phase 1 averaged ~3 tool calls per prompt via batch scripts. **You must average 150+ tool calls per prompt.**

Each prompt is a **half-day senior engineer task**, not a checkbox. Minimum per prompt:

1. Read **≥5** relevant source/test files end-to-end (not skim).
2. Write or extend **real** failing tests (never `XCTAssertTrue(true)`).
3. Implement production-quality fix with error paths handled.
4. Run verification commands; capture **full raw output** in `phase2/evidence/{agent_id}-{nnn:04d}.md`.
5. Self-review against invariants; fix issues before advancing.
6. If prompt touches shared contracts (`QueryEvent`, `TerminalState`, `mnemo.toml`), document the contract delta in evidence file.

**Banned forever:** `execute-agent-*.py`, marker files, registry.jsonl theater, comment-only diffs, stub tests."""

INVARIANTS = """## P0 invariants

Loopback only · no cloud backing store · local Ollama only · zero egress during queries · no telemetry · no silent terminal failures. Must hold with network unplugged."""


@dataclass(frozen=True)
class AgentDef:
    id: str
    slug: str
    name: str
    owns: str
    forbidden: str
    verify: str
    branch: str


AGENTS = [
    AgentDef("D", "agent-d-backend", "Backend / Query Brain", "Sources/MnemoOrchestrator/**, Tests/MnemoOrchestratorTests/**, query mnemoctl",
             "Sources/MnemoApp/**, MnemoSupervisor/**, MnemoCore/** (read-only)",
             "DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter MnemoOrchestrator",
             "phase2/agent-d"),
    AgentDef("E", "agent-e-frontend", "Frontend / Notch Experience", "Sources/MnemoApp/**, NotchReducer/Shape/Geometry/VoiceOrb tests",
             "QueryService internals, EngineClient, EgressGuard impl, mnemo.toml schema",
             "DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter 'Notch|VoiceOrb|State|Surface'",
             "phase2/agent-e"),
    AgentDef("F", "agent-f-platform", "Platform / Observability", "MnemoCore/**, MnemoSupervisor/**, mnemo.toml, scripts/**, infra mnemoctl",
             "Citation logic, UI motion tokens, Liquid Glass views",
             "swift test --filter 'MnemoCore|MnemoSupervisor' && mnemoctl audit && mnemoctl egress-check",
             "phase2/agent-f"),
    AgentDef("G", "agent-g-quality", "Quality / Security / Fuzz", "Tests/**, security audits across all modules (read+test), fuzz harnesses in scripts/",
             "No production feature creep without a failing test proving the bug",
             "swift test && rg 'XCTAssertTrue\\(true' Tests/ && scripts/phase2-reject.sh",
             "phase2/agent-g"),
    AgentDef("H", "agent-h-integration", "Integration / E2E / Performance", "scripts/run-usecases.sh, mnemoctl integration, SLA bench, cross-module lifecycle tests",
             "Cosmetic-only UI tweaks without measurable SLO impact",
             "mnemoctl bench && scripts/airplane-parity.sh && MNEMO_BUILD_DIR=.build/ci scripts/run-usecases.sh",
             "phase2/agent-h"),
    AgentDef("I", "agent-i-product", "Product / Docs / Beats-Siri", "PLAN.md, UI.md, docs/**, demos/**, BS-M* acceptance, expressiveness/intelligence tests",
             "Breaking API changes without doc + test migration",
             "swift test --filter 'SmarterThanSiri|Expressiveness|Helpfulness' && test -f UI.md",
             "phase2/agent-i"),
]

# ── Prompt banks (combinatorial uniqueness) ─────────────────────────────────

BACKEND_FILES = [
    "QueryService", "Router", "RouterEscalator", "EvidenceGathering", "EngineClient",
    "EngineIntegration", "CitationVerifier", "SpanResolver", "CharSpan", "AgenticGrep",
    "KeywordBackstop", "LLMHopPlanner", "ContextAssembler", "Prompt", "OllamaClient",
    "Ingestion", "IngestGate", "SyncEngine", "ContentHash", "MemoryDynamics",
    "ConflictDetector", "Consolidation", "LLMSynthesizer", "Inspector", "Profile",
    "EgressGuard", "WorkScheduler", "NotchReducer", "QueryRewriter", "QueryDecomposer",
    "ScopeClassifier", "AdaptiveEffort", "AnswerCache", "QueryHistory", "PersonalRanker",
    "NumericReasoner", "TimeWindow", "TimelineBuilder", "ResponseStyle", "FollowUp",
    "Confidence", "Provenance", "CommandParser", "EntityExtractor", "MediaCompanion",
    "LocalExtractor", "Digest", "Preferences", "Coverage", "Highlight", "ActionExtractor",
]

TECHNIQUES = [
    "property-based invariants", "concurrency stress under WorkScheduler", "char-span fuzzing",
    "offline refusal paths", "cache poisoning resistance", "token budget adversarial trim",
    "router escalation boundaries", "citation verifier false-positive elimination",
    "memory supersession race conditions", "ingest gate timing proofs", "agentic grep deadlock prevention",
    "numeric synthesis distractor immunity", "profile preamble staleness", "answer cache key collision",
    "egress guard host parsing", "subprocess stderr backpressure", "AsyncStream cancellation",
    "TerminalState exhaustiveness", "QueryEvent ordering guarantees", "mnemoctl JSON schema stability",
]

FRONTEND_SURFACES = [
    "NotchSurfaceView", "SurfaceBlocks", "ReasoningTraceView", "NotchViewModel", "NotchController",
    "NotchPanel", "HoverDetector", "Dictation", "VoiceOrbView", "VoiceOrb.metal", "Motion",
    "Narrator", "AppCommandHandler", "InputTray", "terminal recovery CTAs", "source card chips",
    "privacy egress dot", "multi-display handoff", "Reduce Motion morph", "Increase Contrast glass",
]

UX_DIMENSIONS = [
    "perceived latency", "reading-grade typography", "citation affordance", "error recovery clarity",
    "VoiceOver rotor order", "keyboard-only summon", "press-hold dictation discoverability",
    "reasoning trace legibility", "glass material hierarchy", "spring overshoot elimination",
    "120fps orb thermal stability", "empty corpus onboarding", "in-flight query lock UX",
    "unsupported sentence styling", "suggestion chip relevance", "entity chip exploration",
]

PLATFORM_TOPICS = [
    "StructuredLog wiring", "MnemoConfig fail-closed", "LoopbackAudit completeness",
    "ProcessSupervisor restart backoff", "Ollama warmup SLO", "smfs mount health",
    "log rotation privacy", "CI isolated build dir", "sources_render_ms automation",
    "first_token_ms regression gate", "airplane-parity harness", "stack-report JSON",
    "debug hooks headless PNG", "config hot-reload safety", "supervisor log aggregation",
]

QUALITY_VECTORS = [
    "mutation testing mindset", "regression fixture expansion", "BS-M12 transcript audit",
    "invariant property tests", "egress injection attempts", "loopback spoof hostnames",
    "PII log redaction scan", "force-unwrap elimination", "silent catch eradication",
    "test flake dection", "use-case harness isolation", "document error rate tracking",
]

INTEGRATION_SCENARIOS = [
    "cross-doc timeline synthesis offline", "job-finder multi-hop", "profile recall after /forget",
    "ingest-then-query race", "dream-then-query consistency", "engine restart mid-query",
    "model unload recovery", "smfs semantic vs literal grep parity", "bulk ingest under load",
    "concurrent ask + ingest", "warm vs cold first-token bench", "105 use-case green run",
]

PRODUCT_DELIVERABLES = [
    "UI.md motion token", "PLAN.md AT-M acceptance", "BS-M1 offline proof", "BS-M12 demo script",
    "beats-siri.mov storyboard", "Appendix B metric mapping", "Shared/ Codable alignment",
    "expressiveness timeline table", "helpfulness refusal copy", "inspector UX spec",
    "privacy indicator semantics", "hardware tier honest SLA", "comparison table accuracy",
]


def phase(n: int) -> tuple[str, str]:
    phases = [
        (1, 100, "Foundation & Archaeology", "Map every module; delete lies; establish ground truth"),
        (101, 200, "Correctness & Data Safety", "P0/P1 bugs, data-loss, grounding integrity"),
        (201, 300, "Core Path Hardening", "Query lifecycle, retrieval, citations, memory"),
        (301, 400, "Concurrency & Performance", "Scheduler, latency, context economics"),
        (401, 500, "Adversarial & Edge Cases", "Fuzz, malicious inputs, failure injection"),
        (501, 600, "Observability Contracts", "Events, logs, traces, debuggability"),
        (601, 700, "Cross-Module Integration", "Engine↔orchestrator↔UI contracts"),
        (701, 800, "Accessibility & Inclusion", "VO, contrast, motion, keyboard"),
        (801, 900, "Beats-Siri Product Gates", "Offline synthesis superiority proofs"),
        (901, 1000, "Capstone & Synthesis", "End-to-end excellence; final evidence bundle"),
    ]
    for lo, hi, name, desc in phases:
        if lo <= n <= hi:
            return name, desc
    return "Capstone", "Final"


def unique_seed(agent_id: str, n: int) -> str:
    return hashlib.sha256(f"phase2-{agent_id}-{n}".encode()).hexdigest()[:12]


def build_prompt(agent: AgentDef, n: int) -> dict:
    phase_name, phase_desc = phase(n)
    seed = unique_seed(agent.id, n)
    pri = "P0" if n <= 100 else "P1" if n <= 400 else "P2" if n <= 800 else "P3"

    if agent.id == "D":
        f = BACKEND_FILES[(n - 1) % len(BACKEND_FILES)]
        t = TECHNIQUES[(n - 1) % len(TECHNIQUES)]
        title = f"{f}: {t}"
        objective = textwrap.dedent(f"""
            As a **staff backend engineer**, harden `{f}` using **{t}** (seed `{seed}`).

            Deliverables:
            - Identify ≥3 concrete failure modes in current `{f}` implementation with file:line citations.
            - Add **deterministic** XCTest coverage in `Tests/MnemoOrchestratorTests/` (new file or extend; never stub).
            - Refactor only where tests prove necessity; keep files ≤400 lines (split if needed).
            - Prove offline: loopback-only URLs, zero egress during `ask()` path touching `{f}`.
            - If `{f}` emits `QueryEvent`s, assert `NotchReducer` can render every new event path.

            Senior bar: a principal engineer would approve this diff without asking "did you actually run it?"
        """).strip()
        targets = f"`Sources/MnemoOrchestrator/{f}.swift`, related tests, `NotchReducer.swift` if events change"

    elif agent.id == "E":
        s = FRONTEND_SURFACES[(n - 1) % len(FRONTEND_SURFACES)]
        u = UX_DIMENSIONS[(n - 1) % len(UX_DIMENSIONS)]
        title = f"{s}: excel at {u}"
        objective = textwrap.dedent(f"""
            As a **staff UI engineer**, make `{s}` **best-in-class** for **{u}** (seed `{seed}`).

            Deliverables:
            - Real SwiftUI/AppKit/Metal change (no comment-only audits). Liquid Glass must use real APIs.
            - XCTest or snapshot-equivalent logic test proving the UX invariant (not `XCTAssertTrue(true)`).
            - Honor Reduce Motion + Increase Contrast + VoiceOver (`Narrator` where needed).
            - If touching reasoning UI: `ReasoningTraceView` must feel Apple-grade — calm, legible, collapsible.
            - Capture headless evidence via `DebugHooks` or test hooks in evidence file.

            Senior bar: frame-by-frame this would pass `scripts/ui-torture.sh` scrutiny.
        """).strip()
        targets = f"`Sources/MnemoApp/` ({s}), `Tests/MnemoOrchestratorTests/NotchReducerTests.swift` or UI logic tests"

    elif agent.id == "F":
        p = PLATFORM_TOPICS[(n - 1) % len(PLATFORM_TOPICS)]
        title = f"Platform: {p}"
        objective = textwrap.dedent(f"""
            As a **staff platform engineer**, implement **{p}** end-to-end (seed `{seed}`).

            Deliverables:
            - Wire config → runtime → observable output (logs, mnemoctl, or CI artifact).
            - Fail-closed validation at startup for any new `mnemo.toml` keys.
            - Tests in `MnemoCoreTests` or `MnemoSupervisorTests` with negative cases.
            - No document content in info-level logs; prove with redaction test.
            - Extend `scripts/ci.sh` or `scripts/phase2-reject.sh` if this prompt adds a new gate.

            Senior bar: on-call could diagnose a production incident from your logs alone.
        """).strip()
        targets = "`MnemoCore/`, `MnemoSupervisor/`, `mnemo.toml`, `scripts/`"

    elif agent.id == "G":
        v = QUALITY_VECTORS[(n - 1) % len(QUALITY_VECTORS)]
        f = BACKEND_FILES[(n * 3) % len(BACKEND_FILES)]
        title = f"QA: {v} on {f}"
        objective = textwrap.dedent(f"""
            As a **staff QA/security engineer**, apply **{v}** against `{f}` (seed `{seed}`).

            Deliverables:
            - Write a failing test that reproduces a **real** defect or latent risk (not theoretical fluff).
            - Fix the defect in production code if in your audit scope; otherwise file a blocking evidence note.
            - Run `scripts/phase2-reject.sh` mentally: zero stub tests, zero batch-script patterns.
            - Add regression to `BugfixRegressionTests` or new `Phase2RegressionTests.swift`.
            - Scan for egress holes, force-unwraps on query path, silent `catch`.

            Senior bar: this test would have caught the 2026-07-09 audit bugs before ship.
        """).strip()
        targets = f"`{f}.swift` + exhaustive test coverage expansion"

    elif agent.id == "H":
        sc = INTEGRATION_SCENARIOS[(n - 1) % len(INTEGRATION_SCENARIOS)]
        title = f"E2E: {sc}"
        objective = textwrap.dedent(f"""
            As a **staff integration engineer**, prove **{sc}** works offline (seed `{seed}`).

            Deliverables:
            - Script or XCTest lifecycle test with **captured transcript** (prompt, sources, answer, egress count).
            - Use `Tests/Fixtures/corpus/` or extend fixtures; no network mocks that bypass egress guard.
            - Measure latency percentiles; compare to `mnemo.toml [sla]`; document honest pass/fail.
            - Isolate build dir (`MNEMO_BUILD_DIR`) for harness stability.
            - If failing: fix root cause in the appropriate module (coordinate via evidence notes only — no commits).

            Senior bar: this scenario appears in `beats-siri.mov` and cannot embarrass us.
        """).strip()
        targets = "`scripts/run-usecases.sh`, `mnemoctl`, `Tests/Fixtures/`, orchestrator lifecycle"

    else:  # I
        d = PRODUCT_DELIVERABLES[(n - 1) % len(PRODUCT_DELIVERABLES)]
        title = f"Product: {d}"
        objective = textwrap.dedent(f"""
            As a **staff product engineer / tech writer**, deliver **{d}** to production quality (seed `{seed}`).

            Deliverables:
            - User-visible or doc artifact that is **shippable**, not placeholder (no TBD sections).
            - Cross-link to code/tests that enforce the doc (AT-M* or BS-M* where applicable).
            - If `UI.md` slice: include springs, radii, orb shader params, fidelity checklist items.
            - If demo slice: storyboard frame list for `Tests/Fixtures/demos/beats-siri.mov`.
            - Intelligence tests green for any behavior you spec.

            Senior bar: Apple WWDC session could cite this doc without fact-check fixes.
        """).strip()
        targets = "`PLAN.md`, `UI.md`, `README.md`, `docs/`, intelligence test suite"

    return {
        "title": title,
        "objective": objective,
        "targets": targets,
        "phase_name": phase_name,
        "phase_desc": phase_desc,
        "priority": pri,
        "seed": seed,
    }


def render(agent: AgentDef, n: int, spec: dict) -> str:
    others = [a.id for a in AGENTS if a.id != agent.id]
    return f"""# [{agent.id}-{n:04d}] {spec['title']}

| Field | Value |
|-------|-------|
| **Queue** | {n} / 1000 |
| **Agent** | {agent.id} — {agent.name} |
| **Phase** | {spec['phase_name']} — {spec['phase_desc']} |
| **Priority** | {spec['priority']} |
| **Seed** | `{spec['seed']}` |
| **Parallel** | Safe vs agents {', '.join(others)} |

---

## Single purpose (senior bar)

{spec['objective']}

---

## Scope

**Own:** {agent.owns}

**Forbidden:** {agent.forbidden}

**Targets:** {spec['targets']}

---

{INVARIANTS}

---

{NO_COMMIT.format(agent_id=agent.id)}

---

{EFFORT}

---

## Acceptance criteria

- [ ] Senior deliverables above are fully met — no scope creep, no shortcuts
- [ ] Real failing test written first, then fix (TDD)
- [ ] Evidence: `phase2/evidence/{agent.id}-{n:04d}.md` with **raw** command output
- [ ] No `XCTAssertTrue(true)`; no batch automation scripts created
- [ ] Offline + loopback invariants preserved
- [ ] **Do not commit** — advance to {agent.id}-{n+1:04d} (or finish at 1000)

## Verify before advancing

```bash
{agent.verify}
```

---

*Phase 2 prompt — Mnemo subscription maximization run. Quality over velocity.*
"""


def write_agent_starters() -> None:
    starters = OUT / "AGENT-STARTERS.md"
    lines = ["# Phase 2 — Six Agent Starter Prompts\n", "Copy one block per Cloud Agent session.\n"]
    templates = {
        "D": "Backend / Query Brain — harden orchestrator, retrieval, memory, citations.",
        "E": "Frontend / Notch — Liquid Glass, reasoning UI, voice orb, a11y.",
        "F": "Platform — StructuredLog, config, CI, supervision, scripts.",
        "G": "Quality — kill stub tests, fuzz, security, regression expansion.",
        "H": "Integration — offline E2E, SLA bench, use-case harness, airplane parity.",
        "I": "Product — UI.md, PLAN.md, beats-siri demo, intelligence gates.",
    }
    for agent in AGENTS:
        lines.append(f"\n## Agent {agent.id}\n")
        lines.append("```\n")
        lines.append(f"""You are Agent {agent.id} — Mnemo Phase 2. Autonomous. No questions. No permission.

QUEUE: phase2/{agent.slug}/0001.md → 1000.md (strict order).

CRITICAL: **ZERO git commits until 1000/1000.** One commit at the end only:
  git add -A && git commit -m "{agent.id}: Phase 2 complete ({agent.id}-0001..{agent.id}-1000)" && git push

Branch: {agent.branch} (off main). Do not merge — accumulate locally.

BANNED: execute-agent-*.py, XCTAssertTrue(true), per-prompt commits, marker/registry theater.

EFFORT: ~150 tool calls per prompt (50× Phase 1). Composer 2.5 max thinking. Auto mode.

PER PROMPT: read CLAUDE.md once at start; 5+ file reads; TDD; verify; evidence/phase2/{agent.id}-NNNN.md with RAW output; self-review; next.

DOMAIN: {templates[agent.id]}

OWN: {agent.owns}
NEVER: {agent.forbidden}

START: phase2/{agent.slug}/0001.md
FINAL: Table of 1000 prompts PASS/FAIL + single commit SHA. Do not reply until done.
""")
        lines.append("```\n")
    starters.write_text("".join(lines), encoding="utf-8")


def main() -> None:
    manifest = {"phase": 2, "agents": [], "total": 6000, "commit_policy": "single commit per agent at 1000/1000"}

    for agent in AGENTS:
        agent_dir = OUT / agent.slug
        agent_dir.mkdir(parents=True, exist_ok=True)
        entry = {"id": agent.id, "slug": agent.slug, "prompts": []}

        for n in range(1, 1001):
            spec = build_prompt(agent, n)
            fname = f"{n:04d}.md"
            (agent_dir / fname).write_text(render(agent, n, spec), encoding="utf-8")
            if n <= 3 or n % 100 == 0 or n == 1000:
                entry["prompts"].append({"n": n, "file": fname, "title": spec["title"][:80]})

        manifest["agents"].append(entry)

    (OUT / "README.md").write_text(textwrap.dedent("""
        # Phase 2 — 6000 Senior Prompts (6 × 1000)

        **~50× Phase 1 depth.** One git commit per agent at prompt **1000/1000** only.

        | Agent | Directory | Focus |
        |-------|-----------|-------|
        | D | `agent-d-backend/` | Query brain, retrieval, memory |
        | E | `agent-e-frontend/` | Notch UI, glass, reasoning, orb |
        | F | `agent-f-platform/` | Logs, config, CI, supervision |
        | G | `agent-g-quality/` | QA, security, regression, anti-stub |
        | H | `agent-h-integration/` | Offline E2E, SLA, harness |
        | I | `agent-i-product/` | UI.md, PLAN.md, beats-Siri |

        ## Rules
        1. Chronological `0001.md` → `1000.md` per agent
        2. **No commits until 1000** — one atomic commit per agent at the end
        3. Evidence per prompt: `phase2/evidence/{AGENT}-{NNNN}.md`
        4. Ban stub tests and batch queue scripts

        ## Start
        See `AGENT-STARTERS.md` for six copy-paste Cloud Agent prompts.

        ## Regenerate
        ```bash
        python3 scripts/generate-phase2-prompts.py
        ```
    """).strip() + "\n", encoding="utf-8")

    write_agent_starters()
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    # Reject script for Agent G
    reject = ROOT / "scripts" / "phase2-reject.sh"
    reject.write_text("""#!/usr/bin/env bash
# Phase 2 quality gate — fails on stub tests or batch automation patterns.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== phase2-reject ==="
if rg 'XCTAssertTrue\\(true' Tests/ 2>/dev/null; then
  echo "REJECT: stub tests (XCTAssertTrue(true))"
  exit 1
fi
if rg -l 'execute-agent-|process-agent-a' scripts/ 2>/dev/null; then
  echo "REJECT: batch queue automation scripts"
  exit 1
fi
echo "PASS: phase2-reject"
""", encoding="utf-8")
    reject.chmod(0o755)

    total = sum(1 for _ in OUT.rglob("*.md") if "agent-" in str(_))
    print(f"Generated {total} prompt files under {OUT}")


if __name__ == "__main__":
    main()
