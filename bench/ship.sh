#!/bin/bash
# ship.sh start|stop
R=~/Projects/urwasm-perf; U=${URBIT_BIN:-$R/vere/zig-out/aarch64-macos-none/urbit}
if [ "$1" = stop ]; then
  $R/bench/lens.sh a hood '+hood/exit' >/dev/null 2>&1; sleep 3; pkill -f 'zig-out.*urbit'; sleep 1; rm -f $R/pier/.vere.lock; exit 0
fi
pkill -f 'zig-out.*urbit'; sleep 1; rm -f $R/pier/.vere.lock
[ "${URWASM_TIME-1}" = "" ] && unset URWASM_TIME || export URWASM_TIME=1
URBIT_NO_MDNS=1 $U --lite-boot --daemon $R/pier >> $R/urbit-output 2>&1
sleep 6; $R/bench/lens.sh d '(add 2 2)'
