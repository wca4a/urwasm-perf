# urwasm-perf

Working notes, benchmarks and test programs from making urwasm (Urbit's Wasm
runner: the `run:wasm` jet in vere, on the wasm3 interpreter) faster.

Start with [bench/RESULTS.md](bench/RESULTS.md): it is the running log of what was
measured, what was changed and why, in order.

## Where the code changes are

| What | Where |
|---|---|
| Runtime patch (three commits) | `patches/000[1-3]-urwasm-*.patch`, also branch `urwasm-fast-clean` of wca4a/vere |
| Interpreter: crash fix | urbit/wasm3 pull request 4 |
| Interpreter: table limit fix | urbit/wasm3 pull request 5 |
| Interpreter: compile-order hook (the runtime patch needs it) | `patches/0001-compile-add-a-hook-*.patch`, also branch `compile-hook` of wca4a/wasm3 |

## What is in `bench/`

| Path | What it is |
|---|---|
| `RESULTS.md` | The log |
| `mkwasm.py`, `p*.wasm`, `call*.wasm` | Small synthetic modules (memory size, function count, long call chains) |
| `rustmod/`, `rust.hoon`, `runrust.py` | A Rust module with assorted workloads |
| `notes/`, `notes-app/`, `notes.hoon`, `mkwork.py` | A notes backend (serde_json, pulldown-cmark, sha2) and a ship app that serves it |
| `sqlapp/`, `sql-app/`, `sql.hoon`, `mksql.py` | SQLite compiled to Wasm with no operating system, and a ship app with a SQL page |
| `steps.hoon` | Measures the cost of each step of a multi-step script |
| `node-*.mjs` | Reference runs of the same modules in Node, to compare answers and time |
| `parse-*.py` | Compare a ship run with the Node reference and collect timings |
| `fresh.sh`, `ship.sh`, `lens.sh`, `tests.sh` | Boot a local fake ship, run commands on it, run the upstream wasm tests |
| `crash/` | Standalone reproducer for the interpreter crash |

The poker game built on the same pattern lives in its own repository,
wca4a/urbit-holdem.

## Running it

The scripts assume this folder is `~/Projects/urwasm-perf`, with a vere checkout
built in `vere/`, an `urbit/` checkout for the Arvo source, and a `brass.pill`
beside them. They were written for one machine and are not polished.

`bench/sqlapp/` includes the SQLite 3.46.0 amalgamation (`sqlite3.c`,
`sqlite3.h`), which is in the public domain.
