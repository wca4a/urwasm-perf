#!/bin/bash
# fresh.sh: throw away the pier and boot a new fake ship with tests + bench installed
R=~/Projects/urwasm-perf; U=${URBIT_BIN:-$R/vere/zig-out/aarch64-macos-none/urbit}
cd $R; pkill -f 'zig-out.*urbit'; sleep 1; rm -rf pier; : > urbit-output
[ "${URWASM_TIME-1}" = "" ] && unset URWASM_TIME || export URWASM_TIME=1
URBIT_NO_MDNS=1 $U --lite-boot --daemon --fake bus --bootstrap brass.pill --arvo urbit/pkg/arvo --pier pier >> urbit-output 2>&1
sleep 6
bench/lens.sh a hood '+hood/mount /=base=' >/dev/null; sleep 3
mkdir -p pier/base/bench pier/base/tests/lib && cp bench/*.wasm pier/base/bench/ && cp bench/notes-work.txt bench/sql-work.txt bench/poker-work.txt pier/base/bench/ && cp bench/bench.hoon bench/rust.hoon bench/notes.hoon bench/steps.hoon bench/sql.hoon pier/base/gen/ && cp -R urbit/tests/lib/wasm pier/base/tests/lib/
bench/lens.sh a hood '+hood/commit %base' >/dev/null; sleep 8
bench/lens.sh d '(add 2 2)'
