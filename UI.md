# UI.md — Mnemo notch surface specification

This document is the acceptance bar for the Liquid Glass notch experience on **macOS 26+**. Implementation lives in `Sources/MnemoApp/`; motion tokens in `Motion.swift`, geometry in `NotchGeometry+NSScreen.swift`, orb shader in `VoiceOrb.metal`. Tune timings against `Tests/Fixtures/reference/` recordings.

---

## 1. Product surface

Mnemo is a **non-activating `NSPanel`** anchored to notch geometry. It expands on hover, becomes key while expanded, and renders answers below the notch. The Mac notch is a **fixed hardware cutout** — never reshape it; draw a surface that **grows out from beneath it** via a concave-shouldered `NotchShape` whose black collar continues the notch.

- **Summon:** cursor to top edge (configurable `ui.notch_hover_zone_px`) or hotkey (`ui.hotkey`).
- **Typing:** immediate on expand — no click required; field is first responder.
- **Virtual notch:** on displays with `safeAreaInsets.top == 0`, draw a 200×32 pill at top-center (`NotchGeometry+NSScreen.mnemoNotchRectOrVirtual`).

---

## 2. Notch geometry (runtime)

Read from `NSScreen` at runtime — never hardcode pixel positions.

| Signal | Usage |
|--------|--------|
| `safeAreaInsets.top > 0` | Physical notch present |
| `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` | Notch width |
| `frame` | Screen bounds for panel placement |

Virtual notch fallback: `CGRect(x: midX - 100, y: maxY - 32, width: 200, height: 32)`.

---

## 3. Surface dimensions (`Surface` enum)

| Token | Value | Notes |
|-------|-------|-------|
| `inputWidth` / `readWidth` | 520pt | Single width — vertical morph only |
| `bandHeight` | 60pt | Controls row inside tray |
| `bandFade` | 34pt | Black body → glass tray blend |
| `trayHandle` | 20pt | Home-indicator zone |
| `trayHeight` | bandFade + bandHeight + trayHandle | Full glass tray |
| `answerCap` | 400pt | Answer zone scroll threshold |
| `answerFont` | 17pt | Primary answer typography |
| `bottomRadius` | 46pt | Expanded bottom corners (top = 0) |
| `idleRadius` | 9pt | Collapsed hardware-like rounding |
| `maxBodyHeight` | 560pt | Panel sizing bound |
| `dropWidth` | 176pt | Dictation pendant width |
| `dropBody` | 188pt | Pendant length below notch |
| `orbDiameter` | 120pt | Listening orb (view uses 132pt frame) |
| `homeIndicatorW` × `homeIndicatorH` | 40 × 5pt | Tray bottom pill |
| `trayTint` | 0.74 | Dark glass opacity |
| `shadowBleed` | 60pt | Panel margin |
| `shadowRadius` | 32pt | Drop shadow |
| `shadowY` | 11pt | Shadow offset |
| `shadowOpacity` | 0.36 | |
| `spinnerRing` | 18pt | Searching ring |
| `spinnerDot` | 2.5pt | Ring dot |
| `spinnerRPS` | 1.0 | Revolutions per second |

**Material rule:** one cohesive object — pure-black body (blends with hardware notch) + translucent Liquid Glass tray. Use real `glassEffect(_:in:)` inside a single `GlassEffectContainer`. Glass cannot sample glass.

---

## 4. Liquid Glass

- Deployment target: **macOS 26.0** (`Package.swift`).
- APIs: `glassEffect(_:in:)`, `GlassEffectContainer`, `glassEffectID` + `@Namespace` for notch → answer morph.
- Buttons: `.buttonStyle(.glass)` / `.glassProminent`.
- Variant from config: `ui.glass` = `regular` | `clear`.
- **Forbidden:** hand-rolled blur/vibrancy stacks.

---

## 5. Panel behavior

- **Level:** `ui.panel_level` (`floating` default).
- **Non-activating** when collapsed; **key window** when expanded.
- **Reduce Motion:** follow `ui.reduce_motion` = `system` — honor `accessibilityReduceMotion`.
- **Increase Contrast:** increase text contrast on glass; preserve hierarchy.

---

## 6. Blur-morph transition

Signature content cross-fade (`Motion.blurMorph`):

| Phase | Blur | Scale | Opacity |
|-------|------|-------|---------|
| Outgoing removal | 0 → 6 | 1 → 0.988 | 1 → 0 |
| Incoming insertion | 8 → 0 | 1.012 → 1 | 0 → 1 |

Reduce Motion fallback: opacity-only cross-fade (0.20s easeInOut).

---

## 7. Motion tokens (`Motion` enum)

| Token | Animation | Use |
|-------|-----------|-----|
| `summon` | spring 0.36 / 0.84 | idle → expanded |
| `grow` | spring 0.32 / 0.88 | phase morphs, streaming growth |
| `collapse` | spring 0.30 / 0.90 | retract into notch |
| `glyph` | spring 0.25 / 0.80 | mic ↔ send morph |
| `dissolve` | easeInOut 0.20s | status cross-fade |
| `reveal` | easeOut 0.22s | block fade-in |
| `stagger` | 0.06s | list stagger delay |

`Motion.adaptive(_:reduceMotion:)` → easeInOut 0.20s when Reduce Motion on.

---

## 8. Query lifecycle UI mapping

Every `TerminalState` renders defined copy via `NotchReducer.message(for:)` — no silent empty screens.

| State | Recovery CTA |
|-------|----------------|
| `indexing` | Wait and retry |
| `empty` / `unsupportedAnswer` | Broaden search |
| `emptyCorpus` | Add files |
| `modelNotLoaded` | Load model |
| `engineUnreachable` | Restart engine |

**SLA (platform):** source cards must render before first token (`sources_render_ms` ≤ 1000ms from `mnemo.toml`). First token P95 ≤ `sla.first_token_ms` (1500ms default).

**Egress indicator:** when `privacy.show_egress_indicator`, show dot; must read **0** outbound during queries.

---

## 9. Source cards & citations

- Title, path, relevance bar (0…1), optional snippet.
- Tap opens source in Finder (`mountRoot` + engine path).
- Citation verification flags render per-sentence in reasoning trace.
- Thumbs-up strengthens cited memories (off interactive thread).

---

## 10. Reasoning trace

- Collapsible steps from `QueryEvent.reasoning`.
- Calm typography; no jitter during stream.
- Visible during synthesis and multi-hop; hidden on Reduce Motion heavy paths if motion would distract (opacity fade only).

---

## 11. Fidelity checklist

- [ ] Expand feels like single vertical grow — no horizontal width jump between input/searching/answer.
- [ ] Black collar continuous with hardware notch (or virtual pill).
- [ ] Glass tray samples desktop once; no nested glass-on-glass.
- [ ] Sources appear before answer tokens (event order AT-M1.4).
- [ ] Summon-to-type < 1 frame of unnecessary delay.
- [ ] Collapse spring: zero visible bounce at rest.
- [ ] Spinner at 1 RPS during retrieval.
- [ ] Every terminal state shows message + recovery affordance.
- [ ] VoiceOver: logical rotor order (input → status → answer → sources).
- [ ] Increase Contrast: answer text WCAG AA on glass.
- [ ] 120fps orb on ProMotion without dropped frames (profile with Instruments).

Reference: `Tests/Fixtures/reference/`, `scripts/ui-torture.sh`.

---

## 12. Voice dictation — the listening orb

### 12.1 Interaction

Press-hold notch → on-device dictation via **Speech** framework (`SpeechAnalyzer` / `DictationTranscriber`). Never cloud STT. Audio via `AVAudioEngine` — must not egress.

### 12.2 Visual

- Metal fragment shader `voiceOrb` in `VoiceOrb.metal`.
- SwiftUI: `ShaderLibrary` + `TimelineView(.animation)` at display refresh.
- CPU updates uniforms only; GPU renders meniscus wave.

### 12.3 Amplitude mapping

Louder speech → taller/brighter/more saturated band + white-hot core + chromatic fringing. Silence → thin warm seam. Fixed upper reflection arc for glass read.

| Amplitude | Band half-height | Saturation |
|-----------|------------------|------------|
| 0 | 0.05 (seam) | 0.15 |
| 1 | 0.55 (capped 0.80) | 1.0 |

Scale: `OrbUniforms.scale` + idle breathe `0.008 * sin(t * 1.3)` (disabled Reduce Motion).

### 12.4 Shader uniforms

- `time` — seconds since orb appear
- `amplitude` — smoothed mic envelope 0…1
- `hueShift` — slow spectral drift (default 0)

### 12.5 Meniscus constraints

Wave peaks bloom **downward** only — clamp so energy never reads above notch cutout.

### 12.6 Reduce Motion orb

No shader wave/hue/aberration. Calm overlay: `Circle().fill(.white.opacity(0.15 + amplitude * 0.5))`.

### 12.7 Accessibility

- Label: "Listening"
- Value: "Input level N percent"
- Dictation transcript feeds query field on release

---

## 13. Multi-display & accessibility summary

- Panel tracks screen containing pointer at summon time.
- Hotkey summon uses screen with key window or main display.
- **Keyboard-only:** full path without mouse (hotkey, tab order, escape to dismiss).
- **VoiceOver:** `Narrator` announces state transitions and terminal outcomes.

---

## 14. Debug hooks

`DebugHooks` supports headless PNG capture for CI/visual regression without manual recording. Platform scripts: `scripts/ui-torture.sh`, `scripts/analyze-frames.py`.

---

## 15. Config cross-reference (`mnemo.toml`)

| Key | UI effect |
|-----|-----------|
| `ui.notch_hover_zone_px` | Hover arm distance |
| `ui.hotkey` | Summon chord |
| `ui.glass` | Glass variant |
| `ui.panel_level` | Window level |
| `ui.reduce_motion` | Motion policy |
| `sla.sources_render_ms` | Source card deadline |
| `sla.first_token_ms` | First token deadline |
| `privacy.show_egress_indicator` | Egress dot visibility |

All values validated at startup (fail-closed). No hardcoded hosts or model IDs in UI code.
