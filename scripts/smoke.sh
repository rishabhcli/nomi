#!/usr/bin/env bash
# M0 integration smoke: stack up, loopback-only, healthy. Run with real binaries installed.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}

swift build

# AT-M0.1: start stack (idempotent), prove health
.build/debug/mnemoctl start

# AT-M0.2: loopback-only audit
.build/debug/mnemoctl audit

echo "--- lsof (mnemo-owned listeners) ---"
lsof -iTCP -sTCP:LISTEN -n -P | grep -E '6767|11434' || true

.build/debug/mnemoctl health
echo "SMOKE OK"
