# UI.md — Mnemo Notch Surface Motion Bible

> **Audience:** agents and engineers building the notch UI, voice orb, and state machine.  
> **Invariant:** every animation, material, and terminal copy in this document is enforced by `swift test` filters cited inline. No placeholder sections.

Mnemo is not an app window. It is a **system surface anchored to the Mac notch** — a non-activating `NSPanel` that grows from beneath fixed hardware, takes keyboard focus on expand, and renders grounded answers below the notch. Motion is a **spec**, not a vibe: timings below are measured from reference recordings in `Tests/Fixtures/reference/` and encoded in `Sources/MnemoApp/Motion.swift` and `Sources/MnemoApp/Surface.swift`.

**Cross-links:** geometry tests → `NotchShapeGeometryTests`, `NotchPanelRectTests`; hover → `HoverGeometryTests`; terminal copy → `TerminalStateRenderTests`; orb → `MicEnvelopeTests`; fidelity → §11 checklist.

---

## 1. Design principles

1. **The notch is fixed hardware** — never reshape it. The surface **grows out from beneath** it with an opaque-black collar that continues the notch cutout.
2. **One cohesive object** — body + glass tray + answer zone share a single `GlassEffectContainer`; glass cannot sample glass.
3. **Liquid Glass only (macOS 26+)** — real `glassEffect(_:in:)`, `.buttonStyle(.glass)`, never hand-rolled blur/vibrancy.
4. **Immediate typing** — on summon the panel becomes key; the field is first responder with no prior click.
5. **Every dead end renders** — all `TerminalState` cases produce non-empty copy (`NotchReducer.message(for:)`). Verified: `AT-M12.7`.
6. **Reduce Motion** — springs and blur-morph become opacity cross-fades (`Motion.adaptive`, `Motion.blurMorph(reduceMotion: true)`).
7. **Voice stays on-device** — `SpeechAnalyzer` / `DictationTranscriber`; audio via `AVAudioEngine`; zero egress.

---

## 2. Notch geometry (measured at runtime, never hardcoded)

Read from `NSScreen` at layout time. Pure math in `NotchGeometry` (`Sources/MnemoOrchestrator/NotchGeometry.swift`).

| Signal | Detection | Use |
|--------|-----------|-----|
| Physical notch | `safeAreaInsets.top > 0` **and** `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` widths > 0 | Real notch rect from auxiliary areas |
| Virtual notch | `safeAreaInsets.top == 0` | Draw synthetic notch (width ≈ 185pt, height ≈ 32pt) centered on screen top |
| Panel anchor | `NotchGeometry.panelRect` | **Top edge flush with screen top** (`origin.y = screen.maxY - height`); centered on notch midX |

**AT-M12.3:** virtual notch geometry when `safeAreaInsets.top == 0` — `NotchGeometryTests`.

**Hover arming (§5):** cursor within `notch_hover_zone_px` (default 8, from `mnemo.toml`) of the top edge **and** horizontally over the notch region → arm expand. Pure logic: `NotchHover.isArmed`.

---

## 3. The surface shape — `NotchShape` (the seamless blend)

The silhouette is a **solid black extension** of the hardware notch:

- **Top corners:** square, full-bleed, flush with the screen top (radius 0).
- **Bottom corners:** convex rounding only; radius grows as the body expands.
- **Idle:** hardware-like micro-radius (`Surface.idleRadius` = 9pt).
- **Expanded:** generous bottom radius (`Surface.bottomRadius` = 46pt).

Pure path: `NotchShapeGeometry.path(in:bottomCornerRadius:)` — tested in `NotchShapeGeometryTests`.

| State | `bottomCornerRadius` | Visual |
|-------|------------------------|--------|
| Idle / collapsed | 8–9 | Matches hardware pill |
| Input | 46 | Wide tray, home-indicator pill |
| Searching | 46 | Same width; spinner in tray |
| Answering | 46 | Body grows downward; answer scrolls |
| Voice drop | semicircle pendant | Narrow (`Surface.dropWidth` = 176pt); orb inside |

**AT-M12.1b:** concave-shoulder behavior superseded by square-top redesign (2026-07-09); bottom radius grows with body height — `testBottomCornersAreRounded`, `testRadiusClampsOnTinyRects`.

---

## 4. Panel layout & dimensions

From `Surface` enum (`Sources/MnemoApp/Motion.swift`):

| Token | Value | Role |
|-------|-------|------|
| `inputWidth` / `readWidth` | 520pt | **Same width** for input ↔ searching ↔ answer — pure vertical morph, no sideways jump |
| `bandHeight` | 60pt | Controls row inside glass tray |
| `bandFade` | 34pt | Black body → glass tray blend zone |
| `trayHandle` | 20pt | Home-indicator zone below controls |
| `trayHeight` | 114pt | `bandFade + bandHeight + trayHandle` |
| `answerCap` | 400pt | Answer zone max before scroll |
| `answerFont` | 17pt | Reading-grade white text on black body |
| `maxBodyHeight` | 560pt | Panel sizing bound |
| `dropWidth` | 176pt | Voice pendant width (never widens the notch) |
| `dropBody` | 188pt | Pendant length below notch |
| `orbDiameter` | 120pt | Listening orb diameter |
| `homeIndicatorW` × `homeIndicatorH` | 40 × 5pt | Tray bottom pill |
| `trayTint` | 0.74 | Dark glass — desktop samples through but stays premium |
| `shadowRadius` / `shadowY` / `shadowOpacity` | 32 / 11 / 0.36 | Floating depth |
| `spinnerRing` / `spinnerDot` / `spinnerRPS` | 18 / 2.5 / 1.0 | Six-dot ring while searching |

**Material stack:** opaque `#000` body (continues notch) + dark translucent Liquid Glass tray on the bottom curve only. One `GlassEffectContainer`; shared `glassEffectID` + `@Namespace` for notch → input → answer morph.

---

## 5. Interaction choreography

### 5A. Summon (hover or hotkey)

- **Trigger:** cursor enters hover zone over notch, or global hotkey (`cmd+shift+space` default).
- **Animation:** `Motion.summon` — `spring(response: 0.36, dampingFraction: 0.84)`.
- **Target:** expanded input phase; field becomes first responder.
- **Latency budget:** surface visible and typable in **< 200ms** (`AT-M12.1`, manual).
- **Non-activating:** app behind stays active until expand; panel becomes key **only while expanded**.

### 5B. Collapse

- **Trigger:** ESC, click-away (`NotchHover.isOutside`), or hotkey toggle.
- **Animation:** `Motion.collapse` — `spring(response: 0.30, dampingFraction: 0.90)` — zero bounce, retract into notch.
- **State reset:** query field may retain text; transient answer state clears on next `.routed`.

### 5C. Phase morph (input → searching → answering)

- **Animation:** `Motion.grow` — `spring(response: 0.32, dampingFraction: 0.88)`.
- **Width locked** at 520pt — vertical grow only.
- **Searching:** spinner only in tray; no cycling status text in the notch collar (reasoning events exist for `mnemoctl` but are not rendered in the collar).

### 5D. Status cross-fade

- **Animation:** `Motion.dissolve` — `easeInOut(0.20s)` for status label changes.
- **Block reveal:** `Motion.reveal` — `easeOut(0.22s)` for answer blocks.
- **Stagger:** `Motion.stagger` = 0.06s between sibling block entrances.

### 5E. Glyph morph (mic ↔ send)

- **Animation:** `Motion.glyph` — `spring(response: 0.25, dampingFraction: 0.80)`.

### 5F. Mouse-out collapse

Pure geometry: `NotchHover.isOutside(cursor:hotRect:)` — cursor fully outside combined hot rect (notch + expanded surface + grace margin) → collapse.

---

## 6. Blur-morph transition

Signature content swap (`Motion.blurMorph`):

| Phase | Blur | Scale | Opacity |
|-------|------|-------|---------|
| Outgoing removal | 0 → 6pt | 1.0 → 0.988 | 1 → 0 |
| Incoming insertion | 8 → 0pt (starts 5) | 1.03 → 1.0 (starts 1.012) | 0 → 1 |

**Reduce Motion:** `.opacity` only — no blur, no scale.

**Liquid Glass morph:** single `glassEffectID` within one `GlassEffectContainer` ties notch collar → input tray → answer body. `AT-M12.4` (manual).

---

## 7. Motion system — curves, springs, choreography

Centralized in `Motion` enum. **Do not scatter magic numbers in views.**

| Token | SwiftUI `Animation` | Use |
|-------|---------------------|-----|
| `summon` | `spring(0.36, 0.84)` | idle → expanded |
| `grow` | `spring(0.32, 0.88)` | phase morphs, streaming body growth |
| `collapse` | `spring(0.30, 0.90)` | retract into notch |
| `glyph` | `spring(0.25, 0.80)` | mic ↔ send |
| `dissolve` | `easeInOut(0.20)` | status cross-fade |
| `reveal` | `easeOut(0.22)` | block fade-in |
| `stagger` | 0.06s | sibling delay |

```swift
// Sources/MnemoApp/Motion.swift — canonical values
static let summon   = Animation.spring(response: 0.36, dampingFraction: 0.84)
static let grow     = Animation.spring(response: 0.32, dampingFraction: 0.88)
static let collapse = Animation.spring(response: 0.30, dampingFraction: 0.90)
static let glyph    = Animation.spring(response: 0.25, dampingFraction: 0.80)
```

**Test enforcement:** `ProductDocTests.testMotionTokensMatchUIContract`.

---

## 8. Color, type, and accessibility

| Element | Spec |
|---------|------|
| Body | Pure `#000` — continues hardware notch |
| Answer text | 17pt, white, markdown-rendered |
| Unsupported sentences (M5) | Orange + underline (`AT-M12.5`) |
| Source cards | Title, path, relevance bar, relative time |
| Confidence framing | Prefix above answer when grounded (`ExpressivenessTests`) |
| Increase Contrast | System setting honored via semantic colors |
| VoiceOver | Every control and terminal state has accessibility label from `NotchReducer.message` |
| Reduce Motion | All springs → 0.20s opacity cross-fade |

---

## 9. Terminal state copy (never blank)

Enforced by `TerminalStateRenderTests` (`AT-M12.7`):

| `TerminalState` | User-visible message | Recovery |
|-----------------|---------------------|----------|
| `.indexing(path)` | "Still indexing {filename} — ask again in a moment." | Wait & retry |
| `.empty(nearest:)` | "Nothing in your files matches that closely. Try broadening the question." | Broaden |
| `.emptyCorpus` | "No files yet. Drop documents into ~/Mnemo/memory to start — PDFs, notes, images, audio all work." | Add files |
| `.modelNotLoaded(model)` | "The model {model} isn't loaded. Load it to continue." | Load model |
| `.engineUnreachable` | "The memory engine isn't responding. Restart it to continue." | Restart engine |
| `.unsupportedAnswer` | "I couldn't ground an answer in your files, so I won't guess." | Broaden |

Full refusal-copy spec: `docs/product/helpfulness-refusal-copy.md`.

---

## 10. Source cards & answer layout

- **Order:** source cards render **before** first answer token (`AT-M1.4`, `QueryLifecycleTests`).
- **Click:** reveals file in Finder (`AT-M1.2`, `AT-M12.6`).
- **Citation markers:** `[Title]` in answer text; unsupported sentences flagged per-sentence (`AT-M5.2`).
- **Follow-ups:** suggestion chips below answer; cleared on next `.routed` (`ExpressiveReducerTests`).

---

## 11. Fidelity checklist

Acceptance bar for any UI change. All items must pass before claiming M12 done.

- [ ] **F1** — Idle surface is pure black, blends with hardware notch (`final-idle.png` reference).
- [ ] **F2** — Expanded width locked at 520pt; no horizontal jump between phases.
- [ ] **F3** — Top edge flush with screen top on all displays (no mid-screen dangling collar).
- [ ] **F4** — Summon < 200ms; typing works without prior click (`AT-M12.2`).
- [ ] **F5** — One `GlassEffectContainer`; shared `glassEffectID` morph (`AT-M12.4`).
- [ ] **F6** — Searching shows spinner only — no status text in notch collar.
- [ ] **F7** — Answer renders below notch; markdown + orange unsupported spans (`AT-M12.5`).
- [ ] **F8** — Voice drop is narrow pendant; orb centered; bright band below notch bottom (`OrbUniforms.maxFill`).
- [ ] **F9** — Reduce Motion → opacity only, no blur/scale springs.
- [ ] **F10** — Every `TerminalState` renders non-empty copy (`AT-M12.7`).
- [ ] **F11** — Privacy indicator visible when `show_egress_indicator = true` (`docs/product/privacy-indicator.md`).
- [ ] **F12** — Virtual notch on external displays (`AT-M12.3`).

---

## 12. Voice dictation — the listening orb

### 12.1 Interaction

- **Press-and-hold** mic glyph in input tray → voice drop pendant animates down (`Motion.grow`).
- **Release** → transcription inserted into field; optional auto-submit.
- **On-device only:** `SpeechAnalyzer` + `SpeechTranscriber`; `requiresOnDeviceRecognition = true`.
- **Network off:** dictation must work with Wi-Fi disabled (`AT-M12.10` manual).

### 12.2 Mic envelope

`MicEnvelope` (`Sources/MnemoOrchestrator/VoiceOrb.swift`):

| Parameter | Value | Role |
|-----------|-------|------|
| `attack` | 0.6 | Fast attack — responsive to speech onset |
| `release` | 0.12 | Slow release — no strobe on silence |
| dB floor | -60dB → 0 | RMS normalization |
| dB ceiling | 0dB → 1 | Full scale |

Tested: `MicEnvelopeTests.testEnvelopeFollowerFastAttackSlowRelease`.

### 12.3 Metal shader orb

- **Implementation:** `VoiceOrb.metal` + SwiftUI `ShaderLibrary` + `TimelineView(.animation)`.
- **Target:** 120fps on ProMotion; no dropped frames.
- **Never fake with gradients** — GPU fragment shader only.

### 12.4 Orb shader uniforms (`OrbUniforms`)

Derived per frame from smoothed amplitude:

| Uniform | Formula | Range |
|---------|---------|-------|
| `maxFill` | constant | **0.80** — bright band stays below notch bottom |
| `idleFlow` | constant | **0.06** — baseline motion at silence |
| `waveHeight` | `idleFlow + amp × (maxFill - idleFlow)` | 0.06…0.80 |
| `brightness` | `0.25 + amp × 0.75` | dim → near-white-hot |
| `saturation` | `0.15 + amp × 0.85` | gray → full spectrum |
| `scale` | `1.0 + amp × 0.05` | ≤ 5% swell |

Tested: `MicEnvelopeTests.testMapsToOrbUniforms` (`AT-M12.10`).

### 12.5 Post-dictation

- Release → 6-dot spinner (`Surface.spinnerRing`) while query routes.
- Dictation errors route through `presentInfo` — always visible, not gated on answering phase.

---

## 13. Motion token quick reference

| UI moment | Token | § |
|-----------|-------|---|
| Hover open | `Motion.summon` | §5A |
| Phase grow | `Motion.grow` | §5C |
| Retract | `Motion.collapse` | §5B |
| Mic/send | `Motion.glyph` | §5E |
| Status swap | `Motion.dissolve` | §5D |
| Answer block | `Motion.reveal` + `stagger` | §5D |
| Content swap | `Motion.blurMorph` | §6 |
| Reduce Motion | `Motion.adaptive(_, true)` | §6 |

---

## 14. Test map

```bash
swift test --filter 'NotchShapeGeometryTests|NotchPanelRectTests|HoverGeometryTests|\
TerminalStateRenderTests|StateDriverTests|MicEnvelopeTests|ProductDocTests|\
Expressiveness|Helpfulness|SmarterThanSiri'
```

| UI.md section | Test target |
|---------------|-------------|
| §2 Geometry | `NotchGeometryTests`, `NotchPanelRectTests` |
| §3 Shape | `NotchShapeGeometryTests` |
| §5 Hover | `HoverGeometryTests` |
| §7 Motion tokens | `ProductDocTests` |
| §9 Terminal copy | `TerminalStateRenderTests` |
| §12 Orb | `MicEnvelopeTests` |
| §10 Expressiveness | `ExpressivenessTests` |

---

*Last verified: 2026-07-09. Reference captures: `docs/superpowers/specs/2026-07-09-notch-redesign-verification.md`.*
