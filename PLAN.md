# PLAN.md — Mnemo Execution Spec (Agent C documentation recovery)

> Reconstructed from `docs/superpowers/plans/` and codebase. See [CLAUDE.md](CLAUDE.md) for invariants.

## Milestones (M0–M12)

| Milestone | Focus | Acceptance tests |
|-----------|-------|------------------|
| M0 | Bootstrap, config gate, process supervision | AT-M0.* |
| M1 | Thin slice: ask → cited answer | AT-M1.* |
| M2 | Ingestion & item state | AT-M2.* |
| M3 | Retrieval surfaces | AT-M3.* |
| M4 | Query lifecycle & routing | AT-M4.* |
| M5 | Grounding & citation verification | AT-M5.* |
| M6 | Memory dynamics | AT-M6.* |
| M7 | Sync-engine correctness | AT-M7.* |
| M8 | Consolidation ("dreaming") | AT-M8.* |
| M9 | Personalization & inspector | AT-M9.* |
| M10 | Offline & privacy enforcement | AT-M10.* |
| M11 | Concurrency & scheduling | AT-M11.* |
| M12 | Notch UI + voice orb | AT-M12.* |

## Appendix A — Configuration (`mnemo.toml`)

All hosts must be loopback. `smfs.backing_store` must equal `engine.base_url`. See [mnemo.toml](mnemo.toml).

## Appendix B — Observability metrics

Structured logs at `~/Library/Logs/Mnemo/app.jsonl`: `query_id`, `route_intent`, `effort_tier`, `retrieval_hop_count`, `first_token_ms`, `total_ms`, `egress_blocked_count`, `verification_pass_rate`, `context_token_count`, `model_id`, `terminal_state`. No document body at info level.

## Appendix C — Testing strategy

Unit tests via `swift test`. Live stack via `mnemoctl`. Harness: `scripts/run-usecases.sh` (isolated build dir). Airplane parity: `scripts/airplane-parity.sh`.

## Appendix D — Milestone dependency graph

M0 → M1 → M2 → M3 → M4 → (M5, M6) → M7 → M8 → M9; M4+M5 → M10; M4+M8 → M11; M4+M5+M9 → M12.

## Global data model

Codable structs in `Shared/` mirror engine JSON at client boundary only.

## BS-M12 beats-Siri criteria

Offline cross-document synthesis with verified citations and zero egress. Demo at `Tests/Fixtures/demos/beats-siri.mov`.
