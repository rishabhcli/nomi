# Hardware tier honest SLA

Mnemo does not over-promise latency on constrained hardware. Tiers map to `mnemo.toml` model keys and SLA section.

## Tiers

| Tier | RAM | macOS | Model (`mnemo.toml`) | Notes |
|------|-----|-------|----------------------|-------|
| **Recommended** | 16GB+ | 26+ | `gpt-oss:20b` | ~12GB weights + KV; full effort range |
| **Floor** | 12GB | 26+ | `qwen3:4b` / `llama3.1:8b` | Same code path; high effort capped |

**Test:** `ProductDocTests.testHardwareTiersHonest`  
**Source:** `README.md` Requirements, `ProductDocContract.hardwareTiers`

## SLA targets (`[sla]`)

| Metric | P95 target | Measurement |
|--------|------------|-------------|
| `first_token_ms` | ≤ **1500** | Query start → first `.token` |
| `sources_render_ms` | ≤ **1000** | Query start → `.sources` event |

**Test:** `ProductDocTests.testSLATargetsFromConfig`  
**Report:** `Tests/Fixtures/m11-slo-report.txt`

## What we promise

- On **recommended** tier with warm model: first token under 1.5s with background ingest running (M11)
- Source cards before answer tokens (AT-M1.4) — perceived latency lower than first token
- Floor tier: functionally complete; synthesis may be slower; multihop may truncate effort

## What we do NOT promise

- Cold model load on query path (bug if it happens)
- Sub-second first token on floor tier for multihop synthesis
- Parity with Siri AI latency when Siri routes to Private Cloud Compute

## Model swap

Single config key change — no code path fork:

```toml
[model]
synthesis = "gpt-oss:20b"   # recommended
fallback  = "qwen3:4b"      # floor auto-select on RAM pressure
```

## Verification

```bash
swift test --filter 'SchedulerTests|ProductDocTests.testHardwareTiersHonest'
cat Tests/Fixtures/m11-slo-report.txt
```
