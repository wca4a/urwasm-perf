#!/bin/bash
# build.sh: compile SQLite + sqlapp.c to ../sqlapp.wasm (needs zig 0.15)
cd "$(dirname "$0")"
$(brew --prefix zig@0.15)/bin/zig cc -target wasm32-wasi -O2 -mexec-model=reactor -Wl,-z,stack-size=524288 -Wl,--strip-all \
 -DSQLITE_OS_OTHER=1 -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_TEMP_STORE=3 -DSQLITE_DEFAULT_MEMSTATUS=0 \
 -DSQLITE_OMIT_SHARED_CACHE -DSQLITE_OMIT_WAL -DSQLITE_OMIT_DEPRECATED -DSQLITE_OMIT_LOCALTIME -DSQLITE_ENABLE_FTS5 \
 -DSQLITE_ENABLE_MATH_FUNCTIONS -DSQLITE_DQS=0 -o ../sqlapp.wasm sqlapp.c sqlite3.c
