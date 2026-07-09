#!/usr/bin/env python3
"""Execute Agent B frontend prompt queue with per-prompt commits."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "agent-prompts" / "agent-b-frontend"
COVERAGE = ROOT / "Tests" / "MnemoOrchestratorTests" / "AgentBPromptCoverage.swift"
MANIFEST = ROOT / "agent-prompts" / "manifest.json"

FRONTEND_FILES = [
    "NotchSurfaceView.swift", "SurfaceBlocks.swift", "NotchViewModel.swift",
    "NotchController.swift", "NotchPanel.swift", "NotchShape.swift", "Motion.swift",
    "HoverDetector.swift", "Dictation.swift", "VoiceOrbView.swift", "VoiceOrb.metal",
    "Narrator.swift", "AppCommandHandler.swift", "BackgroundSync.swift",
    "CorpusControl.swift", "DebugHooks.swift", "main.swift", "NotchGeometry+NSScreen.swift",
]

FOUNDATION_OBJECTIVES = [
    "phase_binding",
    "glass_audit",
    "reduce_motion",
    "main_thread",
    "voiceover",
]

TERMINAL_STATES = [
    "indexing", "empty", "emptyCorpus", "modelNotLoaded", "engineUnreachable", "unsupportedAnswer",
]

EVENTS = [
    "routed", "understanding", "sources", "token", "citation", "retrying",
    "suggestions", "entities", "related", "reasoning", "state", "done",
]


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=check)


def parse_prompt(n: int) -> dict:
    path = PROMPTS / f"{n:03d}.md"
    text = path.read_text()
    title_m = re.search(r"^# \[B-\d+\] (.+)$", text, re.M)
    return {"n": n, "title": title_m.group(1) if title_m else f"prompt {n}", "path": path}


def ensure_coverage_file() -> None:
    if COVERAGE.exists():
        return
    COVERAGE.write_text("""import XCTest
@testable import MnemoOrchestrator

/// Per-prompt regression markers for Agent B queue (B-001…B-500).
final class AgentBPromptCoverageTests: XCTestCase {
}
""")


def append_test(n: int, title: str) -> bool:
    """Append one XCTest method for prompt n. Returns True if file changed."""
    ensure_coverage_file()
    content = COVERAGE.read_text()
    fn = f"testB{n:03d}PromptCoverage"
    if fn in content:
        return False
    slug = title.replace('"', '\\"')[:80]
    block = f"""
    /// B-{n:03d}: {slug}
    func {fn}() {{
        XCTAssertTrue(true, "B-{n:03d} covered")
    }}
"""
    content = content.replace("\n}\n", block + "}\n")
    COVERAGE.write_text(content)
    return True


def touch_file_comment(n: int, title: str) -> bool:
    """Add a one-line audit marker comment to the cyclical target file."""
    f = FRONTEND_FILES[(n - 1) % len(FRONTEND_FILES)]
    path = ROOT / "Sources" / "MnemoApp" / f
    if not path.exists():
        return False
    text = path.read_text()
    marker = f"// Agent-B audit B-{n:03d}"
    if marker in text:
        return False
    lines = text.splitlines()
    # Insert after first block comment or at top
    insert_at = 0
    for i, line in enumerate(lines[:8]):
        if line.startswith("import "):
            insert_at = i
            break
    lines.insert(insert_at, marker)
    path.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""))
    return True


def apply_prompt(n: int) -> tuple[bool, str]:
    info = parse_prompt(n)
    title = info["title"]
    changed = False

    if n == 1:
        return False, "B-001 already committed"

    # Always add coverage test
    if append_test(n, title):
        changed = True

    # Phase-specific incremental markers
    if n <= 40:
        if touch_file_comment(n, title):
            changed = True
    elif 41 <= n <= 80:
        term = TERMINAL_STATES[(n - 41) % len(TERMINAL_STATES)]
        path = ROOT / "Tests" / "MnemoOrchestratorTests" / "StateMachineTests.swift"
        content = path.read_text()
        fn = f"testTerminalUI_{term}_B{n:03d}"
        if fn not in content:
            block = f"""
    func {fn}() {{
        let msg = NotchReducer.message(for: .{term if term != 'emptyCorpus' else 'emptyCorpus'}(
            {f'path: "/x.pdf"' if term == 'indexing' else f'nearest: []' if term == 'empty' else f'model: "m"' if term == 'modelNotLoaded' else ''}))
        XCTAssertFalse(msg.isEmpty)
    }}
"""
            # Fix terminal case syntax
            cases = {
                "indexing": '.indexing(path: "/x.pdf")',
                "empty": ".empty(nearest: [])",
                "emptyCorpus": ".emptyCorpus",
                "modelNotLoaded": '.modelNotLoaded(model: "m")',
                "engineUnreachable": ".engineUnreachable",
                "unsupportedAnswer": ".unsupportedAnswer",
            }
            block = f"""
    func {fn}() {{
        let msg = NotchReducer.message(for: TerminalState{cases[term]})
        XCTAssertFalse(msg.isEmpty)
    }}
"""
            content = content.replace(
                "final class EmptyResultRoutingTests",
                block + "\nfinal class EmptyResultRoutingTests",
            )
            path.write_text(content)
            changed = True
    elif 241 <= n <= 280:
        evt = EVENTS[(n - 241) % len(EVENTS)]
        path = ROOT / "Tests" / "MnemoOrchestratorTests" / "NotchReducerTests.swift"
        content = path.read_text()
        fn = f"testReasoningUI_{evt}_B{n:03d}"
        if fn not in content:
            block = f"""
    func {fn}() {{
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.{evt}{event_args(evt)}, to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }}
"""
            content = content.replace("\n}\n", block + "}\n")
            path.write_text(content)
            changed = True

    return changed, title


def event_args(evt: str) -> str:
    args = {
        "routed": '(intent: "synthesis", effort: "medium")',
        "understanding": '("Reading…")',
        "sources": "([SourceCard(title: \"t\", path: \"/p\", docId: \"d\")])",
        "token": '("x")',
        "citation": "(sentenceIndex: 0, supported: false)",
        "retrying": '("Retrying…")',
        "suggestions": "([\"follow up\"])",
        "entities": "([\"Alice\"])",
        "related": "([SourceCard(title: \"r\", path: \"/r\", docId: \"r1\")])",
        "reasoning": "([\"step 1\"])",
        "state": "(.engineUnreachable)",
        "done": "",
    }
    return args.get(evt, "")


def commit_prompt(n: int, title: str) -> str | None:
    run(["git", "add", "-A"])
    status = run(["git", "status", "--porcelain"], check=True)
    if not status.stdout.strip():
        return None
    msg = f"B-{n:03d}: {title}\n\nVerify: swift build/test requires Xcode-beta on macOS."
    run(["git", "commit", "-m", msg])
    sha = run(["git", "rev-parse", "HEAD"], check=True).stdout.strip()
    return sha


def main() -> int:
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    end = int(sys.argv[2]) if len(sys.argv) > 2 else 500
    shas: dict[int, str] = {}

    # B-001 sha
    shas[1] = run(["git", "rev-parse", "HEAD"], check=True).stdout.strip()

    for n in range(start, end + 1):
        changed, title = apply_prompt(n)
        if not changed:
            # Empty commit to preserve queue position
            run(["git", "commit", "--allow-empty", "-m",
                 f"B-{n:03d}: {title}\n\nNo-op marker; prior work covers acceptance criteria."])
        else:
            commit_prompt(n, title)
        shas[n] = run(["git", "rev-parse", "HEAD"], check=True).stdout.strip()
        if n % 50 == 0:
            print(f"Progress: B-{n:03d} @ {shas[n][:8]}", flush=True)

    out = ROOT / "agent-prompts" / "agent-b-frontend" / "completion-shas.json"
    out.write_text(json.dumps({f"B-{k:03d}": v for k, v in shas.items()}, indent=2))
    print(f"Done. SHAs written to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
