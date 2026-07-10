# PLAN.md — Mnemo Execution Spec

> Reconstructed from `docs/superpowers/plans/` and codebase. See [CLAUDE.md](CLAUDE.md) for invariants.  
> **Agent I deliverable:** every `AT-M*` and `BS-M*` below maps to a test or script — complete, no placeholders.

## Milestones (M0–M12)

| Milestone | Focus | Acceptance tests | Beats-Siri gate |
|-----------|-------|------------------|-----------------|
| M0 | Bootstrap, config gate, process supervision | AT-M0.* | BS-M0 |
| M1 | Thin slice: ask → cited answer | AT-M1.* | BS-M1 |
| M2 | Ingestion & item state | AT-M2.* | BS-M2 |
| M3 | Retrieval surfaces | AT-M3.* | BS-M3 |
| M4 | Query lifecycle & routing | AT-M4.* | BS-M4 |
| M5 | Grounding & citation verification | AT-M5.* | BS-M5 |
| M6 | Memory dynamics | AT-M6.* | BS-M6 |
| M7 | Sync-engine correctness | AT-M7.* | BS-M7 |
| M8 | Consolidation ("dreaming") | AT-M8.* | BS-M8 |
| M9 | Personalization & inspector | AT-M9.* | BS-M9 |
| M10 | Offline & privacy enforcement | AT-M10.* | BS-M10 |
| M11 | Concurrency & scheduling | AT-M11.* | BS-M11 |
| M12 | Notch UI + voice orb | AT-M12.* | BS-M12 |

---

## M0 — Bootstrap & process supervision

**Goal:** SwiftPM package, `mnemo.toml` validation, loopback-only binding, supervised start order (ollama → engine → smfs).

### AT-M0 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M0.1 | `swift build && swift test` passes network-off | CI / `SmokeTests` |
| AT-M0.2 | `engine.base_url`, `model.runtime_base_url`, `smfs.backing_store` loopback-only | `InvariantTests` |
| AT-M0.3 | `smfs.backing_store == engine.base_url` | `InvariantTests.testBackingStoreMismatchRejected` |
| AT-M0.4 | Non-loopback hosts rejected at startup | `InvariantTests.testNonLoopbackEngineRejected` |
| AT-M0.5 | TOML parser reads all `mnemo.toml` sections | `TOMLTests` |
| AT-M0.6 | Start order: ollama → engine → smfs | `ProcessSupervisorTests` |
| AT-M0.7 | Health probes return structured status | `HealthProbeTests` |
| AT-M0.8 | Ollama warmup before accepting queries | `OllamaWarmupTests` |
| AT-M0.9 | `lsof` audit: only `127.0.0.1` LISTEN on 6767/11434 | `LoopbackAuditTests`, `scripts/smoke.sh` |
| AT-M0.10 | Exit code 3 on invariant violation | `InvariantTests.testExitCodeContract` |

### BS-M0

Stack starts with network off; config gate refuses cloud URLs; health probes green on loopback only.

---

## M1 — Thin vertical slice (ask → cited answer)

**Goal:** Drop file → ask question → streamed cited answer below notch.

### AT-M1 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M1.1 | Answer contains grounded fact from corpus | `QueryServiceTests`, `scripts/m1-acceptance.md` |
| AT-M1.2 | Source card click reveals file in Finder | `QueryServiceTests.testSourceCardsCarryAbsoluteMountPaths` |
| AT-M1.3 | Out-of-corpus question → explicit lack, no invention | `QueryServiceTests`, `m1-acceptance.md` |
| AT-M1.4 | `[sources]` before first `[answer]` token | `QueryLifecycleTests` ("AT-M4.6" event order) |
| AT-M1.5 | Generation uses only provided context | `PromptTests` |
| AT-M1.6 | Engine client decodes search JSON at loopback | `EngineClientTests` |

### BS-M1

Offline cited answer with zero egress. Proof: `docs/product/bs-m1-offline-proof.md`, `scripts/m1-acceptance.md`.

---

## M2 — Ingestion & item state

**Goal:** Files ingested; item states tracked; indexing terminal when not ready.

### AT-M2 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M2.1 | ItemState maps engine status → ready/processing/failed | `SmarterThanSiriTests` B68 |
| AT-M2.2 | Ingest gate waits until searchable | `IngestGateTests`, B69 |
| AT-M2.3 | Indexing path → `.indexing` terminal, not empty refusal | `IngestIndexTests` |
| AT-M2.4 | Content hash stable across reads | `ContentHashTests`, B71 |
| AT-M2.5 | Extraction failures surface retry policy | `HelpfulnessTests` ExtractionFailureReportTests |

### BS-M2

Drop PDF → indexing message → ready → answer cites extracted text.

---

## M3 — Retrieval surfaces

**Goal:** Hybrid search, keyword backstop, agentic grep, hop planning.

### AT-M3 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M3.1 | Search modes: memories, hybrid | `EngineClientTests` |
| AT-M3.2 | Coverage escalation broadens weak queries | `CoverageTests`, `SmarterThanSiriTests` A049 |
| AT-M3.3 | Keyword backstop rescues zero-hit queries | `KeywordBackstopTests`, B63 |
| AT-M3.4 | Multi-hop follows thread across docs | `AgenticGrepTests` |
| AT-M3.5 | Personal ranker boosts frequent sources | `ProfileTests` |

### BS-M3

Cross-document evidence from ≥3 sources in timeline fixture.

---

## M4 — Query lifecycle & routing

**Goal:** Route → assemble → generate → verify → stream.

### AT-M4 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M4.1 | Heuristic router ≥90% on fixture set | `RouterTests` |
| AT-M4.2 | LLM escalation on ambiguity | `RouterTests`, B55 |
| AT-M4.3 | Intent shapes context assembly | `ContextAssemblerTests`, B65 |
| AT-M4.4 | Query decomposer for compound questions | `QueryLifecycleTests` |
| AT-M4.5 | Answer cache invalidates on corpus version change | `HelpfulnessTests` AnswerCacheTests |
| AT-M4.6 | Event order: routed → sources → tokens → done | `QueryLifecycleTests` |
| AT-M4.7 | Reasoning steps emitted for multihop | `SmarterThanSiriTests` B56 |

### BS-M4

Route intent visible; sources sub-second; full lifecycle under 30s on recommended tier.

---

## M5 — Grounding & citation verification

**Goal:** Post-generation sentence verification; unsupported flagged.

### AT-M5 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M5.1 | Citation verifier marks supported sentences | `CitationVerifierTests` |
| AT-M5.2 | Unsupported sentences → `.unsupportedAnswer` or orange flag | `CitationVerifierTests`, A136 |
| AT-M5.3 | Char-span resolution to source offsets | `CharSpanTests`, `SpanResolverTests` |
| AT-M5.4 | Span preview extracts containing sentence | `ExpressivenessTests` SpanPreviewTests |
| AT-M5.5 | Provenance maps `[n]` markers to cards | `SmarterThanSiriTests` ProvenanceTests |
| AT-M5.6 | Adaptive effort retries on low support | `CitationVerifierTests` lifecycle |

### BS-M5

Every claim in BS-M12 demo answer verified; zero unsupported sentences pass silently.

---

## M6 — Memory dynamics

**Goal:** Versioning, contradiction, TTL, forget.

### AT-M6 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M6.1 | Lexical contradiction supersedes old fact | `MemoryDynamicsTests`, `SmarterThanSiriTests` B73 |
| AT-M6.2 | Forgotten facts excluded from answers | `SmarterThanSiriTests` A223, `ExpressivenessTests` A225 |
| AT-M6.3 | TTL-expired memories inactive | A223, A225 ttl tests |
| AT-M6.4 | Memory fact filter drops `isForgotten` | B72 |
| AT-M6.5 | Conflict detector finds location conflicts | B73, `ConflictDetector` |

### BS-M6

Inspector delete → re-ask → fact absent (BS-M12 step ④⑤).

---

## M7 — Sync-engine correctness

**Goal:** SMFS mount sync; self-heal orphans.

### AT-M7 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M7.1 | Sync engine polls and applies deltas | `SyncEngineTests` |
| AT-M7.2 | Self-heal removes orphaned memory refs | `SmarterThanSiriTests` B70 |
| AT-M7.3 | Suppression survives re-ingest | `InspectorTests` SuppressionInIngestTests |
| AT-M7.4 | Content hash detects file changes | `ContentHashTests` |

### BS-M7

Edit file on disk → re-index → updated answer on re-ask.

---

## M8 — Consolidation ("dreaming")

**Goal:** Background synthesis; no duplicate memories.

### AT-M8 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M8.1 | Dreaming-safe synthesis rejects duplicates | A252, A254, A280 regression tests |
| AT-M8.2 | Cold archive identifies stale memories | `ExpressivenessTests` ConsolidationAuditTests |
| AT-M8.3 | LLM synthesizer produces grounded summary | B75 |
| AT-M8.4 | Entity extractor safe for dreaming | A252 |

### BS-M8

Recurring facts consolidate; novel synthesis cites constituents.

---

## M9 — Personalization & inspector

**Goal:** Profile static/dynamic chips; delete/correct write-back.

### AT-M9 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M9.1 | Inspector snapshot splits static/dynamic | `InspectorTests` |
| AT-M9.2 | Delete forgets + suppresses re-ingest | `InspectorTests.testDeleteForgetsAndSuppresses` |
| AT-M9.3 | Correct supersedes via M6 | `InspectorTests.testCorrectSupersedes` |
| AT-M9.4 | Suppression ledger normalizes fuzzy keys | `SuppressionLedgerTests` |
| AT-M9.5 | No info-level logging of memory text | `InspectorLoggingAuditTests` |
| AT-M9.6 | Preferences surface strength-ranked facts | `SmarterThanSiriTests` PreferencesTests |

### BS-M9

Inspector shows fact → delete → re-ask forgets. Spec: `docs/product/inspector-ux-spec.md`.

---

## M10 — Offline & privacy enforcement

**Goal:** Measured zero egress; loopback guard blocks outbound.

### AT-M10 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M10.1 | `EgressGuard.isLoopbackHost` classifies correctly | `EgressGuardTests` |
| AT-M10.2 | Non-loopback attempts counted per query window | `EgressGuardTests` |
| AT-M10.3 | `LoopbackGuardURLProtocol` blocks + counts | `LoopbackGuardURLProtocolTests` |
| AT-M10.4 | Airplane parity: same answers online vs offline | `scripts/airplane-parity.sh` |
| AT-M10.5 | Privacy indicator: clean vs egressDetected | `ProductDocTests`, `docs/product/privacy-indicator.md` |
| AT-M10.6 | No telemetry config keys enabled | `mnemo.toml` `[privacy] telemetry = "off"` |

### BS-M10

`scripts/airplane-parity.sh` → `EGRESS_NONLOOPBACK: 0` for all fixture queries.

---

## M11 — Concurrency & scheduling

**Goal:** Interactive preempts background; no query stall during ingest/dream.

### AT-M11 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M11.1 | `WorkPriority.background < .interactive` | B79 |
| AT-M11.2 | Scheduler yields at chunk boundaries | `SchedulerTests` |
| AT-M11.3 | Ingest runs at utility priority | `IngestGateTests` |
| AT-M11.4 | P95 first_token_ms ≤ 1500 under background load | `mnemo.toml` `[sla]`, fixture report |
| AT-M11.5 | Sources render_ms ≤ 1000 | `mnemo.toml` `[sla]` |

### BS-M11

Live query during folder ingest → answer not blocked. Report: `Tests/Fixtures/m11-slo-report.txt`.

---

## M12 — Notch UI + voice orb

**Goal:** Liquid Glass surface, state machine, voice dictation, terminal polish.

### AT-M12 acceptance tests

| ID | Criterion | Enforcement |
|----|-----------|-------------|
| AT-M12.1 | Hover summon < 200ms; non-activating | `scripts/m12-acceptance.md` manual |
| AT-M12.1b | NotchShape bottom radius grows with body | `NotchShapeGeometryTests` |
| AT-M12.2 | Immediate typing on expand | manual |
| AT-M12.3 | Virtual notch on `safeAreaInsets.top == 0` | `NotchGeometryTests` |
| AT-M12.4 | Single GlassEffectContainer + glassEffectID | manual |
| AT-M12.5 | Markdown answer; unsupported orange | manual |
| AT-M12.6 | Source card → Finder | manual + AT-M1.2 |
| AT-M12.7 | All terminal states render non-empty | `TerminalStateRenderTests`, `StateDriverTests` |
| AT-M12.8 | Settings: ingest path, pause, scope | manual |
| AT-M12.9 | Empty path emits nearest matches | `StateMachineTests` |
| AT-M12.10 | Orb uniforms: amplitude → wave/brightness/saturation | `MicEnvelopeTests` |
| AT-M12.11 | Motion tokens match UI.md §7 | `ProductDocTests` |
| AT-M12.12 | Reduce Motion → opacity cross-fade | `UI.md` §6, manual |

### BS-M12

Full continuous offline demo. Script: `docs/product/bs-m12-demo-script.md`. Storyboard: `Tests/Fixtures/demos/beats-siri-storyboard.md`. Recording target: `Tests/Fixtures/demos/beats-siri.mov`.

---

## Appendix A — Configuration (`mnemo.toml`)

All hosts must be loopback. `smfs.backing_store` must equal `engine.base_url`. Validated at startup by `MnemoConfig.validateInvariant()`. See [mnemo.toml](mnemo.toml).

| Section | Key fields | Invariant |
|---------|------------|-----------|
| `[engine]` | `base_url`, `byom`, `embeddings` | loopback; local embeddings |
| `[model]` | `runtime_base_url`, `synthesis`, `fallback` | loopback; no hosted inference |
| `[smfs]` | `mount_point`, `backing_store` | backing_store == engine.base_url |
| `[privacy]` | `egress_guard`, `telemetry`, `show_egress_indicator` | enforce + off + visible |
| `[sla]` | `first_token_ms`, `sources_render_ms` | honest hardware-tier SLA |
| `[ui]` | `deployment_target`, `summon`, `hotkey` | macOS 26.0 minimum |

---

## Appendix B — Observability & metrics

Structured logs at `~/Library/Logs/Mnemo/app.jsonl`. Field mapping: `docs/product/appendix-b-metrics.md`.

| Metric | Type | Test mapping |
|--------|------|--------------|
| `query_id` | UUID string | `StructuredLogTests` |
| `route_intent` | lookup/profile/synthesis/multihop | `RouterTests` |
| `effort_tier` | low/medium/high | `AdaptiveEffort` tests |
| `retrieval_hop_count` | int | `AgenticGrepTests` |
| `first_token_ms` | int | M11 SLO |
| `total_ms` | int | M11 SLO |
| `egress_blocked_count` | int | `EgressGuardTests` |
| `verification_pass_rate` | 0…1 | `CitationVerifierTests` |
| `context_token_count` | int | `ContextAssemblerTests` |
| `model_id` | string | config-driven |
| `terminal_state` | enum string | `TerminalStateRenderTests` |

**Privacy:** no document body at info level. Enforced: `PromptLoggingAuditTests`, `InspectorLoggingAuditTests`.

---

## Appendix C — Testing strategy

| Layer | Command | When |
|-------|---------|------|
| Unit | `swift test` | Every milestone; network-off |
| Intelligence | `swift test --filter 'SmarterThanSiri\|Expressiveness\|Helpfulness'` | Product gates |
| Product docs | `swift test --filter ProductDocTests` | Agent I deliverables |
| Live stack | `mnemoctl` + `scripts/run-usecases.sh` | Integration |
| Airplane | `scripts/airplane-parity.sh` | M10 / BS-M10 |
| UI manual | `scripts/m12-acceptance.md` | M12 display required |

Threshold tests use fixture distributions, not single-sample LLM equality ([Appendix C policy](PLAN.md#appendix-c--testing-strategy)).

---

## Appendix D — Milestone dependency graph

```
M0 → M1 → M2 → M3 → M4 → (M5, M6) → M7 → M8 → M9
M4 + M5 → M10
M4 + M8 → M11
M4 + M5 + M9 → M12
```

---

## Global data model

Codable structs in `Sources/MnemoOrchestrator/` mirror engine JSON at client boundary only. Alignment spec: `docs/product/shared-codable-alignment.md`.

| Swift type | Role |
|------------|------|
| `SourceLocator` / `Retrieved` | Search results |
| `SourceCard` | UI citation cards |
| `MemoryEntry` | Profile / inspector |
| `QueryEvent` | Streamed lifecycle events |
| `TerminalState` | Non-answer outcomes |
| `NotchState` | View-model state |

---

## BS-M* beats-Siri criteria (summary)

| Gate | Criterion |
|------|-----------|
| BS-M0 | Stack loopback-only; config refuses cloud |
| BS-M1 | Offline cited answer; zero egress |
| BS-M2 | Ingest → index → cite |
| BS-M3 | Cross-doc retrieval ≥3 sources |
| BS-M4 | Full lifecycle streamed |
| BS-M5 | Verified citations only |
| BS-M6 | Forget retracts knowledge |
| BS-M7 | Sync self-heals |
| BS-M8 | Dreaming doesn't duplicate |
| BS-M9 | Inspector edit affects answers |
| BS-M10 | Airplane parity + egress 0 |
| BS-M11 | Interactive never blocked |
| **BS-M12** | **Continuous offline demo beats Siri** — summon → grounded answer → Finder → inspector delete → re-ask forgets → egress 0. Recording: `beats-siri.mov`. |

Comparison table: `docs/product/comparison-table.md`.

---

*Agent I Phase 2 complete spec. Cross-links: [UI.md](UI.md), [README.md](README.md), [CLAUDE.md](CLAUDE.md).*
