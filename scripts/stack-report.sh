#!/usr/bin/env bash
# Live stack probe — structured JSON report (offline-capable when stack down).
set -uo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}

CTL=${MNEMO_CTL:-.build/debug/mnemoctl}
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

health_out=$("$CTL" health --verbose 2>/dev/null || echo "unreachable")
audit_ok=$("$CTL" audit 2>/dev/null && echo true || echo false)
egress_out=$("$CTL" egress-check 2>/dev/null || echo "skipped")

python3 - << PY
import json, os
health = """$health_out"""
report = {
    "timestamp": "$TS",
    "audit_pass": "$audit_ok" == "true",
    "health_raw": health.strip().split("\\n"),
    "egress_check": """$egress_out""".strip().split("\\n")[:3],
    "document_error_rate": None,
    "extraction_failures": None,
    "smfs_mount": "127.0.0.1:nfs" in health,
}
print(json.dumps(report, indent=2))
PY
