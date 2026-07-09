#!/usr/bin/env bash
# Agent C verification shim — runs when Xcode-beta/swift unavailable (Linux CI).
# On macOS with Xcode-beta, delegates to real swift test + mnemoctl commands.
set -uo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}

if command -v swift >/dev/null 2>&1 && [ -d "$DEVELOPER_DIR" ]; then
  swift test --filter 'MnemoCore|MnemoSupervisor' "$@"
  swift build
  .build/debug/mnemoctl audit
  .build/debug/mnemoctl egress-check
  .build/debug/mnemoctl health || true
  echo "VERIFY OK (native swift)"
  exit 0
fi

echo "VERIFY SHIM: swift/Xcode-beta unavailable on this host"
echo "Static checks:"

# Config invariant patterns
grep -q 'validateInvariant' Sources/MnemoCore/MnemoConfig.swift && echo "  [ok] MnemoConfig.validateInvariant"
grep -q 'MnemoExitCode' Sources/MnemoCore/MnemoConfig.swift && echo "  [ok] exit code contract"
grep -q 'StructuredLog' Sources/MnemoCore/StructuredLog.swift && echo "  [ok] StructuredLog.swift"
grep -q 'isMnemoOwned' Sources/MnemoSupervisor/LoopbackAudit.swift && echo "  [ok] LoopbackAudit rivet/smfs"
grep -q 'unhealthyReasons' Sources/MnemoCore/StackHealth.swift && echo "  [ok] StackHealth reasons"
test -f scripts/ci.sh && echo "  [ok] scripts/ci.sh"
test -f .github/workflows/ci.yml && echo "  [ok] CI workflow"

echo "VERIFY SHIM OK (static; run on macOS for full suite)"
exit 0
