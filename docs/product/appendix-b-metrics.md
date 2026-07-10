# Appendix B — metric mapping

Maps each structured-log field in `~/Library/Logs/Mnemo/app.jsonl` to its producer, test, and UI surfacing. Enforced by `ProductDocTests.testAppendixBMetricsComplete`.

| Field | Producer | When emitted | Test | UI surfacing |
|-------|----------|--------------|------|--------------|
| `query_id` | `QueryService` | Query start | `StructuredLogTests` | Debug only |
| `route_intent` | `HeuristicRouter` / `LLMRouterEscalator` | After `.routed` event | `RouterTests` (AT-M4.1) | Not shown (reasoning optional) |
| `effort_tier` | `AdaptiveEffort` | Route resolution | `AdaptiveEffort` tests | Not shown |
| `retrieval_hop_count` | `AgenticGrep` | Multihop complete | `AgenticGrepTests` (AT-M3.4) | Reasoning steps (mnemoctl) |
| `first_token_ms` | `QueryService` | First `.token` | M11 SLO (`sla.first_token_ms`) | — |
| `total_ms` | `QueryService` | `.done` | M11 SLO | — |
| `egress_blocked_count` | `EgressGuard` / `LoopbackGuardURLProtocol` | Query window end | `EgressGuardTests` (AT-M10.2) | Privacy indicator |
| `verification_pass_rate` | `CitationVerifier` | Post-generation | `CitationVerifierTests` (AT-M5.1) | Unsupported sentence styling |
| `context_token_count` | `ContextAssembler` | Pre-generation | `ContextAssemblerTests` | — |
| `model_id` | `OllamaClient` | Generation start | Config-driven | Settings |
| `terminal_state` | `QueryService` | `.state(...)` emitted | `TerminalStateRenderTests` (AT-M12.7) | Terminal message |

## Privacy rules

- **Never** log document body, memory text, or query content at `info` level.
- Enforced: `PromptLoggingAuditTests`, `InspectorLoggingAuditTests`, `HelpfulnessTests.testContentHashDoesNotLogDocumentBytes`.

## BS-M12 demo

During the continuous demo, `egress_blocked_count` must remain **0** and `verification_pass_rate` must be **1.0** for the synthesis answer.
