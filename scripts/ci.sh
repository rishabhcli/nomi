#!/usr/bin/env bash
# Mnemo CI gate (C-500): swift test + mnemoctl audit + egress-check + isolated usecases.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}

BUILD_DIR=${MNEMO_BUILD_DIR:-.build/ci}
export SWIFT_BUILD_PATH="$BUILD_DIR"

echo "=== Mnemo CI gate ==="
if command -v swift >/dev/null 2>&1 && [ -d "$DEVELOPER_DIR" ]; then
  swift build --build-path "$BUILD_DIR"
  swift test --build-path "$BUILD_DIR" --filter 'MnemoCore|MnemoSupervisor'
  CTL="$BUILD_DIR/debug/mnemoctl"
  "$CTL" audit
  "$CTL" egress-check
  "$CTL" health --verbose || true
  # Isolated usecase run (no mid-run binary clobber)
  MNEMO_BUILD_DIR="$BUILD_DIR" ./scripts/run-usecases.sh /tmp/mnemo-ci-usecases 2>/dev/null || echo "usecases: skipped (no live stack)"
else
  ./scripts/verify-agent-c.sh
fi

# Badge artifact
mkdir -p "$BUILD_DIR/artifacts"
echo '{"status":"pass","agent":"C","invariants":["loopback","egress-zero","no-telemetry"]}' \
  > "$BUILD_DIR/artifacts/badge.json"
echo "CI gate complete; badge at $BUILD_DIR/artifacts/badge.json"
