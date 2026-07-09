#!/bin/bash
# Watches the engine's ingest queue. If nothing finalizes for two consecutive
# 5-minute windows while docs are queued, restarts the engine and wakes the
# pipeline with a probe doc. Exits when the queue fully drains.
set -u
cd "$(dirname "$0")/.."
export SUPERMEMORY_API_KEY=$(cat ~/.supermemory/data/api-key)
CTL=.build/debug/mnemoctl
last_fin=-1
stall=0

counts() {
  curl -s -X POST http://127.0.0.1:6767/v3/documents/list \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $SUPERMEMORY_API_KEY" \
    -d '{"page":1,"limit":300,"containerTags":["mnemo"]}' | python3 -c "
import json,sys
from collections import Counter
c=Counter(x.get('status') for x in json.load(sys.stdin).get('memories',[]))
print(c['done'], c['queued']+c['indexing'], c['failed'])" 2>/dev/null
}

while true; do
  read -r done pending failed <<< "$(counts)"
  fin=$(grep -ac "finalized" /tmp/supermemory.log 2>/dev/null || echo 0)
  echo "$(date +%H:%M:%S) done=$done pending=$pending failed=$failed finalized_total=$fin"
  if [ "${pending:-1}" = "0" ]; then echo "DRAIN-COMPLETE done=$done failed=$failed"; break; fi
  if [ "$fin" = "$last_fin" ]; then
    stall=$((stall+1))
    if [ $stall -ge 2 ]; then
      echo "$(date +%H:%M:%S) STALL detected — restarting engine + waking queue"
      $CTL restart-engine >/dev/null 2>&1
      sleep 8
      curl -s -X POST http://127.0.0.1:6767/v3/documents \
        -H 'Content-Type: application/json' -H "Authorization: Bearer $SUPERMEMORY_API_KEY" \
        -d "{\"content\":\"watchdog wake $(date +%H%M%S)\",\"containerTags\":[\"mnemo-probe\"]}" >/dev/null
      stall=0
    fi
  else
    stall=0
  fi
  last_fin=$fin
  sleep 300
done
