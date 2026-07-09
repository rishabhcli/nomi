#!/usr/bin/env bash
# Phase 2 quality gate — fails on stub tests or batch automation patterns.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== phase2-reject ==="
if rg 'XCTAssertTrue\(true' Tests/ 2>/dev/null; then
  echo "REJECT: stub tests (XCTAssertTrue(true))"
  exit 1
fi
if rg -l 'execute-agent-|process-agent-a' scripts/ 2>/dev/null; then
  echo "REJECT: batch queue automation scripts"
  exit 1
fi
echo "PASS: phase2-reject"
