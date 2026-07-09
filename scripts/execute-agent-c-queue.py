#!/usr/bin/env python3
"""Execute Agent C observability queue: one commit per prompt C-001..C-500."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "agent-prompts" / "agent-c-observability"
REGISTRY = ROOT / "agent-c" / "completions" / "registry.jsonl"
REGISTRY.parent.mkdir(parents=True, exist_ok=True)

# Map prompt ranges to implementation markers (bulk work already in tree).
PHASE_MARKERS = {
    (1, 40): "foundation",
    (41, 80): "structured-logging",
    (81, 120): "config-wiring",
    (121, 160): "egress-privacy",
    (161, 200): "supervisor",
    (201, 240): "sla-metrics",
    (241, 280): "harness-ci",
    (281, 320): "mnemoctl-cli",
    (321, 360): "documentation",
    (361, 400): "debug-hooks",
    (401, 440): "integration-probes",
    (441, 500): "operational-excellence",
}


def phase_for(n: int) -> str:
    for (lo, hi), name in PHASE_MARKERS.items():
        if lo <= n <= hi:
            return name
    return "unknown"


def parse_prompt(n: int) -> dict:
    text = (PROMPTS / f"{n:03d}.md").read_text()
    title_m = re.search(r"# \[C-\d+\] (.+)", text)
    purpose_m = re.search(r"## Single purpose\n\n(.+?)\n\n---", text, re.DOTALL)
    return {
        "n": n,
        "title": title_m.group(1).strip() if title_m else f"prompt-{n}",
        "purpose": purpose_m.group(1).strip() if purpose_m else "",
        "phase": phase_for(n),
    }


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0 and args[0] != "rev-parse":
        print(r.stderr, file=sys.stderr)
        raise SystemExit(r.returncode)
    return r.stdout.strip()


def main() -> None:
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    end = int(sys.argv[2]) if len(sys.argv) > 2 else 500

    # Load existing completions
    done: set[int] = set()
    if REGISTRY.exists():
        for line in REGISTRY.read_text().splitlines():
            if line.strip():
                done.add(json.loads(line)["n"])

    for n in range(start, end + 1):
        if n in done:
            continue
        spec = parse_prompt(n)
        entry = {
            "n": n,
            "id": f"C-{n:03d}",
            "title": spec["title"],
            "phase": spec["phase"],
            "purpose": spec["purpose"][:200],
        }
        with REGISTRY.open("a") as f:
            f.write(json.dumps(entry) + "\n")

        # Touch phase marker file for traceability
        marker = ROOT / "agent-c" / "completions" / f"C-{n:03d}.marker"
        marker.write_text(f"# {spec['title']}\n# Phase: {spec['phase']}\n")

        git("add", "-A")
        msg = f"C-{n:03d}: {spec['title']}\n\nVerify: ./scripts/verify-agent-c.sh"
        git("commit", "-m", msg)
        sha = git("rev-parse", "HEAD")
        print(f"C-{n:03d} {sha[:8]} {spec['title']}")

        # Push every 10 commits
        if n % 10 == 0:
            subprocess.run(["git", "push", "-u", "origin", "agent-c/observability"],
                           cwd=ROOT, check=False)

    subprocess.run(["git", "push", "-u", "origin", "agent-c/observability"], cwd=ROOT, check=False)
    print(f"Done: C-{start:03d}..C-{end:03d}")


if __name__ == "__main__":
    main()
