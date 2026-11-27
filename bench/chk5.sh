#!/bin/bash
# chk5.sh: the paths the fifth review round's fixes added, each forced with
# a switch of the test build, answers compared with Node's as always.
cd ~/Projects/urwasm-perf
unset URBIT_BIN URWASM_COLD URWASM_BIG
up()  { bench/ship.sh stop; for p in $(pgrep -f 'urwasm-perf/vere/zig-out.*urbit'); do kill -9 $p; done; rm -f pier/.vere.lock
        : > urbit-output; env "$@" URWASM_TIME= bench/ship.sh start >/dev/null 2>&1; }
wl()  { app=$1; L=$2
        if [ $app = notes ]; then G="+notes %notes %notes-work %gent"; elif [ $app = sql ]; then G="+sql %sqlapp %sql-work %gent"; else G="+sql %poker %poker-work %gent"; fi
        LENS_TIMEOUT=1800 bench/lens.sh d "$G" > bench/$app-out.$L.txt
        if [ $app = notes ]; then python3 bench/parse-notes.py $L | sed -n '1p'; else python3 bench/parse-app.py $app $L | sed -n '1p'; fi; }
n()   { grep -ac "$1" urbit-output | tr -d ' '; }
bad() { echo "bails: $(grep -ac '^bail' urbit-output)  faults: $(grep -ac 'loom: external\|Assertion' urbit-output)  worker: $(pgrep -f 'zig-out.*urbit work')"; }

URWASM_TIME= bench/fresh.sh >/dev/null 2>&1

echo "=== A. memory refused while idle instances exist: they go first, then retry"
up URWASM_OPENBUSY=1
wl notes ev; wl sql ev; wl poker ev; wl notes ev2; wl sql ev2
echo "idle instances dropped to make room: $(n 'UWH open evict')   refusals that failed the event: $(n 'memory refused\|code refused')"; bad

echo "=== B. sizing before anything makes way"
up URWASM_FITLOG=1
bench/tests.sh fit 2>&1 | sed -n '2,3p' | tr '\n' ' '
diff <(grep -E '^(OK|FAILED|CRASHED)' bench/test-out.fit.txt | sort) <(grep -E '^(OK|FAILED|CRASHED)' bench/test-out.base.txt | sort) >/dev/null && echo "| same as original"
wl notes fit; wl sql fit; wl poker fit
echo "instances sized: $(n 'UWH fit [0-9]')   dropped by count or budget: $(n 'UWH trim evict')   refused: $(n 'fit refused')"
echo "price at admission vs held after the call (bytes), largest shortfalls:"
python3 - <<'EOF'
import re
fit=None; rows=[]
for l in open('urbit-output', errors='replace'):
    m=re.match(r'UWH fit (\d+)', l)
    if m: fit=int(m.group(1)); continue
    m=re.match(r'UWH kept (\d+)', l)
    if m and fit is not None: rows.append((int(m.group(1))-fit, fit, int(m.group(1)))); fit=None
rows.sort(reverse=True)
print("  pairs:", len(rows), " held more than priced:", sum(1 for r in rows if r[0]>0))
for d,f,k in rows[:3]: print("  priced", f, "held", k, "difference", d)
EOF
bad

echo "=== B2. every instance refused at sizing: nothing else is dropped, calls go the ordinary way"
up URWASM_FITMAX=1000 URWASM_FITLOG=1
wl sql fitno
echo "refused: $(n 'fit refused')   dropped for them: $(n 'UWH trim evict\|UWH open evict')"; bad

echo "=== C. the ship empties its long-term cache (|meld)"
up URWASM_FITLOG=1
wl sql wipe1
bench/lens.sh a hood '+hood/meld' >/dev/null; sleep 20; bench/lens.sh d '(add 2 2)' >/dev/null
echo "wipe lines: $(grep -a 'UWH wipe' urbit-output | sort | uniq -c | tr '\n' ' ')"
wl sql wipe2; bad

echo "=== D. a stack overflow simulated in the middle of emptying a slot"
up URWASM_FREEOVER=1 URWASM_BIG=1
LENS_TIMEOUT=600 bench/lens.sh d '+sql %sqlapp %sql-work %gent' > /dev/null
grep -a 'UWH free: simulated\|UWH reap\|recover' urbit-output | sort | uniq -c
wl sql over; bad
bench/ship.sh stop
echo "=== done"
