#!/usr/bin/env bash
# M10 airplane-mode parity harness (AT-M10.4 / BS-M10).
# Runs the fixture query set and, for each, records the answer + an
# external socket measurement (lsof) proving zero non-loopback peers.
#
# Run it twice — once online, once with Wi-Fi off + Ethernet unplugged — and
# diff the two answer logs; they must match. The egress column must read 0
# in both runs (that is the whole thesis, made checkable).
set -uo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}

BUILD_DIR=${MNEMO_BUILD_DIR:-.build/airplane}
if [ ! -x "$BUILD_DIR/debug/mnemoctl" ]; then
  swift build --build-path "$BUILD_DIR" 2>/dev/null || true
fi
CTL=${MNEMO_BUILD_DIR:+$BUILD_DIR/debug/mnemoctl}
CTL=${CTL:-.build/debug/mnemoctl}
OUT=${1:-/tmp/mnemo-parity-$(date +%s).log}
QUERIES=(
  "What is my favorite build tool?"
  "When did I switch to Bazel and why?"
  "How often does the staging database password rotate?"
  "When was the Orion project kickoff moved to?"
  "What is the search latency target from the OKR review?"
  "What is my conference badge pickup code?"
)

echo "# Mnemo airplane-mode parity run — $(date)" > "$OUT"
for q in "${QUERIES[@]}"; do
  echo "## Q: $q" >> "$OUT"
  # Sample sockets during the query.
  egress_file=$(mktemp)
  ( for _ in $(seq 1 40); do
      lsof -i -nP 2>/dev/null | grep -iE 'mnemoctl|ollama|supermemo|smfs' \
        | grep -vE '127\.0\.0\.1|\[::1\]|LISTEN' >> "$egress_file"
      sleep 0.25
    done ) &
  mon=$!
  answer=$($CTL ask "$q" 2>/dev/null | sed -n 's/^\[answer\] //p')
  wait $mon
  egress=$(sort -u "$egress_file" | grep -c . || true)
  rm -f "$egress_file"
  echo "ANSWER: $answer" >> "$OUT"
  echo "EGRESS_NONLOOPBACK: $egress" >> "$OUT"
  echo >> "$OUT"
done
echo "wrote $OUT"
cat "$OUT"
