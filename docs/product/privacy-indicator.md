# Privacy indicator semantics

The egress indicator is a **measurement**, not a policy claim. It reflects live `EgressGuard` state during the session.

## States (`PrivacyIndicator`)

| State | Meaning | UI |
|-------|---------|-----|
| `.clean` | `outboundNonLoopbackAttempts == 0` | Green dot / "On-device" |
| `.egressDetected(count: n)` | n non-loopback attempts recorded | Red dot / "Egress blocked: n" |

**Source:** `Sources/MnemoOrchestrator/EgressGuard.swift`  
**Config:** `mnemo.toml` → `[privacy] show_egress_indicator = true`

## Measurement window

1. `beginQueryWindow()` at query start
2. `recordAttempt(host:)` on each outbound URLSession open
3. Loopback hosts (`127.0.0.1`, `localhost`, `::1`, full `127.x.x.x` quads) **do not** increment
4. `PrivacyIndicator.from(guard)` polled for UI refresh
5. `endWindow` at query complete

## Blocking mode

When `egress_guard = "enforce"` and `block_on_egress = true`:

- `LoopbackGuardURLProtocol` intercepts non-loopback requests
- Request fails with `MnemoEgressGuard` error
- Counter increments (AT-M10.3)

## What it does NOT mean

- Green does not prove Wi-Fi is off — it proves **Mnemo's clients** attempted zero non-loopback connections
- Other processes (unrelated apps) are not counted
- DNS to non-loopback may still occur at OS level; Mnemo's guard covers **its** URLSession stack

## BS-M12 requirement

Egress indicator must read **clean (0)** for the entire continuous demo. If `egressDetected` appears, the demo fails BS-M10 and BS-M12.

## Tests

```bash
swift test --filter 'EgressGuardTests|ProductDocTests.testPrivacyIndicator'
```

| Test | AT-M |
|------|------|
| `testPrivacyIndicatorCleanWhenZeroEgress` | AT-M10.5 |
| `testPrivacyIndicatorEgressWhenBlocked` | AT-M10.5 |
| `LoopbackGuardURLProtocolTests` | AT-M10.3 |

## Manual verification

```bash
lsof -i -nP | grep -iE 'MnemoApp|ollama|supermemo' | grep -vE '127\.0\.0\.1|LISTEN'
# expect: empty during query
```
