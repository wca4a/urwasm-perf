#!/bin/bash
# sig5.sh [nopass]: interrupt the worker while the keep-alive code is holding
# signals off, so that the signal lands on another thread of the process.
# needs the test build (URWASM_HOLDNAP naps inside the hold and logs it).
# with "nopass" the handlers behave as they did before the fix.
cd ~/Projects/urwasm-perf
N=${N:-6}
bench/ship.sh stop
: > urbit-output
export URWASM_HOLDNAP=2500
[ "$1" = nopass ] && export URWASM_NOPASS=1
URWASM_TIME= bench/ship.sh start >/dev/null 2>&1
W0=$(pgrep -f 'zig-out.*urbit work'); echo "worker pid at start: $W0"
sent=0
for i in $(seq 1 $N); do
  before=$(grep -c 'UWH nap$' urbit-output | tr -d ' ')
  (LENS_TIMEOUT=120 bench/lens.sh d '+sql %sqlapp %sql-work %gent' >/dev/null 2>&1 &)
  hit=0
  for t in $(seq 1 1200); do
    now=$(grep -ac 'UWH nap' urbit-output | tr -d ' ')
    over=$(grep -ac 'UWH nap over' urbit-output | tr -d ' ')
    # a nap has started and not ended
    if [ $((now - 2 * over)) -gt 0 ]; then hit=1; break; fi
    sleep 0.05
  done
  W=$(pgrep -f 'zig-out.*urbit work')
  if [ $hit = 1 ] && [ -n "$W" ]; then sleep 0.3; kill -INT $W; sent=$((sent + 1)); fi
  sleep 5
  [ -z "$(pgrep -f 'zig-out.*urbit work')" ] && { echo "round $i: worker is gone"; break; }
done
sleep 2
if [ "$1" != nopass ]; then
  # same worker, after the interrupts: do the answers still match Node?
  LENS_TIMEOUT=600 bench/lens.sh d '+sql %sqlapp %sql-work %gent' > bench/sql-out.sig5.txt
  python3 bench/parse-app.py sql sig5 | sed -n '1p'
fi
W1=$(pgrep -f 'zig-out.*urbit work')
echo "interrupts sent inside a hold: $sent"
echo "worker pid at end: ${W1:-none}"
echo "landed on another thread: $(grep -ac 'UWH signal on another thread' urbit-output)"
echo "recovered: $(grep -ac 'recover: dig: intr' urbit-output)   reaps: $(grep -ac 'UWH reap' urbit-output)"
echo "crash lines: $(grep -aciE 'segmentation|bus error|abort|assert|bail: |serf.*exit|pier.*dead|work.*exit' urbit-output)"
grep -aiE 'segmentation|bus error|assert|serf|dead|exited|signal [0-9]' urbit-output | head -5
unset URWASM_HOLDNAP URWASM_NOPASS
