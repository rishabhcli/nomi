# Helpfulness refusal copy

User-visible messages when Mnemo cannot or will not answer. **Never invent; never silent.** Source: `NotchReducer.message(for:)` in `Sources/MnemoOrchestrator/NotchReducer.swift`.

## Terminal refusals

| State | Copy | Recovery affordance |
|-------|------|---------------------|
| `.unsupportedAnswer` | "I couldn't ground an answer in your files, so I won't guess." | Broaden search |
| `.empty(nearest:)` | "Nothing in your files matches that closely. Try broadening the question." | Broaden |
| `.emptyCorpus` | "No files yet. Drop documents into ~/Mnemo/memory to start — PDFs, notes, images, audio all work." | Add files |
| `.indexing(path)` | "Still indexing {filename} — ask again in a moment." | Wait & retry |
| `.modelNotLoaded(model)` | "The model {model} isn't loaded. Load it to continue." | Load model |
| `.engineUnreachable` | "The memory engine isn't responding. Restart it to continue." | Restart engine |

## In-answer refusals (streaming)

When corpus lacks the answer but retrieval returned weak matches:

- Generator contract: state plainly when context lacks the answer.
- Example (M1 fixture): *"I'm sorry, but the provided notes don't contain any information about your dog's name."*
- **AT-M1.3:** `QueryServiceTests`, `scripts/m1-acceptance.md`.

## Self-correction retry

On failed verification:

- Event: `.retrying("That wasn't grounded — reconsidering using only your files…")`
- Discards draft answer; returns to searching phase.
- Source: `ResponseStyle.lifecycleEvents(branch: .retry)`.

## Confidence framing (not refusal)

| Level | Framing |
|-------|---------|
| High | "Grounded in your files…" |
| Medium | Balanced qualification |
| Low | "Loose match" / infer language |

`ExpressivenessTests` ConfidenceTests — distinct from terminal refusal.

## Tests

```bash
swift test --filter 'TerminalStateRenderTests|ProductDocTests.testRefusalCopy|Helpfulness'
```

- `ProductDocTests.testRefusalCopyDoesNotInvent`
- `ProductDocTests.testTerminalCopyMatchesUIContract`
- AT-M12.7 — no empty terminal render

## Voice / dictation errors

Dictation failures route through `presentInfo` — always visible in input/drop phases, not gated on answering.
