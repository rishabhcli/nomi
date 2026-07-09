# CLAUDE.md — Operating manual for agents building Mnemo

You are building **Mnemo**, an on-device knowledge assistant for macOS. Read this file **before writing a single line of code**, every session. It turns the product invariant into rules that fail the build when violated. [README.md](README.md) is the intent; [PLAN.md](PLAN.md) is the execution spec; this file is how you work.

---

## 0. The one rule everything else serves

> **The answer path, the memory, and the model all live on the machine. Mnemo works identically with the network physically off.**

If a change could let any part of the answer path, the memory, or the model reach the network, **stop**. That is not a feature to weigh against others — it is the product. Enforce it by wiring, prove it by measurement, never defend it by policy.

**Litmus test before any commit:** *"If I unplug the network right now, does this still work?"* If the honest answer is "no" or "I'm not sure," you are not done.

---

## 1. Non-negotiable invariants (violations are P0, build-breaking)

1. **Loopback only.** Every process binds `127.0.0.1`. Never `0.0.0.0`, never a LAN address. `engine.base_url`, `model.runtime_base_url`, and `smfs.backing_store` must all be loopback and are validated at startup ([PLAN.md → Appendix A](PLAN.md#appendix-a--configuration-mnemotoml)).
2. **No cloud backing store.** SMFS backing store == the local engine. Any reference to `api.supermemory.ai` or any non-loopback host outside a code comment or a docs link is a defect. `smfs.backing_store` must equal `engine.base_url`.
3. **Local model only.** All generation — routing, extraction, synthesis, verification — goes to local Ollama. There is no hosted-inference fallback for any path. Do not add one "just for reliability."
4. **Egress is measured.** The M10 guard counts outbound non-loopback connection attempts during a query. The only correct value is **0**. A non-zero count fails CI.
5. **No telemetry.** App, engine, SMFS, and Ollama all have telemetry off. Do not add analytics, crash reporters, or "anonymous usage stats" that egress.
6. **The state machine has no silent failures.** Every terminal state is a defined, rendered output ([PLAN.md → M12](PLAN.md#m12--interaction-polish--state-machine)). A query that returns nothing to the user is a bug, not an edge case.

If you believe an invariant must be bent to ship a feature, the feature is wrong, not the invariant. Escalate to the user before proceeding — do not quietly work around it.

---

## 2. How to work here (process, not vibes)

You have Superpowers skills. Use them — this is not optional.

- **Before any feature or behavior change:** `superpowers:brainstorming` (you are past this for the overall design; use it again for any milestone whose approach is unclear).
- **Before writing implementation code:** `superpowers:test-driven-development`. Write the acceptance test from the milestone first, watch it fail, then implement. Every `AT-M*` and `BS-M*` in PLAN.md is a test to write, not prose to admire.
- **Any bug/failure/unexpected behavior:** `superpowers:systematic-debugging` before proposing a fix. No guess-and-check.
- **Before claiming done:** `superpowers:verification-before-completion`. Run the commands, capture the output, then claim. Evidence before assertions, always.
- **Before merging a milestone:** `superpowers:requesting-code-review`.
- **Independent milestone branches:** `superpowers:dispatching-parallel-agents` (see the dependency graph in [PLAN.md → Appendix D](PLAN.md#appendix-d--milestone-dependency-graph)).
- **Executing a milestone plan across sessions:** `superpowers:executing-plans` / `superpowers:writing-plans`.

**One milestone at a time, in order.** Do not start M(n+1) until M(n)'s Definition of Done is met and every acceptance test is green with the network off.

---

## 3. Definition of Done (applies to every milestone)

A milestone is done only when **all** of these hold:

- [ ] Every `AT-M*` acceptance test for the milestone passes, **with the network physically off** (except the M10 egress-detection tests, which need a live interface to prove blocking).
- [ ] The milestone's `BS-M*` beats-Siri criterion passes — it is a product gate, not decoration.
- [ ] The loopback and egress invariant checks still pass (run them at every milestone, not just M0/M10).
- [ ] Code review requested and addressed (`superpowers:requesting-code-review`).
- [ ] No new file exceeds ~400 lines without a reason; responsibilities stayed separated.
- [ ] Metrics the milestone introduces ([PLAN.md → Appendix B](PLAN.md#appendix-b--observability--metrics)) are wired and each maps to a test.
- [ ] The verification output (command + result) is captured, not asserted from memory.

"I think it works" is not done. "Here is the command and its output showing it works offline" is done.

---

## 4. Stack & conventions

- **Language/UI:** Swift + SwiftUI, **deployment target macOS 26.0** (`platforms: [.macOS(.v26)]`) — required by Liquid Glass. The surface **lives in the notch**: a **non-activating `NSPanel`** anchored to notch geometry that expands on hover, becomes key so typing is immediate, and renders the answer below the notch. It is a system surface, not an app window. Orchestrator is an **in-process** Swift async service — no separate daemon for the query lifecycle.
- **Liquid Glass (required, macOS 26):** build the surface with the real APIs — `glassEffect(_:in:)`, a single shared `GlassEffectContainer` (**glass cannot sample glass** — group them), `glassEffectID` + `@Namespace` for the notch → answer morph, and `.buttonStyle(.glass)`/`.glassProminent`. **Never** fake it with hand-rolled blur/vibrancy. Glass floats above content; content stays at the base layer. Honor Reduce Motion, Increase Contrast, and VoiceOver.
- **Motion is a spec, not a vibe.** The notch surface's animations (easing, springs, radii, the blur-morph, the spinner) are defined in **[UI.md](UI.md)**. The Mac notch is a **fixed hardware cutout** — never try to reshape it; draw a surface that **grows out from beneath it** via a concave-shouldered `NotchShape` whose black collar continues the notch. Geometry is **read from `NSScreen` at runtime**, never hardcoded. Build to match the reference *feel*; the [UI.md fidelity checklist](UI.md#11-fidelity-checklist) is the acceptance bar. Do not improvise timings — tune the documented tokens against the recording.
- **Voice dictation (on-device):** press-hold the notch dictates via the **Speech** framework (`SpeechAnalyzer` / `DictationTranscriber` / `SpeechDetector`) — never a cloud STT. Audio is captured with `AVAudioEngine` and **must not egress**. The listening orb is a **Metal fragment shader** (SwiftUI `ShaderLibrary` + `TimelineView(.animation)`), reactive to a smoothed mic-amplitude envelope (grows bigger/brighter/more saturated as the user talks), targeting 120fps. Spec: [UI.md → §12](UI.md#12-voice-dictation--the-listening-orb).
- **Notch geometry:** detect the notch with `NSScreen.safeAreaInsets.top > 0`; size it from `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`. On screens with `safeAreaInsets.top == 0`, draw a **virtual notch** — the interaction must work on every Mac and display, physical notch or not. The panel is non-activating (app behind stays active) but becomes key **only while expanded** so the input takes text immediately.
- **Concurrency:** Swift structured concurrency (`async/await`, `AsyncStream`). Interactive work is highest priority; background work (`ingest`, `dream`) runs at `.utility`/`.background` and must yield ([PLAN.md → M11](PLAN.md#m11--concurrency--scheduling)).
- **Config:** everything in `mnemo.toml`. **No hardcoded hosts, ports, or model ids in code.** Read them from config; validate at startup.
- **Data model:** the `Codable` structs in `Shared/` mirror [PLAN.md → Global data model](PLAN.md#global-data-model). Map to the engine's JSON at the client boundary only.
- **Errors are values.** The query path returns a `TerminalState` enum, exhaustively handled — the compiler enforces that every state renders something.
- **Logging:** local only, to `~/Library/Logs/Mnemo/`. Structured. Never log document contents at info level (privacy — the corpus is the user's).
- **Dependencies:** prefer the platform and the three managed processes. Do not add a dependency that phones home. Audit every new dependency for network behavior.

---

## 5. Running the stack (developer loop)

```bash
# Model runtime (loopback)
ollama serve                                  # 127.0.0.1:11434
ollama pull gpt-oss:20b                        # recommended tier; qwen3:4b on a 12GB box
ollama run gpt-oss:20b "warm up"               # confirm weights load

# Engine (self-hosted Supermemory, loopback, BYOM=ollama, local embeddings)
mnemo engine start                             # supervises the binary on 127.0.0.1:6767

# Filesystem (SMFS, backing store = local engine)
mnemo mount ~/Mnemo/memory                     # real NFS mount, no kext

# App
open App/                                       # build & run the SwiftUI shell
```

**Health & invariant checks (run these constantly):**
```bash
# Loopback proof — no non-loopback LISTEN for our processes
lsof -iTCP -sTCP:LISTEN -n -P | grep -E '6767|11434'   # expect only 127.0.0.1

# Egress proof — during a query, zero non-loopback connections
nettop -P -l 1 | grep -i mnemo                          # expect no non-loopback peers
lsof -i -nP | grep -i -E 'mnemo|ollama|supermemory'     # inspect live connections

# The real test: turn Wi-Fi off, unplug Ethernet, run the full query set. It must work.
```

---

## 6. Guardrails — do not do these

- ❌ Add any hosted-inference or hosted-memory fallback "for reliability." The local stack *is* the reliability story.
- ❌ Point SMFS or the SDK at the Supermemory cloud, even in a dev/debug build. Dev builds must obey the invariant too, or the tests lie.
- ❌ Bind anything to `0.0.0.0` or a LAN IP "to test from my phone."
- ❌ Do a cold model load on the query path. The model is warm-resident; a cold load is a bug ([PLAN.md → M0](PLAN.md#m0--bootstrap--process-supervision), [M11](PLAN.md#m11--concurrency--scheduling)).
- ❌ Return an empty screen. Every dead end is a defined `TerminalState` with a rendered output and, where relevant, one-tap recovery.
- ❌ Fake Liquid Glass with hand-rolled blur/vibrancy, or let one glass element sample another. Use `glassEffect`/`GlassEffectContainer`; group glass in a single container.
- ❌ Assume a physical notch. Notch-less Macs and external displays get a virtual notch with identical behavior.
- ❌ Require a click before typing. On summon the panel takes key focus and the field is first responder — typing is immediate.
- ❌ Lower the deployment target below macOS 26. Liquid Glass requires it; a lower target breaks the UI-consistency guarantee and won't compile the glass surface.
- ❌ Send microphone audio to any network speech-to-text. Dictation is on-device (`SpeechAnalyzer`) only; captured audio must never egress.
- ❌ Fake the voice orb with stacked SwiftUI gradients/blurs. It is a GPU Metal shader and must sustain the display refresh (120fps on ProMotion) with no dropped frames.
- ❌ Let the assistant answer from outside the provided context. The generation contract is: answer only from context, cite each claim, say plainly when the corpus lacks it. M5 verifies this — do not defeat the verifier.
- ❌ Invent facts in consolidation. Synthesized memories must cite their constituent memories and remain subject to M5 grounding.
- ❌ Block the interactive path with background work. Ingesting a folder or a dreaming pass must never stall a live question.
- ❌ Claim done without running the offline acceptance tests and capturing output.

---

## 7. Build the demo you must beat

The product bar is **Siri AI in macOS 27**, which routes cross-document synthesis to Private Cloud Compute (needs network) and keeps its model of the user opaque. Every milestone carries a `BS-M*` criterion; the culmination is `BS-M12` — one continuous offline demo:

> Drop the cursor to the notch → it expands (Liquid Glass) and takes the keyboard → a personal, grounded answer with **verified** citations renders below the notch → open the source in Finder → open the memory inspector, delete a fact → re-ask, watch Mnemo forget it → the whole time, the egress indicator reads **zero outbound**.

If that demo runs offline and Siri's equivalent cannot, Mnemo has done its job. Keep it recorded at `Tests/Fixtures/demos/beats-siri.mov` and green.

---

## 8. When you are unsure

- **Design ambiguity in a milestone?** `superpowers:brainstorming`, then confirm with the user before building.
- **A test is hard to make deterministic (LLM-judged)?** Assert on thresholds/distributions over a fixture set, not single-sample equality ([PLAN.md → Appendix C](PLAN.md#appendix-c--testing-strategy)).
- **Tempted to bend an invariant?** Stop and ask the user. The invariant is the product; if it truly blocks a requirement, that is a conversation, not a workaround.
- **A capability seems missing from the managed processes?** Verify against the live docs before declaring it impossible — the Supermemory self-hosted engine and SMFS are the substrate, and much of what you'd otherwise build (OCR, transcription, chunking, embeddings, the graph) is already theirs.

Report outcomes faithfully. If a test fails, say so with the output. If a step was skipped, say that. When something is verified offline, state it plainly — with the evidence.
