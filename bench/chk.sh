#!/bin/bash
cd ~/Projects/urwasm-perf
unset URBIT_BIN URWASM_COLD URWASM_TINY
chk() { L=$1; URWASM_TIME= bench/fresh.sh >/dev/null 2>&1
  bench/tests.sh $L 2>&1 | sed -n '2,3p' | tr '\n' ' '
  diff <(grep -E '^(OK|FAILED|CRASHED)' bench/test-out.$L.txt | sort) <(grep -E '^(OK|FAILED|CRASHED)' bench/test-out.base.txt | sort) >/dev/null && echo "| same as original"
  LENS_TIMEOUT=600 bench/lens.sh d '+hot-test %gent' > bench/hot-test.$L.txt
  echo "stale-program test: $(grep -o '%all-agree\|%mismatch\|crud\|build-fail' bench/hot-test.$L.txt | head -1)"
  cmp bench/hot-test.$L.txt bench/hot-test.cold.txt && echo "identical to keep-alive off"
  python3 bench/runrust.py rustmod 2>&1 | grep -v "^[a-z]*(.*nan\|^step" | tail -4
  for app in notes sql poker; do
    if [ $app = notes ]; then G="+notes %notes %notes-work %gent"; elif [ $app = sql ]; then G="+sql %sqlapp %sql-work %gent"; else G="+sql %poker %poker-work %gent"; fi
    bench/ship.sh stop; URWASM_TIME= bench/ship.sh start >/dev/null 2>&1
    LENS_TIMEOUT=1800 bench/lens.sh d "$G" > bench/$app-out.$L.txt; bench/lens.sh d '(add 2 2)' >/dev/null; bench/ship.sh stop
    if [ $app = notes ]; then python3 bench/parse-notes.py $L | sed -n '1p;$p'; else python3 bench/parse-app.py $app $L | sed -n '1p;$p'; fi
    URWASM_TIME= bench/ship.sh start >/dev/null 2>&1
  done
  echo "forced drops: $(grep -c 'UWH big' urbit-output)  bails: $(grep -c '^bail' urbit-output)  faults: $(grep -c 'loom: external\|Assertion' urbit-output)"
}
echo "=== keep-alive on"; chk hot5
echo "=== every paused state forced down the too-much-code path"; export URWASM_BIG=1; chk big; unset URWASM_BIG
echo "=== done"
