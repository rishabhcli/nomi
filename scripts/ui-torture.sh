#!/bin/bash
# Extreme UI test for the notch surface. Two drivers:
#   real  — cliclick moves the actual cursor + types real keystrokes
#           (requires Accessibility permission for the host terminal app)
#   hooks — the app's MNEMO_DEBUG_HOOKS DistributedNotification hooks
#           (no special permission; drives the same summon/dismiss/phases)
# Screen segments are recorded during transitions and graded for smoothness
# by scripts/analyze-frames.py (frame-differential analysis).
#
# Usage: ui-torture.sh [out-dir]
set -u
cd "$(dirname "$0")/.."
OUT=${1:-/tmp/ui-torture}
mkdir -p "$OUT"
LOG="$OUT/torture.log"
: > "$LOG"
note() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }

hook() { python3 -c "
from Foundation import NSDistributedNotificationCenter
NSDistributedNotificationCenter.defaultCenter().postNotificationName_object_('ai.mnemo.debug.$1', None)"; }

ask_hook() { python3 -c "
from Foundation import NSDistributedNotificationCenter
NSDistributedNotificationCenter.defaultCenter().postNotificationName_object_userInfo_(
    'ai.mnemo.debug.ask', None, {'query': '''$1'''})"; }

read -r W H <<< "$(system_profiler SPDisplaysDataType 2>/dev/null | python3 -c "
import sys,re
t=sys.stdin.read()
m=re.search(r'Resolution:\s*(\d+)\s*x\s*(\d+)', t)
print(m.group(1), m.group(2) if m else '1512 982')
" 2>/dev/null || echo "1512 982")"
NX=$((W / 2))

# Driver: hooks (default) or real (cliclick — needs Accessibility on the shell).
DRIVER=${MNEMO_UI_DRIVER:-hooks}
if [ "$DRIVER" = auto ]; then
  DRIVER=hooks
  WARN=$(cliclick m:+1,+0 2>&1 || true)
  if ! echo "$WARN" | grep -qi accessibility; then
    P1=$(cliclick p 2>/dev/null | tr -d ' ')
    cliclick m:+20,+0 2>/dev/null; sleep 0.2
    P2=$(cliclick p 2>/dev/null | tr -d ' ')
    [ "$P1" != "$P2" ] && DRIVER=real
  fi
fi
note "display ${W}x${H}pt · driver=$DRIVER"

open_ui()  { if [ $DRIVER = real ]; then cliclick "m:$NX,300" "w:150" "m:$NX,12" "w:120" "m:$NX,4"; else hook summon; fi; }
close_ui() { if [ $DRIVER = real ]; then cliclick "m:$NX,700"; else hook dismiss; fi; }

alive() { pgrep -f "debug/MnemoApp" > /dev/null; }
shot() { screencapture -x "$OUT/$1.png"; }

record() { screencapture -v -V "$2" -x "$OUT/$1.mov" 2>/dev/null & REC_PID=$!; }
frames() {
  rm -rf "$OUT/frames-$1"; mkdir -p "$OUT/frames-$1"
  ffmpeg -loglevel error -i "$OUT/$1.mov" -vf "fps=60,crop=iw:ih/4:0:0" "$OUT/frames-$1/f%04d.png" 2>> "$LOG"
}

fail=0
check() { if [ "$2" -eq 0 ]; then note "PASS: $1"; else note "FAIL: $1"; fail=$((fail+1)); fi; }

# ---------- 0. Preconditions ----------
alive; check "app alive at start" $?
: > /tmp/mnemo-geometry.log
shot 00-idle

# ---------- 1. Recorded open/close smoothness (3 cycles, graded) ----------
for i in 1 2 3; do
  close_ui; sleep 1
  record "open-$i" 3
  sleep 0.6; open_ui; sleep 1.8
  wait ${REC_PID:-0} 2>/dev/null
  shot "10-open-$i"
  record "close-$i" 3
  sleep 0.5; close_ui; sleep 2
  wait ${REC_PID:-0} 2>/dev/null
done
for i in 1 2 3; do
  frames "open-$i"  && python3 scripts/analyze-frames.py "$OUT/frames-open-$i"  "open-$i"  >> "$LOG" 2>&1
  check "open-$i smooth"  $?
  frames "close-$i" && python3 scripts/analyze-frames.py "$OUT/frames-close-$i" "close-$i" >> "$LOG" 2>&1
  check "close-$i smooth" $?
done

# ---------- 2. Rapid open/close soak (10 cycles) ----------
for i in $(seq 1 10); do open_ui; sleep 0.4; close_ui; sleep 0.35; done
sleep 1
alive; check "alive after 10 rapid cycles" $?
shot 20-after-soak

# ---------- 3. In-app 10x cycle hook (animation state machine soak) ----------
hook cycle
sleep 13
alive; check "alive after in-app cycle soak" $?
grep -q "cycle-done" /tmp/mnemo-geometry.log; check "in-app cycle completed" $?

# ---------- 4. Prompt through the UI ----------
if [ $DRIVER = real ]; then
  open_ui; sleep 1.2
  cliclick "c:$NX,60"; sleep 0.4
  cliclick "t:What is my favorite build tool?"; sleep 0.3
  shot 30-typed
  cliclick "kp:return"
  note "real prompt submitted; waiting"
  sleep 40
  shot 31-answer
  alive; check "alive after real prompt round-trip" $?
  cliclick "kp:esc"; sleep 0.5
else
  hook typing; sleep 1
  shot 30-typed          # mic → send morph state
  hook searching; sleep 1
  shot 30-searching
  hook demo; sleep 1.2
  shot 31-answer         # reference answer layout
  hook snapshot; sleep 1
  alive; check "alive after phase drive" $?
  # Real orchestrator round-trip through the UI state machine.
  ask_hook "What is my favorite build tool?"; sleep 45
  shot 32-live-answer
  grep -q "ask-started" /tmp/mnemo-geometry.log; check "live ask started" $?
  alive; check "alive after live ask round-trip" $?
  hook dismiss
fi

# ---------- 5. Geometry assertions from the app's own log ----------
hook summon; sleep 0.8; hook snapshot; sleep 1; hook dismiss
grep -q "midXAligned=true" /tmp/mnemo-geometry.log; check "panel midX aligned to notch" $?
grep -q "topFlush=true"    /tmp/mnemo-geometry.log; check "panel flush to screen top" $?

# ---------- 6. Orb amplitude curve stills ----------
hook orb; sleep 2
ls /tmp/mnemo-orb-100.png > /dev/null 2>&1; check "orb stills rendered" $?

# ---------- 7. Crash-report scan ----------
NEW_CRASHES=$(find ~/Library/Logs/DiagnosticReports \( -name "MnemoApp*" \) -newer "$OUT/00-idle.png" 2>/dev/null | wc -l | tr -d ' ')
check "no new crash reports (found $NEW_CRASHES)" "$NEW_CRASHES"
alive; check "app alive at end" $?

note "---- torture done: $fail failures (driver=$DRIVER) ----"
exit "$fail"
