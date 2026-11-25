#!/bin/bash
# run upstream wasm tests, print pass/fail summary
R=~/Projects/urwasm-perf; L=$R/urbit-output
pos=$(wc -c < $L)
URW=$( LENS_TIMEOUT=1800 $R/bench/lens.sh d '-test %/tests/lib/wasm ~' )
sleep 3
tail -c +$((pos+1)) $L | grep -v '^UWT' > $R/bench/test-out.$1.txt
echo "lens: $URW"
grep -c '^OK ' $R/bench/test-out.$1.txt | sed 's/^/OK: /'
grep -E -c '^FAILED|CRASHED' $R/bench/test-out.$1.txt | sed 's/^/FAILED: /'
grep -E '^FAILED|CRASHED|ok=' $R/bench/test-out.$1.txt | head -10
