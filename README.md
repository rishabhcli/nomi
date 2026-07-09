# Mnemo — an on-device knowledge assistant for macOS

> Working codename: **Mnemo** (from *Mnemosyne*, memory). Rename freely; the name appears only in UI strings and the launchd labels.

Mnemo is a resident macOS assistant that answers natural-language questions over **your own files** with synthesized, **cited** answers, and keeps a **memory of you that you can read and edit** — all on-device. It works identically with the network physically off, because the answer path, the memory, and the model all live on the machine. That is the single invariant this project exists to protect, and it is enforced by **wiring, not policy**.

---

## Why this exists (and what it beats)

In June 2026 Apple shipped **Siri AI** in macOS 27 "Golden Gate": a genuinely capable personal assistant that reads across your mail, notes, photos, and files, compares PDFs, and understands what's on screen. It is a real product and a real bar. But two of its design choices leave a gap Mnemo is built to fill:

1. **Complex synthesis leaves the device.** Simple requests run on-device; requests too complex for on-device — the cross-document synthesis this product performs — are routed to **Private Cloud Compute**, which requires an internet connection. Mnemo performs the equivalent cross-document synthesis **locally**, so it holds with the network off. ([Apple](https://www.apple.com/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/))
2. **Its model of you is a black box, and conversations sync to iCloud.** Mnemo's memory is a graph you can **inspect and correct**; deleting a fact retracts it from what the assistant knows. Nothing about you is stored off the machine.

| | **Siri AI (macOS 27)** | **Mnemo** |
|---|---|---|
| Simple lookups | On-device | On-device |
| **Cross-document synthesis** | **Private Cloud Compute (needs network)** | **On-device (holds network-off)** |
| Works airplane-mode for hard questions | No | **Yes — verifiable at the socket layer** |
| Conversation / history storage | Synced to iCloud | Stays on device |
| Your profile / "what it knows about you" | Not user-inspectable | **Inspectable, editable, retractable** |
| Citations | Comparison tables | **Real char-offset spans, post-verified** |
| Model | Licensed 1.2T Gemini (Apple) | `gpt-oss:20b` (Apache-2.0, local) |

Mnemo does not try to out-scale Apple. It wins on the axis Apple conceded: **the hard questions stay on your machine.**

---

## The invariant

> **The answer path, the memory, and the model all live on the machine. Mnemo works identically with the network physically off.**

Every design decision in [PLAN.md](PLAN.md) preserves this. It is not a promise printed in a privacy policy — it is a property of the process topology (loopback-only binding), the model (local Ollama), the memory backing store (SMFS points at the local engine, not the cloud), and an explicit **network-egress guard** that makes "zero outbound connections during a query" a *measured* fact surfaced in the UI. See [PLAN.md → M10](PLAN.md#m10--offline--privacy-enforcement).

---

## Architecture at a glance

Four local processes, all bound to `127.0.0.1`, none listening beyond loopback. There is **no configured path off the machine**.

```
                      ┌───────────────────────────────────────────────┐
                      │  Swift app shell + in-process orchestrator      │
                      │  • notch-resident Liquid Glass surface (hover)  │
                      │  • query lifecycle (route → assemble → generate)│
                      │  • SSE stream to UI   • process supervisor       │
                      │  • network-egress guard (measured, not claimed) │
                      └───────┬───────────────┬───────────────┬────────┘
                              │ HTTP           │ HTTP/SSE      │ filesystem
                              ▼                ▼               ▼
        ┌─────────────────────────┐  ┌──────────────┐  ┌────────────────────────┐
        │ Supermemory (self-host) │  │   Ollama     │  │  SMFS mount (NFS)       │
        │ 127.0.0.1:6767          │◄─┤ :11434       │  │  ~/Mnemo/memory/...     │
        │ • ingest, extract       │  │ gpt-oss:20b  │  │ • kernel mount          │
        │ • local embeddings      │  │ warm resident│  │ • local SQLite cache    │
        │ • memory graph          │  │ BYOM for     │  │ • backing store =        │
        │ • hybrid search/profile │  │ extraction   │  │   LOCAL engine (:6767)  │
        └─────────────────────────┘  └──────────────┘  └────────────────────────┘
         documents = ground truth; memories = inferred facts, linked by similarity edges
```

- **Supermemory self-hosted** — a single open-source binary that owns ingestion, local embedding, the memory graph, hybrid search, and profile generation. Its "bring your own model" slot points at Ollama. ([self-hosting docs](https://supermemory.ai/docs/self-hosting/overview))
- **SMFS** — mounts a Supermemory container as a **real NFS filesystem on macOS with no kext / no macFUSE**. Configured so its backing store is the **local** engine. Flagless `grep` inside the mount is semantic; `grep -F` falls through to literal. ([smfs](https://github.com/supermemoryai/smfs))
- **Ollama** — serves `gpt-oss:20b` (21B MoE, **3.6B active/token**, 128k context, Apache-2.0), kept warm so a cold weight-load never falls on a user query. ([model card](https://huggingface.co/openai/gpt-oss-20b), [Ollama](https://ollama.com/library/gpt-oss:20b))
- **Swift app shell + orchestrator** — native SwiftUI overlay plus the in-process query lifecycle service.

---

## How a question is answered

1. **Route** the query (lookup / profile / single-shot synthesis / multi-hop) with fast heuristics, escalating to one structured model call only when ambiguous.
2. **Assemble context**: the profile's static/dynamic facts as a persistent preamble (this is why Mnemo "already knows you"), then reranked memories and raw chunks, each tagged with source title, path, and char span. Trimmed to what's relevant — never the whole corpus.
3. **Generate** with the local model under a strict contract: answer *only* from context, cite each claim, and say plainly when the corpus lacks the answer.
4. **Verify & stream**: source cards render sub-second while the answer streams above them; a post-generation pass re-checks each sentence against the retrieved text and flags anything unsupported.

Full lifecycle in [PLAN.md → M4](PLAN.md#m4--query-lifecycle--routing)–[M5](PLAN.md#m5--grounding--citation-verification).

---

## Lives in the notch

Mnemo is not an app window — it's a **system surface that lives in the notch**. The Mac notch is fixed hardware, so Mnemo doesn't reshape it; instead, move the cursor to the top of the screen and a surface **grows out from beneath the notch** with a fluid **Liquid Glass** morph — its black collar continuing the notch so it reads as one object — flaring into a chat input. The keyboard is live immediately (it's a Mac — no on-screen keyboard), so you start typing without a click. As Mnemo searches, the surface animates; the synthesized answer and its source cards render **below the notch** — reading-grade markdown on Liquid Glass, the same material Apple uses for Siri's answer surface in macOS 26/27, but notch-native and fully offline. ESC or click-away retracts it back into the notch. A global hotkey is the equivalent summon for keyboard-only use, and Macs or displays without a physical notch get a drawn **virtual notch** with identical behavior. **Press-and-hold the notch** to talk instead of type: a Siri-grade **listening orb** blooms with your voice — brighter and bigger as you speak — powered by macOS's on-device `SpeechAnalyzer`, so even dictation holds with the network off. The full motion spec — springs, the concave-shouldered shape, the blur-morph, and the voice orb — is in **[UI.md](UI.md)**.

---

## The memory is alive

Mnemo does not keep a pile of chunks. The graph evolves:

- **Versioning & contradiction** — "I moved to SF" supersedes "I live in NYC," in place.
- **Decay & forgetting** — ephemeral facts ("exam tomorrow") carry TTLs and expire; soft-delete preserves history for audit.
- **Consolidation ("dreaming")** — a background pass promotes recurring dynamic facts into stable static ones, synthesizes higher-level patterns, and archives cold memories. Frequently retrieved facts strengthen; neglected ones fade. The profile **sharpens with use** instead of bloating.

Details in [PLAN.md → M6](PLAN.md#m6--memory-dynamics) and [M8](PLAN.md#m8--consolidation-dreaming).

---

## Requirements & hardware tiers

**macOS 26 "Tahoe" or later is required** — the UI is built on **Liquid Glass**, Apple's macOS-26 material, so the surface stays visually consistent with the system (and its SwiftUI APIs only exist on 26+). Mnemo lives **in the notch**, with a drawn virtual notch on Macs and displays without a physical one, so any Apple silicon Mac qualifies.

Mnemo targets the same hardware floor as Siri AI (**Apple silicon, ~12GB**) but is honest about what the model needs:

| Tier | Machine | Primary synthesis model | Notes |
|---|---|---|---|
| **Recommended** | Apple silicon, **16GB+**, **macOS 26+** | `gpt-oss:20b` (MXFP4) | ~12GB weights + ~2.7GB buffers + KV; full reasoning-effort range |
| **Floor** | Apple silicon, **12GB**, **macOS 26+** | fallback 4–8B (`qwen3:4b` / `llama3.1:8b`) | same code path, swapped weights; high effort capped |

Model selection is a single config key ([PLAN.md → Configuration](PLAN.md#appendix-a--configuration-mnemotoml)); the answer path does not change between tiers.

---

## Quickstart (target end state — see PLAN.md for the build)

```bash
# 1. Model runtime
brew install ollama
ollama serve &                      # binds 127.0.0.1:11434
ollama pull gpt-oss:20b             # ~12GB; on a 12GB Mac pull the fallback instead

# 2. Memory engine (self-hosted Supermemory, loopback only)
mnemo engine start                  # supervises the binary on 127.0.0.1:6767, BYOM=ollama

# 3. Filesystem (SMFS, backing store = local engine)
mnemo mount ~/Mnemo/memory          # real NFS mount, no kext

# 4. App
open /Applications/Mnemo.app        # lives in the notch; hover the notch (or hotkey) to summon

# Add knowledge: drop any file — pdf, image, audio, video, doc — into ~/Mnemo/memory/
# Ask: drop the cursor to the notch, type a question, get a cited answer. Turn Wi-Fi off; it still works.
```

---

## Repository map

| File | Audience | Contents |
|---|---|---|
| **[README.md](README.md)** | humans evaluating the product | this file — vision, invariant, architecture, comparison, quickstart |
| **[PLAN.md](PLAN.md)** | AI agents building it | the exhaustive, milestone-by-milestone execution spec with interfaces, data shapes, and acceptance tests |
| **[UI.md](UI.md)** | AI agents building the UI | the motion bible — the notch surface's animations, easing, radii, and the blur-morph, reverse-engineered frame-by-frame from the reference recording |
| **[CLAUDE.md](CLAUDE.md)** | AI agents building it | operating manual — invariants, conventions, how to run/verify, definition-of-done, guardrails |

**Every contributor — human or agent — must read [CLAUDE.md](CLAUDE.md) before writing a line of code.** The invariant above is non-negotiable, and CLAUDE.md is where it is turned into rules that fail the build when violated.
