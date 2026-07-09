# Mnemo Agent Prompt Queue — 1500 Prompts

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
