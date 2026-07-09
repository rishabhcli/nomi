# Mnemo — Backend Test Report (2026-07-09)

Scope: MnemoCore, MnemoSupervisor, MnemoOrchestrator (+ mnemoctl). MnemoApp reviewed only for the hover/summon bug reported live. Every claim below is backed by captured command output.

Toolchain note: the project builds with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` (needs XCTest + the metal compiler; Command-Line-Tools alone can't build it). The live stack (engine :6767, ollama gpt-oss:20b warm, smfs NFS mount) was up throughout.

---

## Baseline — PASS
- Clean build with the correct toolchain: 0 errors, 1 benign SwiftPM warning; whole package incl. MnemoApp compiles.
- `swift test`: **335 → 341 tests, 0 failures** after the fixes below.

## P0 invariants — VERIFIED (unit + live; re-verified after fixes)
- Config gate: cloud `base_url`→exit 3, backing-store mismatch→exit 3, LAN `runtime_base_url`→exit 3, good→exit 0.
- Loopback audit: 4 listeners all `127.0.0.1` (engine 6767, Rivet 6420, ollama 11434, smfs 11111).
- Egress guard: deliberate `api.supermemory.ai` call BLOCKED (blockedCount=1); loopback passes through the same session.
- Socket sweep during a live query: **654 established-connection observations, every foreign peer `127.0.0.1`, zero non-loopback**.
- Telemetry off (engine env + config).

## Live functional — VERIFIED (all offline)
Lookup ("Bazel" cited), cross-doc numeric synthesis ("four weeks" across 3 timeline docs — the scenario Siri offloads to the cloud), refusal (no fabrication), greeting short-circuit, nonsense refusal, semantic-vs-literal grep, memory supersede-in-place + history + delete, `--verify` (zero false-positive flags).

---

## FIXES APPLIED THIS SESSION (regression tests added; 341 green; live re-verified)

Backend (MnemoOrchestrator):
1. **EgressGuard.isLoopbackHost** (EgressGuard.swift:16) — was `hasPrefix("127.")`, so `127.0.0.1.evil.com` / `127.attacker.net` counted as loopback → the in-process guard would NOT block egress to them. Now validates a real 127/8 dotted-quad. Tests: `EgressHostAndCitationTests`.
2. **CitationVerifier.stripCitations** (CitationVerifier.swift:41) — was also stripping `( … )`, so parenthetical claims went unverified and an unmatched "(" nuked the sentence tail (false UNSUPPORTED). Now strips only `[ ]` / `【 】`.
3. **NumericReasoner.durationNote** (NumericReasoner.swift) — computed the global earliest→latest span across ALL evidence dates and told the model "use this — do not re-derive it" (8× wrong once a distractor date is present). Now lists dated facts chronologically; span is advisory, model picks the endpoints. Aurora "four weeks" preserved (live). Test: `testNumericNoteIsAdvisoryWithDistractorDate`.
4. **TimeWindow.parse** (TimeWindow.swift:31) — matched the word "may" (and "maybe"/"marching") as months. Now whole-word match; "may" needs a temporal cue. Test: `HelpfulnessTests.TimeWindowTests`.
5. **Subprocess.capture** (AgenticGrep.swift:179) — piped stderr but never drained it → a child writing >~64KB to stderr (`grep -rFn` permission-denied spam) would deadlock the agentic query. Now discards stderr.
6. **Consolidator.dream** (Consolidation.swift:112) — re-synthesized cluster memories every pass → graph bloat. Now skips a synthesis whose text already exists. Test: `testDreamDoesNotDuplicateExistingSynthesis`.

App (MnemoApp) — the reported hover/duplicate-window bug:
7. **Single-instance enforcement** (main.swift) — the app had none, so every launch left another resident notch panel (each with its own global hover monitor → stacked "Ask Mnemo" surfaces). New launch now terminates older `ai.mnemo.app` instances.
8. **In-flight query lock** (NotchViewModel `isQuerying` + NotchController `summon`/`mouseOutHotRect`) — a hover-out/in during a streaming answer dismissed then re-summoned, spawning a duplicate session the old task clobbered. Now, while a query streams, mouse-out won't dismiss and summon is a no-op.

## FINDINGS NOT CHANGED (flagged for your call)
- **[P1 data-loss] `SelfHeal.orphanedMemoryIds` (SyncEngine.swift:20)** deletes any memory with no `documentIds`. **Intentional and test-backed** (`SyncEngineTests.swift:16` asserts `docIds:[]`→orphan), but it means `sync self-heal` GCs consolidation syntheses, promoted static facts, and `memory add` facts (all source-less). Recommend exempting source-less memories. NOT changed — deliberate data-deletion decision.
- **[limitation] `LexicalContradiction` (MemoryDynamics.swift:129)** only recognizes location/employment predicates → supersession + conflict detection fire only for those; other contradictions duplicate.
- **[P2] SuppressionLedger (Inspector.swift:19)** keys retractions by exact normalized text → a re-extracted fact with different wording resurrects.
- **[P2, background] ColdArchive (Consolidation.swift:57)** never archives never-retrieved memories. Left as-is (changing it risks over-archiving fresh memories).
- **[latency] First-token ~8.5s steady / 16s cold (mnemoctl bench)** — 6–11× over the 1500ms SLA. M11 no-degradation-under-load holds.
- **[product] 27 / 71 documents (38%) in engine-side `error` state** — extraction failures; graceful chunk-level degradation.
- **[trivial] QueryService.swift:371 `abs(q0.hashValue)`** traps if hash==Int.min (~1/2^64). **[minor]** smfs semantic grep returns `(unknown)` filepaths.

## Files independently reviewed and judged correct
TOML/MnemoConfig (fail-closed, no egress hole), CharSpan/SpanResolver, LocalVerificationBackend.parseVerdict (prior bug genuinely fixed), KeywordBackstop, EvidenceGathering, EngineClient wire-mapping, ContextAssembler, WorkScheduler, Profile/ProfileDedupe, ContentHash, AnswerCache, CommandParser, PersonalRanker, Coverage, ConflictDetector, Ingestion state mapping.

## Harness note
`run-usecases.sh` (105 cases) was run twice; **both were clobbered** — the shared `.build/debug/mnemoctl` binary is rebuilt whenever anyone builds the app in the same working copy, so ~75 later cases fail instantly (0.0s) once the binary vanishes mid-run. Valid pre-clobber signal: fixture-lookup 10/10, timeline-numeric 7/8, job-finder 11/12, invariants 5/5 — 2 genuine failures (b08 synthesis miss; c04 engine model error). A clean run needs an isolated build dir. Egress sampler: **0 non-loopback** across both.

## Honest limitations
- Did not physically pull the network — offline behavior proven by measurement (config gate + guard + socket sweep), as PROGRESS.md did.
- No clean end-to-end 105-case harness run (shared-`.build` clobbering); targeted queries covered every major path.
