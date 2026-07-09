# beats-siri.mov — storyboard & capture plan

Target file: `Tests/Fixtures/demos/beats-siri.mov`  
Script: `docs/product/bs-m12-demo-script.md`  
Headless transcript: `scripts/m12-acceptance.md`

## Capture requirements

- Mac with physical or virtual notch + **attached display**
- Wi-Fi **off** (strict) or egress monitor visible in frame
- `Mnemo.app` built via `scripts/build-app.sh`
- M0 stack running; Aurora timeline fixture ingested
- QuickTime Screen Recording or `screencapture` sequence stitched

## Frame list

| Frame | Time | Visual | Audio/narration (optional) |
|-------|------|--------|---------------------------|
| F01 | 0:00 | Desktop idle; menu bar `◗` visible | "Mnemo lives in the notch." |
| F02 | 0:02 | Cursor enters notch hover zone | — |
| F03 | 0:03 | Surface expands; glass tray; input focused | "No click required." |
| F04 | 0:05 | Typing synthesis question | — |
| F05 | 0:08 | Searching: spinner only in tray | "On-device retrieval." |
| F06 | 0:12 | Source cards appear | "Citations first." |
| F07 | 0:15 | Answer streams; markdown; green privacy dot | "Grounded synthesis." |
| F08 | 0:22 | Orange underline on any unsupported span (if triggered in test) | "Verified — or flagged." |
| F09 | 0:28 | Click source card | — |
| F10 | 0:30 | Finder reveals source file | "Real files." |
| F11 | 0:35 | Inspector opens; Bazel fact chip | "Your memory — readable." |
| F12 | 0:42 | Delete chip animation | — |
| F13 | 0:48 | Re-type same question | — |
| F14 | 0:55 | Refusal: no longer mentions Bazel | "It forgot." |
| F15 | 1:00 | Hold on privacy indicator: clean / 0 egress | "Beats Siri offline." |
| F16 | 1:05 | ESC collapse to idle notch | End card |

## Alternate cross-doc frame (Aurora)

Replace F04–F07 with: *"How many weeks did the Aurora migration slip?"* — answer cites ≥3 docs; `SmarterThanSiriTests` B53.

## Egress overlay (optional)

Picture-in-picture terminal running:

```bash
watch -n0.5 'lsof -i -nP | grep -iE MnemoApp | grep -v 127.0.0.1 | wc -l'
```

Must show `0` entire recording.

## Reduce Motion variant

Separate capture with Reduce Motion on → opacity cross-fades only (UI.md §6). File: `beats-siri-reduce-motion.mov` (optional).

## Acceptance

- [ ] All F01–F16 captured
- [ ] Privacy indicator visible F07–F15
- [ ] No frame shows blank terminal state
- [ ] Duration 60–90s
- [ ] Exported H.264; max 1920×1080

## Headless fallback

When no display (CI/cloud): storyboard + `scripts/m12-acceptance.md` transcript satisfy BS-M12 logic gate; `.mov` marked `CAPTURE_PENDING` until Mac capture.

**Test enforcement:** `ProductDocTests`; `swift test --filter SmarterThanSiri`.
