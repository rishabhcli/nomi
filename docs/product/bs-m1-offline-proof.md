# BS-M1 offline proof

**Gate:** cited answer with network physically off (or egress measured zero).

## Preconditions

- M0 stack running: `mnemoctl start`
- Fixture: `~/Mnemo/memory/fixture.md` contains Bazel adoption fact
- Wi-Fi off + Ethernet unplugged **or** egress monitor (see below)

## Proof steps

| Step | Action | Pass criterion | AT-M |
|------|--------|----------------|------|
| 1 | `mnemoctl ask "What is my favorite build tool?"` | `[answer]` contains "Bazel" | AT-M1.1 |
| 2 | Observe event order | `[sources]` before `[answer]` | AT-M1.4 |
| 3 | `mnemoctl ask "What is my dog's name?"` | States corpus lacks it; no invention | AT-M1.3 |
| 4 | UI: click source card | Finder reveals `fixture.md` | AT-M1.2 |
| 5 | Egress monitor during step 1 | Zero non-loopback connections | BS-M1 |

## Egress monitor

```bash
(for i in $(seq 1 60); do
   lsof -i -nP | grep -i -E 'mnemoctl|MnemoApp|ollama|supermemo|smfs' \
     | grep -v -E '127\.0\.0\.1|\[::1\]|LISTEN'
   sleep 0.5
 done) & mnemoctl ask "What is my favorite build tool?"; wait
# expect: no output lines
```

## Captured evidence (2026-07-08)

```
$ mnemoctl ask "What is my favorite build tool?"
[route] synthesis
[sources] Build tooling notes </Users/m3-max/Mnemo/memory/fixture.md>
[answer] Your favorite build tool is **Bazel** [Build tooling notes].
[done]
=== non-loopback connections during query ===
=== end (empty = zero egress) ===
```

## Test enforcement

- `QueryServiceTests` — event order, grounding
- `InvariantTests` — loopback config
- `EgressGuardTests` — AT-M10.3
- `ProductDocTests` — PLAN.md references BS-M1

## Recording

Target: `Tests/Fixtures/demos/m1-offline.mov` (requires Mac with display).
