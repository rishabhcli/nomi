# BS-M12 demo script

**Gate:** one continuous offline demo that beats Siri AI on cross-document synthesis with verified citations, inspector forget, and zero egress.

## Cast

- Operator (you)
- Mnemo notch surface (`Mnemo.app`)
- `mnemoctl` (headless verification fallback)
- Egress monitor / privacy indicator

## Script (UI path — preferred)

| # | Time | Action | Expected | AT-M / BS |
|---|------|--------|----------|-----------|
| ① | 0:00 | Move cursor to notch; surface expands | Input focused < 200ms; app behind stays active | AT-M12.1, AT-M12.2 |
| ② | 0:05 | Type: "Based on my notes, what's my favorite build tool and when did I adopt it?" | Spinner in tray; no collar text | AT-M12.6 |
| ③ | 0:15 | Answer streams | Markdown below notch; source cards first; citations verified | AT-M1.4, AT-M5.2, AT-M12.5 |
| ④ | 0:30 | Click source card | Finder reveals `fixture.md` | AT-M12.6 |
| ⑤ | 0:40 | Open inspector; locate Bazel fact | Static/dynamic chips visible | AT-M9.1 |
| ⑥ | 0:50 | Delete fact | Forgotten + suppressed | AT-M9.2, BS-M6 |
| ⑦ | 1:00 | Re-ask same question | "I don't have information…" — no Bazel | BS-M12 |
| ⑧ | 1:10 | Check privacy indicator | Green / zero egress throughout | AT-M10.5, BS-M10 |

**Egress:** Wi-Fi off for strict proof; or monitor shows 0 non-loopback peers.

## Headless script (CI / cloud agent)

```bash
# ① Ask synthesis
mnemoctl ask --verify "Based on my notes, what's my favorite build tool and when did I adopt it?"

# ③ Inspector delete (capture id from inspect list)
mnemoctl inspect delete <id> "User's favorite build tool is Bazel."

# ⑦ Re-ask
mnemoctl ask "What is my favorite build tool?"
# expect: no favorite build tool in answer

# ⑧ Egress
# egress_blocked_count == 0 in logs; lsof monitor empty
```

Captured transcript: `scripts/m12-acceptance.md`.

## Cross-doc variant (beats Siri core)

```bash
mnemoctl ask "How many weeks did the Aurora migration slip across my notes?"
```

Expect: answer cites ≥3 timeline docs; `SmarterThanSiriTests` B53 gate.

## Recording

- File: `Tests/Fixtures/demos/beats-siri.mov`
- Storyboard: `Tests/Fixtures/demos/beats-siri-storyboard.md`
- Requires Mac with display (headless `screencapture` fails)

## Test map

`swift test --filter 'SmarterThanSiri|ProductDocTests|TerminalStateRenderTests|MicEnvelopeTests'`
