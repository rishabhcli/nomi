# M1 acceptance — ask → cited answer (thin vertical slice)

Run with the M0 stack up (`mnemoctl start` or launchd). The full BS-M1 pass
requires networking physically off; when that isn't possible (e.g. the machine
must stay online), substitute the egress monitor in step 6 — the invariant is
proven by measurement either way.

## Headless (scriptable, no UI)

1. Fixture in the corpus: `~/Mnemo/memory/fixture.md` contains
   "My favorite build tool is Bazel and I switched to it in March 2025."
2. `mnemoctl ask "What is my favorite build tool?"`
   - **AT-M1.1** — `[answer]` contains "Bazel".
   - **AT-M1.4** — the `[sources]` line prints **before** `[answer]` (event
     order is also asserted hermetically in `QueryServiceTests`).
3. `mnemoctl ask "What is my dog's name?"` (not in corpus)
   - **AT-M1.3** — answer states the corpus lacks it; nothing invented.

## UI (manual)

4. `swift run MnemoApp`, click the menu-bar `◗`.
   - Panel appears below the notch, input focused; typing works immediately.
   - Ask the fixture question → answer streams, source card appears first.
   - **AT-M1.2** — clicking the source card reveals `fixture.md` in Finder
     (path mapping unit-tested in `testSourceCardsCarryAbsoluteMountPaths`).
5. Record the offline demo to `Tests/Fixtures/demos/m1-offline.mov`.

## Egress proof (BS-M1)

6. Either: turn Wi-Fi off + unplug Ethernet and repeat step 2 (strict BS-M1),
   or run the monitor during a query and require **zero** rows:

```bash
(for i in $(seq 1 60); do
   lsof -i -nP | grep -i -E 'mnemoctl|MnemoApp|ollama|supermemo|smfs' \
     | grep -v -E '127\.0\.0\.1|\[::1\]|LISTEN'
   sleep 0.5
 done) & mnemoctl ask "What is my favorite build tool?"; wait
# expect: no non-loopback lines printed
```

## Captured evidence (2026-07-08, Wi-Fi ON by user request, zero egress measured)

```
$ .build/debug/mnemoctl ask "What is my favorite build tool?"
[route] synthesis
[sources] Build tooling notes </Users/m3-max/Mnemo/memory/fixture.md>
[answer] Your favorite build tool is **Bazel** [Build tooling notes].
[done]
=== non-loopback connections during query ===
=== end (empty = zero egress) ===

$ .build/debug/mnemoctl ask "What is my dog's name?"
[route] synthesis
[sources] Build tooling notes </Users/m3-max/Mnemo/memory/fixture.md>
[answer] I'm sorry, but the provided notes don't contain any information about your dog's name.
[done]
```
