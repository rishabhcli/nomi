# Comparison table accuracy

Mnemo vs Siri AI (macOS 27). Every row is verifiable; no marketing inflation.

| Capability | Siri AI (macOS 27) | Mnemo | Verification |
|------------|-------------------|-------|--------------|
| Simple lookups | On-device | On-device | Both — not differentiator |
| **Cross-document synthesis** | Private Cloud Compute (**network required**) | **On-device** (`gpt-oss:20b` local) | `SmarterThanSiriTests` B53; `scripts/airplane-parity.sh` |
| **Airplane mode (hard questions)** | No | **Yes** | AT-M10.4; BS-M10; egress monitor |
| Conversation storage | iCloud sync | Stays on device | Architecture diagram; no iCloud code |
| Profile inspectable | No user-facing inspector | **Inspector + delete/correct** | `InspectorTests`; BS-M12 step ⑤⑥ |
| Citations | Comparison tables | **Char-offset spans, post-verified** | `CitationVerifierTests`; AT-M5.* |
| Model | Apple 1.2T Gemini (licensed) | `gpt-oss:20b` Apache-2.0 local | `mnemo.toml`; no cloud inference path |
| Dictation | Cloud optional | **On-device SpeechAnalyzer** | AT-M12.10; network-off manual |
| Egress during query | Non-zero (PCC path) | **Measured zero** | `EgressGuardTests`; privacy indicator |

## Axes under test

`ProductDocContract.comparisonAxes`:

1. `cross_document_synthesis`
2. `airplane_mode_hard_questions`
3. `conversation_storage`
4. `profile_inspectable`
5. `citations`
6. `model`

**Test:** `ProductDocTests.testComparisonAxesCoverSiriGap`

## Apple source

[Siri AI announcement (June 2026)](https://www.apple.com/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/) — complex synthesis uses Private Cloud Compute.

## Mnemo proof artifact

`Tests/Fixtures/demos/beats-siri.mov` — continuous demo per `docs/product/bs-m12-demo-script.md`.

## Honest limitations

| Mnemo does NOT claim | Reality |
|---------------------|---------|
| Out-scale Apple's model | 20B local vs 1.2T cloud |
| Match Siri screen awareness | Mnemo is corpus-only |
| Replace system Siri | Coexists; different axis (privacy + offline synthesis) |
