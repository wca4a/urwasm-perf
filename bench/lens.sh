#!/bin/bash
# usage: lens.sh d '<dojo expr>'   |  lens.sh a <app> '<generator>'
port=$(grep loopback ~/Projects/urwasm-perf/pier/.http.ports | awk '{print $1}')
if [ "$1" = d ]; then
  python3 -c 'import json,sys;print(json.dumps({"source":{"dojo":sys.argv[1]},"sink":{"stdout":None}}))' "$2" | curl -s --max-time ${LENS_TIMEOUT:-600} --data @- "http://localhost:$port"
else
  python3 -c 'import json,sys;print(json.dumps({"source":{"dojo":sys.argv[2]},"sink":{"app":sys.argv[1]}}))' "$2" "$3" | curl -s --max-time ${LENS_TIMEOUT:-600} --data @- "http://localhost:$port"
fi
echo
