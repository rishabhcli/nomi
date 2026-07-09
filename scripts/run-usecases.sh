#!/bin/bash
# Strict use-case harness: runs scripts/usecases.tsv against the live local
# stack, grades each case (regex expectations, forbidden patterns, timeout),
# samples egress continuously, and writes a TSV of results + a summary.
# Usage: run-usecases.sh [results-dir] [only-id-prefix]
set -u
cd "$(dirname "$0")/.."
RUN=${1:-/tmp/usecase-run}
ONLY=${2:-}
BUILD_DIR=${MNEMO_BUILD_DIR:-.build/usecases}
if [ ! -x "$BUILD_DIR/debug/mnemoctl" ]; then
  export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}
  swift build --build-path "$BUILD_DIR" 2>/dev/null || true
fi
CTL=${MNEMO_BUILD_DIR:+$BUILD_DIR/debug/mnemoctl}
CTL=${CTL:-.build/debug/mnemoctl}
export SUPERMEMORY_API_KEY=$(cat ~/.supermemory/data/api-key)
mkdir -p "$RUN/out"
RESULTS="$RUN/results.tsv"
[ -f "$RESULTS" ] || echo -e "id\tcategory\tstatus\tlatency_s\tnote" > "$RESULTS"

# --- continuous egress sampler (non-loopback, non-listen peers of our stack)
: > "$RUN/egress-violations.txt"
( while true; do
    lsof -i -nP 2>/dev/null | grep -iE 'mnemo|ollama|supermemo' \
      | grep -vE '127\.0\.0\.1|\*:[0-9]+ \(LISTEN\)|\[::1\]' >> "$RUN/egress-violations.txt"
    sleep 5
  done ) & SAMPLER=$!
trap 'kill $SAMPLER 2>/dev/null' EXIT

now() { python3 -c 'import time; print(f"{time.time():.1f}")'; }

run_with_timeout() { # $1=seconds, rest=command...
  local secs=$1; shift
  perl -e 'alarm shift; exec @ARGV' "$secs" "$@" 2>&1
}

pass=0; fail=0
while IFS=$'\t' read -r id category type input expect forbid timeout; do
  case "$id" in \#*|"") continue;; esac
  [ -n "$ONLY" ] && case "$id" in "$ONLY"*) ;; *) continue;; esac
  # skip already-recorded cases (lets us resume/re-run selectively)
  grep -q "^$id	" "$RESULTS" && continue

  out="$RUN/out/$id.log"
  t0=$(now)
  case "$type" in
    ask)    run_with_timeout "$timeout" $CTL ask "$input" > "$out";;
    verify) run_with_timeout "$timeout" $CTL ask --verify "$input" > "$out";;
    then)   q1="${input%%||*}"; q2="${input##*||}"
            run_with_timeout "$timeout" $CTL ask "$q1" --then "$q2" > "$out";;
    cli)    run_with_timeout "$timeout" $CTL $input > "$out";;
    cache)  run_with_timeout "$timeout" $CTL ask "$input" > "$out"
            run_with_timeout "$timeout" $CTL ask "$input" >> "$out";;
    shell)  run_with_timeout "$timeout" bash -c "$input" > "$out";;
    *)      echo "unknown type $type" > "$out";;
  esac
  rc=$?
  t1=$(now)
  lat=$(python3 -c "print(f'{$t1-$t0:.1f}')")

  # Grade in python: NFKC-normalize (LLMs emit narrow no-break spaces in
  # dates), then regex with IGNORECASE+DOTALL so (?s)-style ordered
  # multi-line expectations work.
  verdict=$(python3 - "$out" "$expect" "$forbid" << 'PYEOF'
import re, sys, unicodedata
text = unicodedata.normalize("NFKC", open(sys.argv[1], errors="replace").read())
text = text.replace("\u2019", "'").replace("\u2018", "'").replace("\u201c", '"').replace("\u201d", '"')
expect, forbid = sys.argv[2], sys.argv[3]
flags = re.IGNORECASE | re.DOTALL
if expect != "-" and not re.search(expect, text, flags):
    print("MISS"); sys.exit()
if forbid != "-":
    m = re.search(forbid, text, flags)
    if m: print("FORBID:" + m.group(0)[:50].replace("\t", " ").replace("\n", " ")); sys.exit()
print("OK")
PYEOF
)
  status=PASS; note=-
  if [ $rc -ge 124 ] || [ $rc -eq 142 ]; then
    status=FAIL; note="timeout(${timeout}s)"
  elif grep -qE "\[error\]" "$out" && [ "$category" != "robustness" ]; then
    status=FAIL; note="errored: $(grep -m1 -E '\[error\]' "$out" | head -c 60)"
  elif [ "$verdict" = "MISS" ]; then
    status=FAIL; note="missing /$expect/"
  elif [ "${verdict#FORBID:}" != "$verdict" ]; then
    status=FAIL; note="forbidden: ${verdict#FORBID:}"
  fi
  [ $status = PASS ] && pass=$((pass+1)) || fail=$((fail+1))
  echo -e "$id\t$category\t$status\t$lat\t$note" >> "$RESULTS"
  echo "[$status] $id ($category) ${lat}s $note"
done < scripts/usecases.tsv

echo "---"
echo "pass=$pass fail=$fail"
awk -F'\t' 'NR>1 {t[$2]++; if ($3=="PASS") p[$2]++} END {for (c in t) printf "%-16s %d/%d\n", c, p[c]+0, t[c]}' "$RESULTS" | sort
