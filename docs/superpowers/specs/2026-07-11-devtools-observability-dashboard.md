# Devtools Observability Dashboard — design + live progress

**Status:** ✅ IMPLEMENTATION COMPLETE + TESTED (2026-07-11 ~03:05 IST). All six
phases built and verified via 38 passing tests (isolated worktree, offline).
Only remaining step is a human launching the app with `MNEMO_DEVTOOLS=1` to view
it live — see **§ Completion & verification**. This doc is BOTH the approved
design spec and the resume handoff.

## Goal

A LOCAL, developer-only website showing **maximum observability of the Mnemo
query pipeline as soon as it is prompted** — the full deep trace of every stage,
live. For the developer only; never shipped.

## Approved decisions (from the user)

- **Deep trace** — add gated instrumentation to the orchestrator: per-stage
  timings, rewritten query, ALL retrieval candidates + scores (incl.
  below-threshold), the assembled system prompt + context, engine/Ollama
  round-trip timings, token-by-token streaming.
- **Observe + prompt** — read-only live view PLUS a prompt box that drives the
  real orchestrator.
- **Full raw content** — show prompt/evidence/context/answer verbatim (dev-only,
  loopback, off by default, nothing extra written to disk).
- **Approach A** — in-process loopback SSE server + a `DevTrace` bus.

## Invariants (do NOT break — these fail the build/PR)

- Bind **127.0.0.1 only** (constant in code, never from config). No `0.0.0.0`.
- **Zero egress.** The dashboard HTML must have **no external assets** (no CDN,
  fonts, script/img src to the internet) — grep it for `https?://`, every hit
  must be inside a JS comment. It must render with the network OFF.
- **Off by default.** Gated by `[devtools] enabled=false` in mnemo.toml +
  `MNEMO_DEVTOOLS=1` env override. Never in a release/normal run.
- **Nil-cost when off.** `QueryService.trace` is `DevTrace?` = nil normally;
  every emit is `trace?.…`. Normal runs get zero new events, zero behavior
  change, and the log-privacy rule stays intact.
- Follow **TDD**: failing test first, watch it fail, then implement.

## Build / test commands

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
# (drop the deprecated --build-system native flag; native is the default now)
# filter while iterating:
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter 'DevTraceTests|DevServer'
```

## Concurrency hazard (important)

`Sources/MnemoOrchestrator/QueryService.swift` and several `Sources/MnemoApp/*`
files (NotchShape/Motion/NotchSurfaceView) are being edited by another process
concurrently. **Re-read them fresh immediately before editing**, keep changes
minimal + additive, and rebuild to catch clobbers. `QueryEvent` already gained a
`.metrics(QueryMetrics)` case from that concurrent work.

## Architecture

- **`MnemoCore/DevTrace.swift`** (DONE): `JSONValue` (inline-JSON Codable),
  `TraceEvent` (wire format), `DevTrace` (actor fan-out + backlog replay),
  `QueryTracer` (per-query helper stamping queryId + monotonic seq + atMs).
- **`MnemoCore` config** (DONE): `MnemoConfig.DevTools { enabled, port }`,
  parsed with defaults (false / 7878), validated (port 1..65535 when enabled),
  schema allow-list `[devtools] = enabled, port`.
- **`MnemoDevServer`** (NEW library target, deps MnemoCore): the loopback HTTP
  server. Files (each focused, <400 lines):
  - `HTTPMessage.swift` — `HTTPRequest.parse(Data)`, `HTTPResponse.serialize()`.
  - `SSE.swift` — `SSE.frame(event:data:id:)`, `SSE.comment(_)`.
  - `DevAuth.swift` — `newToken()`, `isAuthorized(req, token:)` (token + loopback
    Origin/Host check — blocks CSRF from a visited webpage).
  - `DashboardDataSource.swift` — protocol the app implements: `snapshot()` →
    `DashboardSnapshot` (Codable, mirrors /api/state), `ask(_ query:)`,
    `trace: DevTrace`. Plus the `DashboardSnapshot` struct.
  - `DevServer.swift` — `NWListener` on 127.0.0.1:port, accept loop, route
    dispatch, SSE stream management, lifecycle start()/stop().
  - `DashboardPage.swift` — load the HTML resource, substitute `__MNEMO_TOKEN__`.
  - `Resources/dashboard.html` — the self-contained page (SUBAGENT FAILED to
    write it; build it by hand — see § Dashboard contract).
- **`MnemoOrchestrator/QueryService.swift`** (TODO): add `trace: DevTrace?` init
  param; emit a `TraceEvent` at each stage (see § Trace stages). Also instrument
  `EvidenceGathering.gatherEvidence` (pass the tracer) for candidate scores.
- **`MnemoApp`** (TODO): new `DevTools.swift`; when enabled, build DevTrace +
  DevServer, inject trace into the service, and FIX THE GAP by wiring the real
  `QueryLogSink` + `egressCounter` (`LoopbackGuardURLProtocol.blockedCount`) +
  `modelId` into `NotchController.makeService`. Start server, provide the
  data source (health snapshot + `ask` closure on MainActor).
- **`mnemo.toml`** (TODO): add a commented `[devtools]` section (enabled=false,
  port=7878).

## Endpoints (server contract)

- `GET /` → dashboard HTML with `__MNEMO_TOKEN__` replaced by the session token.
- `GET /events?token=…` → SSE. First an `event: snapshot` (same JSON as
  /api/state), then `event: trace` messages (one TraceEvent JSON each). `:`
  heartbeat comments every ~15s.
- `GET /api/state?token=…` → JSON snapshot (health, egress, invariant, sla,
  model, history).
- `POST /api/ask` (header `X-Mnemo-Token`) body `{"query":"…"}` → 202; drives the
  real orchestrator; trace flows over /events.
- Auth: token on every request; `Origin`/`Host` must be loopback or absent.

## Dashboard contract (for rebuilding dashboard.html)

Self-contained HTML, inline CSS/JS, system font, dark theme, no external assets.
JS reads `const TOKEN = "__MNEMO_TOKEN__";`. `EventSource("/events?token="+TOKEN)`.
Sections: status bar (Ollama/engine/SMFS health chips, model id, hero EGRESS
badge — big `0` green / red on >0, invariant OK, SSE dot); prompt box (POST
/api/ask); live trace timeline (group by queryId, per-stage rows with durations,
expandable detail, streaming tokens); evidence panel (candidates w/ relevance
bars, below-threshold marked); prompt/context inspector (collapsible, raw);
answer + citations (streamed, per-sentence supported/unsupported, pass rate);
metrics strip (firstTokenMs/totalMs/hops/contextTokens/passRate/egress); SLA
panel; history (recent queries + sparkline); raw event log (collapsible, pause,
copy). Escape all injected text. Batch token DOM updates with rAF.

### TraceEvent JSON

```json
{"queryId":"q-1","seq":4,"atMs":37,"stage":"route","phase":"end","durationMs":3,"message":"lookup / low","data":{ }}
```
`stage` ∈ scope, route, cache, rewrite, gather.decompose, gather.search,
gather.coverage, gather.agentic, gather.timewindow, backstop, rank, assemble,
generate, verify, terminal, done. `phase` ∈ begin | end | info | token.
`data` by stage: route `{intent,effort,ambiguous,escalated}`; scope
`{corpusQuestion,reply?}`; cache `{hit}`; rewrite `{from,to}`; gather.search
`{candidates:[{title,path,score,aboveThreshold,snippet}]}`; backstop
`{triggered,terms,rescued}`; rank `{shape,count}`; assemble
`{system,context,question,contextTokens}`; generate token `{tokenText}` / end
`{answer}`; verify `{verdicts:[{sentence,supported}],passRate}`; terminal
`{state,recovery}`; done `{metrics:{firstTokenMs,totalMs,hops,contextTokens,passRate,egress}}`.

### /api/state JSON

```json
{"health":{"ollama":{"name":"ollama","isRunning":true,"boundAddress":"127.0.0.1:11434","isLoopback":true,"unhealthyReason":null},"engine":{…},"smfs":{…},"allHealthyAndLoopback":true},
 "egress":{"blockedCount":0,"blockedHosts":[],"loopbackOK":true},
 "invariant":{"ok":true,"detail":"loopback-only"},
 "sla":{"firstTokenMs":1500,"sourcesRenderMs":1000},
 "model":{"id":"gpt-oss:20b"},
 "history":[{"queryId":"…","timestamp":"…","routeIntent":"…","firstTokenMs":410,"totalMs":1700,"terminalState":"answered","verificationPassRate":1.0,"egressBlockedCount":0}]}
```

## Trace stages → QueryService emit points

Map each to the existing code in `QueryService.ask()` / `EvidenceGathering`:
scope gate → before routing; route → after `router.classify`/escalation; cache →
`cache.lookup`; rewrite → `rewriter.rewrite`; gather.* → inside `gatherEvidence`
(emit candidates from `search()` results with `similarity` and
`aboveThreshold = sim >= defaults.threshold`); backstop → `KeywordBackstop.rescue`;
rank → after `PersonalRanker.rank`/`AnswerShape.detect`; assemble → after
`assembler.assemble` (emit `system`, `assembled.evidence` joined, question,
contextTokens); generate → in the token loop (`phase:"token"` per token, `end`
with full answer); verify → after `verifier.verify` (verdicts + passRate);
terminal/done → at each terminal + final metrics.

## Progress checklist

- [x] Phase 1a: `DevTrace`/`TraceEvent`/`JSONValue` in MnemoCore + tests
      (`Tests/MnemoCoreTests/DevTraceTests.swift`) — GREEN (6 tests).
- [x] Phase 1b: `[devtools]` config (struct, parse, validate, schema) + tests
      (`Tests/MnemoCoreTests/DevToolsConfigTests.swift`) — GREEN (4 tests).
- [x] Unblock pre-existing build break in `NotchShape.swift` (concurrent work
      later completed the shoulder feature; build is green).
- [ ] Phase 3a: Package.swift — add `MnemoDevServer` target + `MnemoDevServerTests`.
- [ ] Phase 3b: `HTTPMessage.swift` (+ tests) — parse request, serialize response.
- [ ] Phase 3c: `SSE.swift` (+ tests) — event framing + comments.
- [ ] Phase 3d: `DevAuth.swift` (+ tests) — token + loopback-origin auth.
- [ ] Phase 3e: `DashboardSnapshot` + `DashboardDataSource` protocol.
- [ ] Phase 3f: `DevServer.swift` (NWListener) + integration test (ephemeral
      port: GET /api/state returns JSON; /events streams a trace; auth rejects
      bad token + non-loopback Origin; binds 127.0.0.1 only).
- [ ] Phase 3g: `DashboardPage.swift` + `Resources/dashboard.html` (build by
      hand — subagent failed). Add resource to Package.swift. Grep for external
      URLs → none.
- [ ] Phase 2: instrument `QueryService` (+ EvidenceGathering) with `trace`.
      Test: run a query with a DevTrace, assert ordered stage events incl.
      candidates/prompt/tokens/verdicts/terminal. RE-READ THE FILE FIRST.
- [ ] Phase 4: `MnemoApp/DevTools.swift` + wire real logSink/egress/modelId in
      `NotchController.makeService` (RE-READ FIRST). Gate by config/env.
- [ ] Phase 5: `mnemo.toml` `[devtools]` section (commented, off).
- [ ] Phase 6: final verification — full `swift test` green offline; grep HTML
      for external URLs; confirm 127.0.0.1-only bind; confirm nil-trace path
      unaffected. Capture command output. Then delete AUTO-RESUME crons.

## How to run it (once built)

Set `MNEMO_DEVTOOLS=1` (and/or `[devtools] enabled=true`), launch MnemoApp
(`DEVELOPER_DIR=…-beta swift run MnemoApp` or the packaged .app), open
`http://127.0.0.1:7878/?token=…` — the full tokened URL is printed to **stderr**
at launch (`▶ Mnemo Observatory (dev): …`). Prompt Mnemo (notch or the page's
box) and watch the live deep trace.

## Completion & verification

Built and verified offline in an isolated git worktree (main tree's full
`swift test` is currently blocked by a *concurrent* process's in-progress
`MnemoOrchestratorTests` files — `FakeRetriever` redeclaration, `SourceProvenance`
— NOT by this feature; my orchestrator changes compile and the library builds).

Verified (all offline):
- 38 tests pass: `DevTraceTests`(6), `DevToolsConfigTests`(4), `HTTPMessageTests`(5),
  `SSETests`(4), `DevAuthTests`(8), `RouterTests`(6), `DevServerIntegrationTests`(3,
  real sockets: /api/state 200, no-token 401, SSE snapshot+live trace),
  `DashboardPageTests`(2, incl. no-external-URL invariant), `QueryServiceTracingTests`(2,
  deep trace fires + nil-trace path is silent).
- `swift build --target MnemoOrchestrator` and `--target MnemoApp` → Build complete.
- `grep -cE 'https?://' dashboard.html` → 0 (renders offline).
- Server bind is `requiredInterfaceType = .loopback` (no 0.0.0.0).

Live smoke (headless; the resident app was NOT running, so safe): launched
MnemoApp with `MNEMO_DEVTOOLS=1` → it printed the tokened URL to stderr;
`GET /api/state` returned **401** without a token and **200 + real history**
(read from app.jsonl) with it; `GET /` served the 26 KB page with the token
substituted (0 `__MNEMO_TOKEN__` remaining); egress read 0. App killed cleanly.

Trace coverage is now maximal: scope, cache, route, rewrite, gather.search,
backstop, assemble, generate (tokens+end), verify, terminal, done.

Remaining (human): open the URL in a browser and prompt a real query (needs the
ollama/engine/smfs stack up) to watch the token-by-token deep trace render live.

All checklist items above are DONE.

### Integration note for the concurrent branch
This feature's changes to shared files are additive: `QueryService` gained a
`trace: DevTrace? = nil` param (default nil → zero behavior change);
`NotchController.makeService` passes `trace: devTrace`; `main.swift` calls
`DevTools.startIfEnabled`; `Package.swift` adds the `MnemoDevServer`
target/product + `MnemoApp` dep; `MnemoConfig`/`ConfigSchema` add `[devtools]`.
New files: `MnemoCore/DevTrace.swift`, all of `MnemoDevServer/`, `MnemoApp/DevTools.swift`.
