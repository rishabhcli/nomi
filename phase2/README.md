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
