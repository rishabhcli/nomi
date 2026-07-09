# M12 acceptance — notch UI, Liquid Glass, voice orb, state machine

Logic (geometry, state machine, orb math, hover, empty-result) is covered by
`swift test` (see below). The AppKit/SwiftUI/Metal rendering is verified by
running the app on a Mac **with a display** and following these steps.

## Automated (network-off, hermetic)

```
swift test --filter 'NotchShapeGeometryTests|HoverGeometryTests|TerminalStateRenderTests|\
StateDriverTests|EmptyResultRoutingTests|MicEnvelopeTests|StateMachine'
```
- AT-M12.1b — `NotchShape` concave shoulders + bottomRadius grows with body height.
- AT-M12.3 — virtual notch geometry on `safeAreaInsets.top == 0` (NotchGeometry).
- AT-M12.7 — all five terminal states reduce to a rendered, non-empty output.
- AT-M12.9 — empty-result path emits `.state(.empty(nearest:))` with matches.
- AT-M12.10 (orb) — amplitude → wave height/brightness/saturation, capped at maxFill; fast-attack/slow-release envelope.

## Manual (run on a Mac with a display, Wi-Fi OFF)

1. `swift run MnemoApp` (M0 stack up). A menu-bar `◗` appears; no dock icon.
2. **AT-M12.1** — move the cursor to the top of the screen over the notch → the
   surface grows from beneath the notch into the input in < 200ms; the app
   behind stays active (non-activating). ESC / click-away collapses it up.
3. **AT-M12.2** — on expand, type immediately with no prior click (field is
   first responder).
4. **AT-M12.4** — the surface is one `GlassEffectContainer` with a shared
   `glassEffectID` morph (notch → input → answer); Reduce Motion → cross-fade.
5. **AT-M12.5** — ask a question; markdown answer renders below the notch;
   any M5-unsupported sentence is orange/underlined.
6. **AT-M12.6** — click a source card → the file reveals in Finder.
7. **AT-M12.8** — Settings: add a path (ingest begins), pause indexing (queue
   halts), scope a folder to `work` (queries with container `work` see only it).
8. **AT-M12.10** — press the mic; with the network off, speech transcribes into
   the field (on-device `SFSpeechRecognizer`, `requiresOnDeviceRecognition`);
   the orb's wave grows/brightens with your voice; release → 6-dot spinner →
   answer. Zero audio egress.

## BS-M12 — the continuous offline demo (headless-verified 2026-07-09)

Captured via `mnemoctl` with an egress monitor (Wi-Fi left ON by user request;
proven by measurement instead of unplugging):

```
① $ mnemoctl ask --verify "Based on my notes, what's my favorite build tool and when did I adopt it?"
   [route] synthesis (effort: medium)
   [sources] Build tooling notes </Users/m3-max/Mnemo/memory/fixture.md>, …
   [answer] Your favorite build tool is **Bazel** [Build tooling notes — /fixture.md]
            and you adopted it in **March 2025** [Build tooling notes — /fixture.md].
② source is a real file: ~/Mnemo/memory/fixture.md
③ inspector shows the fact: "User's favorite build tool is Bazel."
④ $ mnemoctl inspect delete <id> "User's favorite build tool is Bazel."   → forgotten + suppressed
⑤ $ mnemoctl ask "What is my favorite build tool?"
   [answer] I don't have information on which build tool you consider your favorite.
⑥ non-loopback connections during the entire demo: 0
```

The `.mov` recording (`Tests/Fixtures/demos/beats-siri.mov`) must be captured on
a Mac with a display — this session is headless (`screencapture` returns
"could not create image from display").
