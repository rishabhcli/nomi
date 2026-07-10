#!/usr/bin/env bash
# Phase 2 quality gate — fails on stub tests or batch automation patterns.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== phase2-reject ==="
if rg 'XCTAssertTrue\(true' Tests/ 2>/dev/null; then
  echo "REJECT: stub tests (XCTAssertTrue(true))"
  exit 1
fi
if compgen -G "scripts/execute-agent-*.py" >/dev/null 2>&1; then
  echo "REJECT: batch queue automation scripts (execute-agent-*.py)"
  exit 1
fi
if compgen -G "scripts/process-agent-a*.py" >/dev/null 2>&1; then
  echo "REJECT: batch queue automation scripts (process-agent-a*.py)"
  exit 1
fi
echo "PASS: phase2-reject"
