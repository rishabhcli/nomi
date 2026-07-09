# Notch redesign — verification evidence (2026-07-09)

Captured from the running app (`.build/Mnemo.app`, built with the Xcode-beta
toolchain). Screens were driven headlessly via the `ai.mnemo.debug.*` hooks and
captured with `screencapture`.

## Bugs fixed (root-caused, not guessed)

| Bug | Root cause (evidence) | Fix | Verified |
|---|---|---|---|
| Voice force-quits | Crash report `MnemoApp-2026-07-09-131541.ips`: `EXC_BREAKPOINT` in `Dictation.start()`'s `SFSpeechRecognizer.requestAuthorization` callback → `swift_task_isCurrentExecutor` → `dispatch_assert_queue` fail. The @MainActor closure ran on TCC's background queue. | Rewrote dictation on the macOS 26 **SpeechAnalyzer + SpeechTranscriber** (on-device); all Speech callbacks are `@Sendable` + main-actor hops; permission via `withCheckedContinuation`; session-guarded start/stop lifecycle. | Drove dictate + stop → **no new crash report**; app stays alive. |
| Glitchy open | The surface animated as disjoint pieces (black body grew while a separate glass band opacity-faded in, with a transparent gap between). | One cohesive object: opaque-black body + dark glass tray, single `SurfaceGeometry` value on one spring, no nested animation, no desktop gap. | Mid-open stills show one object growing. |
| Steps in the notch | Searching pill rendered cycling status text. | Spinner-only while searching; reasoning/understanding/related/etc. stay in state for `mnemoctl`, unrendered. | `r5-searching.png`: spinner, no text. |
| Not black | Glass tray was too light + a black→clear fade showed the desktop. | Pure `#000` body; only the bottom tray is dark translucent Liquid Glass (samples desktop). | `final-idle.png` (pure black), `final-answer2.png`. |
| (regression I introduced) transcript lost during dictation | Gating the tray on `!listening` unmounted the transcript→query bridge. | Moved the bridge + a tap-to-submit onto the always-mounted surface. | Compiles; reviewed. |
| Dictation errors silent | `problem` only rendered in the answering phase; the input/drop states have no body. | Route `dictation.problem` through `presentInfo` so it's always visible. | Reviewed. |

## Reference match (states captured)

- **Idle** — pure-black notch, blends with hardware. (`final-idle.png`)
- **Input** — dark Liquid-Glass tray, `+` / "Ask Mnemo" / mic, home-indicator pill, large rounded bottom corners.
- **Searching** — spinner only.
- **Answer** — black body, white text, "Riddleness" chip, outline thumbs, glass tray. (`final-answer2.png`)
- **Voice drop** — narrow pendant from the notch (notch-width, not widened), semicircle bottom, reactive Metal orb inside. (`r6-drop.png`)

## Invariants (loopback / 0-egress)

```
LISTEN:  ollama 127.0.0.1:11434 · supermemory 127.0.0.1:6767   (loopback only)
MnemoApp connections:  127.0.0.1:<port> -> 127.0.0.1:6767      (loopback only; 0 non-loopback)
```

## Code review

Four review agents (three on the original diff, one on the SpeechAnalyzer
rewrite). All confirmed correctness bugs fixed:
- Concurrency: crash fix sound; the SpeechAnalyzer lifecycle hardened against
  stop()-during-await (no live-mic-after-release), superseded-task clobber,
  converter-nil silent failure, and orb amplitude persisting after stop.
- Layout: no black/tray gap, no answerHeight feedback loop, no NaN.
- Conventions: no hardcoded hosts/ports/model-ids; no new egress; files < 400 lines.

## Packaging & permissions

Packaged as a real `Mnemo.app` (`ai.mnemo.app`) via `scripts/build-app.sh` so
macOS TCC attributes mic/speech to **Mnemo** (a bare binary is attributed to the
launching terminal, so the grant never sticks). Confirmed the permission prompt
now reads **"Allow 'Mnemo' … speech recognition"** with the on-device usage
string. Granting is the user's one click (macOS forbids any process granting
itself the permission) — launch `Mnemo.app` from Finder, or toggle Mnemo on in
System Settings → Privacy & Security → Speech Recognition + Microphone.

## Build

`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build`
(plain Command Line Tools cannot compile `VoiceOrb.metal` — the Metal compiler
ships only with full Xcode). `.app`: `bash scripts/build-app.sh`.
