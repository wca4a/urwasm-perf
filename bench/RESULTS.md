# urwasm stateful jet: where the time goes (2026-11-24)

Setup: vere 697fc95 built from source (ReleaseFast, Apple Silicon), fake ship ~bus, Arvo from
urbit/urbit 88c6173 (zuse 408). Timers added locally to `pkg/noun/jets/e/urwasm.c` (printed when
`URWASM_TIME` is set). mDNS switched off with a local `URBIT_NO_MDNS` guard because it crashed the
king on this machine. Modules are hand-assembled by `mkwasm.py`; calls go through `+bench`
(`bench.hoon`), hint `%gent`, 50 calls each, averages below are cached-state calls only.

## Per-call cost of a call that does nothing (ms)

| module                         | total | setup | copy in | compile | run  | save  |
|--------------------------------|-------|-------|---------|---------|------|-------|
| 64 KB memory, 3 functions      | 0.96  | 0.43  | 0.17    | 0.004   | 0.05 | 0.31  |
| 1 MB memory (in use)           | 1.53  | 0.54  | 0.32    | 0.003   | 0.10 | 0.56  |
| 16 MB memory (in use)          | 1.56  | 0.44  | 0.47    | 0.003   | 0.04 | 0.60  |
| 64 MB memory (in use)          | 3.94  | 0.51  | 1.63    | 0.005   | 0.06 | 1.73  |
| 64 MB memory (all zero)        | 17.34 | 0.39  | 0.44    | 0.005   | 0.04 | 16.46 |
| 1,000 extra functions (54 KB)  | 1.28  | 0.37  | 0.14    | 0.47    | 0.03 | 0.26  |
| 10,000 extra functions (540 KB)| 5.49  | 0.39  | 0.20    | 4.79    | 0.05 | 0.07  |

## Engine speed: 100M-iteration loop

| engine                              | time   |
|-------------------------------------|--------|
| wasm3 in the stateful jet (%gent)   | 488 ms |
| wasm3 in the stateless jet (%omit)  | 362 ms |
| V8 (Node 26), compiled              | ~120 ms |

## Stateless mode, for comparison

20 calls on the 540 KB module with `%omit` took 1.4 to 1.6 s (70 to 80 ms per call): each call
re-parses the module and replays every earlier call.

## Not measured

Real Rust modules, effect on snapshots and the event log, 64-bit loom builds, Linux.

# After the fixes (branch `urwasm-fast` in vere/, 2026-11-24)

Three changes in `pkg/noun/jets/e/urwasm.c`: remember the per-context setup in the memo cache;
prepare functions on first call when the loaded state is not paused (redo eagerly if the call ends
paused); skip trailing zero pages when saving memory. Upstream tests: 48 of 48 pass before and
after, same results.

| module (do-nothing call, ms)    | before | after | 
|---------------------------------|--------|-------|
| 64 KB memory, 3 functions       | 0.96   | 0.50  |
| 1 MB memory (in use)            | 1.53   | 0.51  |
| 16 MB memory (in use)           | 1.56   | 1.08  |
| 64 MB memory (in use)           | 3.94   | 3.16  |
| 64 MB memory (all zero)         | 17.34  | 3.88  |
| 1,000 extra functions (54 KB)   | 1.28   | 0.51  |
| 10,000 extra functions (540 KB) | 5.49   | 0.29  |

What is left per call: about 0.45 ms copying wasm3's own bookkeeping in and out, plus about
0.05 ms per MB of memory. Not exercised: the spill-into-extra-chunks path of the lazy code arena
(needs over 1 MB of code executed in one call).

# After sizing the saved struct arena exactly (same branch, later on 2026-11-24)

48 of 48 upstream tests pass, same results, on a freshly booted ship.

| module (do-nothing call, ms)    | original | first fixes | now  |
|---------------------------------|----------|-------------|------|
| 64 KB memory, 3 functions       | 0.96     | 0.50        | 0.12 |
| 1 MB memory (in use)            | 1.53     | 0.51        | 0.17 |
| 16 MB memory (in use)           | 1.56     | 1.08        | 0.64 |
| 64 MB memory (in use)           | 3.94     | 3.16        | 2.27 |
| 64 MB memory (all zero)         | 17.34    | 3.88        | 2.20 |
| 1,000 extra functions (54 KB)   | 1.28     | 0.51        | 0.13 |
| 10,000 extra functions (540 KB) | 5.49     | 0.29        | 0.22 |

Left: about 0.08 ms copying wasm3's structs (mostly its 2 MB stack) and about 0.035 ms per MB of
Wasm memory, copied in and out on every call. Not built: keeping a live instance between calls.

## Real Rust module (2026-11-24)

`rustmod/` is ordinary std Rust (HashMap, BTreeMap, String formatting, sorting, hand-written SHA-256), built with
`cargo build --release --target wasm32-unknown-unknown`: 80 KB, no host imports. One instance, 360 calls in sequence
(`rust.hoon`, `runrust.py`, `parse-rust.py`). Every answer matched Node/V8 on both runtimes. ms per call, in order:

| Step | Calls | Original total | Fixed total | Original run | Fixed run |
|---|---|---|---|---|---|
| tick() | 50 | 1.68 | 0.16 | 0.04 | 0.03 |
| put(i) | 50 | 1.87 | 0.40 | 0.06 | 0.27 |
| get(i) | 50 | 1.82 | 0.17 | 0.05 | 0.04 |
| fill(20000) | 1 | 205.36 | 162.60 | 202.32 | 162.44 |
| tick() | 50 | 2.05 | 0.23 | 0.05 | 0.03 |
| put(i) | 50 | 1.76 | 0.45 | 0.05 | 0.25 |
| scan() | 5 | 4.29 | 2.34 | 2.52 | 2.13 |
| sort(1000000) | 1 | 164.63 | 128.20 | 161.60 | 127.63 |
| hash(200000) | 1 | 552.43 | 437.70 | 550.45 | 437.05 |
| grow(4096) | 1 | 15.45 | 11.47 | 12.47 | 10.98 |
| tick() | 50 | 2.22 | 0.48 | 0.05 | 0.03 |
| grow(16384) | 1 | 55.05 | 43.32 | 50.26 | 40.92 |
| tick() | 50 | 3.08 | 1.11 | 0.05 | 0.04 |

Memory grows through the sequence: about 1 MB at the start, about 12 MB after fill, about 16 MB after grow(4096), about 32 MB after grow(16384).
Node/V8 for the heavy calls: fill(20000) about 19 ms, sort(1000000) about 20 ms, hash(200000) about 190 ms.
`put` runs slower inside the fixed runtime (0.27 vs 0.06 ms) because lazily prepared code is thrown away after each call and the formatting code is re-prepared every time; total is still 4x lower.

### Existing crash found (not caused by these changes)

A synthetic module whose one function calls N others (`callN.wasm`, `callall.wasm`) crashes the ship on first load:
`loom: external fault` inside wasm3 `EnsureCodePageNumLines` under `m3_CompileModule`. N=100 and N=1,000 work and match Node;
N=3,000 crashes the fixed runtime; N=10,000 crashes both original and fixed. Not diagnosed. So the >1 MB lazy chunk-spill path is still untested.

## Crash diagnosed and clean patch (2026-11-25)

Cause of the large-function crash: wasm3 `CompileCallArgsAndReturn` (m3_compile.c) marks a call's result slots in
`m3Slots[d_m3MaxFunctionSlots = 4000]` without a bounds check. A chain of calls each consuming the previous result
climbs 2 slots per call, so about 2,000 chained calls write past the array into the rest of the compilation state and
the runtime (code page lists), and the next page lookup faults. Found with `bench/crash/repro.c` built with ASan/UBSan
(`index 4000 out of bounds for type 'u8[4000]'`). Present in urbit/wasm3 268894556a, independent of the jet changes.

Fix (local clone `wasm3/`, branch `fix-call-slot-overflow`): refuse to compile with `m3Err_functionStackOverflow`.
Standalone: chain of 1,997 calls still runs, 1,998+ is refused cleanly; 10,000 unchained calls unaffected.
On the ship (branch `urwasm-test` = clean patch + this fix): call3000/callall fail the one command ("compilation error:
compiling function overran its stack height limit", bail: fail), ship stays up and keeps answering.

Clean patch: vere branch `urwasm-fast-clean` (one commit on develop, no timers, only urwasm.c). 48/48 wasm tests,
same results as original; Rust module matches Node. `took` per call: tiny module 0.13 ms, 540 KB module 0.30 ms,
64 MB memory 2.2 to 2.5 ms (includes the Hoon loop). Patches for both repos are in `patches/`.

### Review follow-up (2026-11-25)

Codex review did not finish (requested model unavailable on this account; the default-model run was cut off by the
service). Its two interim leads were checked by hand and both fixed in `urwasm-fast-clean` (f1d2d9f):
1. The match-data memo went into the persistent cache, which `+mice` harvests and returns to Hoon. Now bypassed when
   `u3a_flag_cash` is set. (The existing state entries leak into `+mice` the same way upstream; not changed here.)
2. The eager redo re-read the saved state from the cache; a nested run on the same seed could tombstone it first.
   The jet now holds its own reference to the state across the lazy attempt.
Re-run after these: 48/48 tests same as original, Rust module matches Node, call3000 fails cleanly, ship stays up.
Not exercised: the `+mice` path, the nested-run redo path, the >1 MB lazy chunk spill.

## Real app: notes backend (2026-11-25)

`bench/notes/` is a notes backend in Rust using serde_json, pulldown-cmark and sha2 (611 KB of Wasm, no imports).
One JSON request in, one JSON response out. Each request is one urwasm run of five steps:
`request(len)`, memwrite, `handle(len)`, `response()`, memread. Driver: `bench/notes.hoon`; workload: `bench/mkwork.py`
writes `notes-work.txt` (814 requests: 251 add, 252 search, 93 get, 88 render, 77 edit, 23 delete, tags, stats,
2 exports of about 200 KB, 3 malformed, one 100 KB note). Reference: `bench/node-notes.mjs`. Compare: `bench/parse-notes.py LABEL`.

Answers: 814 of 814 responses identical to Node (length and SHA-256) on the original runtime, the clean patch
(binary built from urwasm-test), and both timer builds.

Time per request (`~> %bout` around each run, no-timer builds):

| request | original ms | patched ms | Node ms |
|---|---|---|---|
| add | 6.10 | 2.11 | 0.044 |
| search | 6.32 | 2.24 | 0.055 |
| edit | 6.24 | 2.17 | 0.048 |
| render | 6.04 | 2.55 | 0.058 |
| get | 5.95 | 1.56 | 0.007 |
| stats | 6.04 | 1.48 | 0.007 |
| export (200 KB reply) | 9.71 | 4.90 | 0.293 |
| all 814 | 5042 total | 1745 total | 38 total |

The very first request takes about 5.5 s on both runtimes, outside the jet's own timers (jet total for it is about 9 ms). Not explained yet.

Breakdown per request from the timer builds (vere-base = original, vere-timers = urwasm-fast 28aec3c):
original total 6.37 = compile 4.34 + run 1.16 + setup 0.40 + save 0.25 + copy 0.21;
patched total 2.22 = run 2.03 + copy 0.13 + save 0.04 + setup 0.01.

Where the remaining run time goes (`bench/steps.hoon`, same module, 100 runs each):

| script | original run ms | patched run ms |
|---|---|---|
| 1 call | 0.083 | 0.059 |
| 2 calls | 0.325 | 0.282 |
| 4 calls | 0.771 | 0.725 |
| call + memwrite | 0.209 | 0.175 |
| call + memread | 0.198 | 0.175 |
| full 5-step request (stats) | 0.798 | 1.211 |

So every step after the first costs about 0.2 ms on both runtimes, whatever the step does. That is an existing cost in
how the jet chains script steps, untouched by the patch, and it is now the largest part of a small request.
The extra 0.4 ms in the patched 5-step request is lazy compile re-preparing the functions `handle` touches on every call.

## Real app: SQLite (2026-11-25)

`bench/sqlapp/` is SQLite 3.46.0 (amalgamation from the libsqlite3-sys crate already on disk) plus `sqlapp.c`, built with
`zig cc -target wasm32-wasi` (`build.sh`) to `bench/sqlapp.wasm`, 1.29 MB. No files: in-memory database, custom VFS.
Two imports, `env.ship_now` and `env.ship_entropy`; each makes the run stop (`call-ext`) and the caller resumes it with the answer.
Driver `bench/sql.hoon` (fixed time and entropy so answers are comparable), workload `bench/mksql.py` -> `sql-work.txt`
(367 requests: schema with trigger, view, FTS5; 600 customers, 200 products, 3000 orders, 9000 items; joins, window functions,
recursive CTEs, JSON, FTS, updates, rollbacks, errors, integrity check; 20 requests need the ship). Reference `bench/node-sql.mjs`.
Compare `bench/parse-app.py sql LABEL`.

Answers: 367 of 367 identical to Node on the original runtime and on the patch, including all 20 that stop and resume.
This is the first time the stop-and-resume path of the patch has run (lazy first try, eager redo, later resume).

Time per request, ms (`~> %bout`):

| phase | original | patched | Node |
|---|---|---|---|
| before the first request that asks the ship (52 requests, mostly bulk inserts) | 16.8 | 7.9 | 0.47 |
| after it (313 requests) | 25.8 | 25.2 | 1.14 |
| a trivial request after it (139 of them) | 14.3 | 13.7 | under 0.06 |
| a request that asks the ship | 27.5 | 26.5 | 0.05 |
| all 367 | 9008 total | 8338 total | 402 total |

Finding: once a module has stopped to ask the ship even once, the patch marks it "eager" for the rest of the process
(`_uw_eager_w`), so every later call compiles all 1.29 MB again (about 13 ms) exactly like the original. For any app that
uses imports that block, the patch currently gives almost nothing after the first such call. A request that asks the ship
pays the compile twice (once to stop, once to resume).

Playable: Gall agents `bench/notes-app/notes.hoon` and `bench/sql-app/sql.hoon` with pages `notes-ui.html`, `sql-ui.html`
(copy agents to `app/`, pages and wasm to `/bench`, `+hood/start`). http://localhost/notes and http://localhost/sql.
The SQL agent answers the imports from `now.bowl` and `eny.bowl`.

## Lazy compile kept across suspension (2026-11-25)

vere `urwasm-fast-clean` e9ec0a2 (second commit on top of f1d2d9f) + urbit/wasm3 branch `compile-hook` fe4ff1e (15 lines:
`m3_SetCompileHook`, called at the start of every `CompileFunction`). Local test build: vere `urwasm-test`, wasm3 `urwasm-test-all`
(hook + slot fix) via `wasm3-test-all.tar.gz`.

How: code layout depends only on compile order (only code pages and constants come from the transient allocator, both at compile
time). The jet records the order (function indices) through the hook, saves `[count indices code-bytes-used]` next to the runtime
offset when a lazily compiled call ends suspended, and on load compiles those functions in that order, checks count and bytes used,
then keeps compiling lazily. No eager table any more (`_uw_eager_w` gone); a per-module code arena size hint replaces it.
A suspending call is re-run only if its code spilled out of the arena (then once, in an arena that fits). If the rebuilt layout
does not match, the state is dropped and recomputed from the seed. States suspended after an eager compile (first instantiation,
or saved by an older runtime) still load eagerly. An older runtime fails cleanly (bail) on the new suspended format.

SQL workload, ms per request (base / patch before / patch now / Node):

| phase | original | patch before | patch now | Node |
|---|---|---|---|---|
| before the first ask (52) | 16.8 | 7.9 | 8.0 | 0.47 |
| after the first ask (313) | 25.8 | 25.2 | 15.8 | 1.14 |
| trivial request after it (139) | 14.3 | 13.7 | 4.3 | 0.03 |
| a request that asks the ship (20) | 27.5 | 26.5 | 7.0 | 0.05 |
| all 367 | 9008 | 8338 | 5377 | 402 |

Checks on the new build: SQL 367/367 same as Node; notes 814/814; upstream wasm tests 48/48, same results as original.
Forced-spill run (temporary env switch, 64 KB arena, not in the patch): redo path taken 20 times, SQL 367/367, tests 48/48.
The layout-mismatch fallback never triggered and is not exercised. Not yet reviewed by anyone else.
A SQLite request compiles about 1.1 to 1.3 MB of code lazily; that recompile per call is most of the remaining 4 ms floor.

## Review fixes (2026-11-25)

Codex reviewed e9ec0a2 + the wasm3 hook; all findings addressed. vere `urwasm-fast-clean` is now three commits on develop:
f1d2d9f (per-call overhead), 4376493 (lazy across suspension), 724b73c (match data packed field by field).
wasm3 `compile-hook` is 9e83198 (hook now passes the function index; documented as process-wide like the allocator setters).

- Layout-mismatch fallback now clears lazy mode, so a recomputed state that suspends again is saved as eagerly compiled.
- Lazily suspended states live under their own cache key (`uw_ord_m`); an older runtime never sees them and recomputes from the seed.
- A lazy arena too small during load (import stubs, replay) reloads the state with twice the room instead of failing.
- A suspended state whose code cannot be made contiguous (over the 1 GiB cap) is not cached; the yield is still returned.
- The vere patch needs the wasm3 pin bumped once the hook is merged there (not done here: no upstream commit to point at yet).

Checks after the fixes: SQL 367/367, notes 814/814, upstream tests 48/48; speed unchanged (SQL workload 5.38 s vs 5.35 s).
Forced with temporary env switches (not in the patch), SQL 367/367 and tests 48/48 each time:
spill (4 KB arena): reload-with-more-room path 372 times, redo path 20 times; forced mismatch: fallback path 22 times.

## Second review fixes (2026-11-25)

Second Codex pass: hook clean; three P2 points on the jet, all addressed. vere `urwasm-fast-clean` = f1d2d9f, e8c78d9, 4943a9f.

- Inside +mice (u3a_flag_cash) the jet does not compile lazily (unless the loaded state already depends on it), does not write
  `uw_ord_m` entries, and does not keep a lazily suspended state: the harvested map has one entry per seed, in the old form.
- Replay arena is sized from the recorded bytes used (+64 KB), not twice that.
- The per-module code arena hint halves after lighter calls instead of only growing.

Checks: SQL 367/367, notes 814/814, upstream tests 48/48. Forced spill: reload 372, redo 20; forced mismatch: 22; all correct.
Speed unchanged within noise (notes 1.79 to 1.80 s, SQL 5.30 s best; the Mac was under heavy unrelated load, runs varied up to 7.5 s).
Not tested: the +mice behaviour (this kernel has no +mice arm to call it from).

## Hold'em table (2026-11-25)

`bench/poker/` is a Texas hold'em engine in Rust (serde_json only, 301 KB of Wasm, one import `env.ship_entropy` called twice per
deal). Reply is line-based: the caller's answer, then one line per seated player (32-char token + that player's view), then the
spectator view; a player's view holds only their own cards. Agent `bench/poker-app/poker.hoon` keeps the per-token lines and serves
polls from them without running wasm; page `poker-ui.html` at http://localhost/poker (token per tab in sessionStorage, polls every 600 ms).

Rules checks (native, `cargo test --release` in bench/poker): hand ranking ladder and kickers; pot splitting (side pots, ties with odd
chips, uncalled bets, folded contributors); 20,000 random hands with players joining, leaving and rebuying: chips always conserved,
never stuck, nobody else's cards in a player's view.

On the ship: `bench/mkpoker.mjs` lets bots play (700 requests, 34 hands, refused and malformed requests included) and
`+sql %poker %poker-work %gent` replays them. 700 of 700 replies identical to Node on original and patched runtimes.
Per move: original median 5.0 ms, patched 3.3 ms; a deal (stops twice for randomness): original 10.6 ms, patched 4.1 ms.
Played a hand to showdown through the page in two browser tabs (about 26 ms per move round trip).

### Second interpreter bug found (not caused by these changes)

urbit/wasm3 reads a table's maximum size with `ReadLEB_i32`. A maximum of 64 to 127 (one LEB byte with bit 6 set; also 8192 to
16383 and so on) decodes negative and `m3_ValidateModule` rejects a valid module ("validation error: malformed Wasm binary").
The first poker build had a table of 102 and failed on both runtimes. Workaround in the module: link with `--growable-table`
(bench/poker/.cargo/config.toml). Fix: local wasm3 branch `fix-table-limit-leb` c0fc307, patch in `patches/`. Not pushed.

## Sealed deck for hold'em (2026-11-25)

Commit-reveal shuffle in wca4a/urbit-holdem: the engine fixes a 32-byte secret from ship entropy (4 import calls) and publishes
its SHA-256; each browser adds 16 random bytes; deck = public recipe over secret, numbers and hand number (SHA-256 stream,
unbiased Fisher-Yates); after the hand the secret, numbers and deck are published and every browser re-derives and checks.
Three independent implementations of the recipe (Rust engine, JavaScript page with its own SHA-256, Python seat script).

Checks: native tests 4/4; `test/verify.mjs`: 300 bot hands, 1,495 player-checks, every check line true, six kinds of tampering
all caught; ship replay 905 of 905 replies identical to Node on original and patched runtimes; two browser tabs each showed
"Hand 1 checked: the deal was fair" with all six lines passing.
Per move on the ship (noisy machine): patched 3.5 ms, original 6.8 ms; deal patched 6.6 ms, original 25 ms.
Does not hide the cards from the ship operator, and does not stop a player colluding with the ship from grinding their number.

## Where the per-step cost comes from (2026-11-26)

Profiled `+steps %notes 30.000 %gent %c4` on the patched runtime with macOS `sample`. Of the time inside the jet, 66% is
under `uw_slam_check` (running a `;<` continuation), and it is Nock interpretation plus noun allocation and freeing, not wasm.

Two candidate causes, tested separately:

1. The fresh virtualization (`u3n_nock_an`, a new road per continuation). Replaced with `u3n_nock_on` under a test switch:
   c1 0.184 -> 0.188, c2 0.394 -> 0.399, c4 1.010 -> 0.811, all 1.726 -> 1.667 ms. Small, and it would change behaviour
   (scries in scripts are blocked today). Not pursued; switch removed.
2. The Hoon library itself. `bench/monad.hoon` builds script forms without running any wasm:

| what is built | ms each |
|---|---|
| empty loop | 0.0006 |
| `*m-sat` (default lia-state) | 0.014 |
| `(call 'f' ~)` | 0.014 |
| `(memread 0 16)` | 0.014 |
| `(call-1 'f' ~)` | 0.088 |
| `;<` around `call` | 0.087 |
| `;<` around `call-1` | 0.16 to 0.23 |

So the cost is in lib/wasm/lia: every `;<` costs about 0.07 ms to build (the forms are gates whose sample defaults are
bunted each time), and `call-1` hides a second `;<`. It is not a runtime problem and the jet cannot avoid it.

What an app can do today (`+steps ... %lean`): reserve the request buffer once and reuse it, and use `call` in place of
`call-1`. Same request, same answer: 1.38 -> 1.01 ms per call (27% less), no runtime change.

What the library could do: give the script forms a cheap default sample (compute the lia-state default once per `arrows`
core, not per form). That changes core layout the jet depends on (context axes), so kernel and runtime would change together.

## Keeping instances alive between calls (2026-11-26)

vere branch `urwasm-hot` = `urwasm-fast-clean` + one commit (2b5c419, `patches/0004-...`). Local test build: `urwasm-hot-test`
(adds the mdns guard, the test wasm3, and a `URWASM_COLD` switch that turns keep-alive off for comparison).

What it does: after a call the instance (struct arena, compiled code, wasm memory) stays in C-heap memory, in one of 8 slots
(512 MB ceiling in total, 256 MB wasm memory per instance, 256 MB of reserved address space for code each). The next call on the
state just saved reuses it: no copy in, no relink, no recompile. Every call still writes the full saved state to the memo cache,
which stays the source of truth.

How it stays correct: each save writes a fresh random id after the struct image in the saved state and gives the same id to the
live instance; an instance has no id while a call runs on it. A call uses a live instance only if the saved state it found for
its seed carries that instance's id. Rolled-back events, branches, restarts and cache trims all end in "ids differ", which means
load from the saved state as before. A bail during a call on a live instance is caught in the jet (same road, its own setjmp),
the instance is dropped, and the bail is re-raised. An event aborted by a signal skips that; such a slot is reclaimed when a
later call arrives from a frame that is not deeper than the one that owned it.
Not used inside +mice, nor for %oust.

Bug found on the way: my first version passed an 8-byte buffer to `c3_rand()`, which fills 64. Fixed.

Checks (keep-alive on, and off with the same build):
- upstream wasm tests 48/48, same results as the original runtime
- notes 814/814, SQL 367/367, poker 905/905 replies identical to Node, on and off
- `bench/hot-test.hoon`, 44 checks, identical output on and off: sequence; a call whose surrounding computation then crashes
  (rollback); a call that crashes halfway after changing the instance (trap path, seen firing); branching from an older seed;
  12 instances in rotation through 8 slots (eviction)
- restart and mixing runtimes on one ship: 3 notes + SQL table on this build, stop, 2 more on the ORIGINAL runtime, stop,
  2 more on this build: ids 1..7 continuous, SQL rows a,b,c,d. Saved states are read correctly both ways.
- with tracing on, the SQL replay reused the live instance on 385 of 386 calls.

Profile of the SQL replay inside the jet (macOS `sample`):

| | keep-alive off | on |
|---|---|---|
| wasm actually running | 70% | 91% |
| wasm3 preparing code | 21% | 0% |
| Hoon script steps | 6% | 7% |
| loading state | 1% | 0% |

Time per request (median; the machine was busy with an unrelated job, so treat as indicative):

| workload | off | on |
|---|---|---|
| notes (814) | 2.33 ms | 1.49 ms |
| SQL (367) | 7.42 ms | 2.90 ms |
| poker (905) | 3.61 ms | 3.34 ms |
| one notes request, 5 steps (`+steps %all`) | 1.95 to 2.22 ms | 1.26 to 1.38 ms |
| same in the lean style (`%lean`) | 1.40 to 1.49 ms | 0.70 to 0.83 ms |

After this the SQL workload is 91% interpreter time: the remaining gap to Node there is wasm3 itself.
Not tested: the signal-abort reclaim; behaviour under real memory pressure; Windows (keep-alive is compiled out there).
Not reviewed by anyone else yet.

### Keep-alive: review fixes (2026-11-26)

Codex reviewed the keep-alive commit: two P1, two P2, all addressed (vere `urwasm-hot`, one commit, `patches/0004-*`).

- A live instance's wasm memory is now one fixed mmap reservation (256 MB) that grows in place, like its code. No pointer
  the slot holds can go stale, so reclaiming a slot abandoned by a signal abort cannot double-free.
- When a live instance outgrows its code or memory room mid-call, the jet catches it, drops the instance, winds the road's
  error trace back, and runs the call again the ordinary way (which has no such limit). The module is remembered and not
  tried live again in this process. Costs one repeated call (imports may run twice) and a small one-off leak in the road.
- If room for a new live instance cannot be reserved, the call just runs the ordinary way.
- The total kept is rechecked after every call, since memory can grow during one.

Checks after the fixes: upstream tests 48/48; stale-instance test all agree; notes 814, SQL 367, poker 905 identical to Node.
Forced fallback (test switch giving 64 KB of code room): 2,255 fallbacks taken, same results on all of the above, no bails or
faults. The fixes themselves are unreviewed.

### Keep-alive: second review round (2026-11-26)

Second Codex pass on `urwasm-hot`: one P1 and three P2, all addressed; the commit is now a5039eb's successor (one commit, `patches/0004-*`).

- The jet no longer calls `c3_rand` (defined in pkg/vere, so noun-only targets would not link). The per-process id comes from
  libent, which libnoun already links.
- The mid-call "outgrew its room, run again the ordinary way" path is gone, and with it the leaks Codex pointed out. Instead each
  live instance reserves address space for all the wasm memory a module can have (4 GiB) and all the code an arena can describe
  (just under 4 GiB). These are reservations, not memory in use.
- What is kept is limited by use: an instance whose memory passes 256 MB is dropped after its call, and the 512 MB total now
  counts compiled code as well as structs and memory.
- If the per-function scratch table cannot be allocated, the state is loaded the ordinary way instead of failing.

Checks: upstream tests 48/48; stale-instance test identical to keep-alive off; notes 814, SQL 367, poker 905 identical to Node;
rustmod sequence identical to Node, including one that grows memory by 300 MB mid-run (so the instance is dropped and later
calls load from the saved state). No bails or faults.
On a quieter machine: notes 814 requests in 1.01 s (original runtime 5.04 s), SQL 367 in 3.69 s (9.01 s), poker 905 in 2.23 s.

### Keep-alive: third review round (2026-11-27)

Third Codex pass on `urwasm-hot`: one P1 and two P2, all addressed in a second commit on the branch (50612c5, `patches/0005-*`).

- A live instance has room for almost 4 GiB of code, an ordinary load for 1 GiB (`UW_CODE_MAX`). A computation that suspended with
  more code than an ordinary load can rebuild could be saved and then fail to load once its live instance was dropped. Such a state
  is now not saved, exactly like one whose code spilled: the next call recomputes from the seed.
- What an instance holds now includes its per-function scratch table and its compile-order buffer.
- `_uw_hot_take` drops nothing when the new instance cannot fit beside the instances in use (or alone): it returns NULL first.

Checks on the test build (`urwasm-hot-test`), plain and with `URWASM_BIG=1`, a test-only switch that sends every suspended live
state down the "too much code" path:

| | plain | `URWASM_BIG=1` |
|---|---|---|
| upstream wasm tests | 48/48, same as original | 48/48, same as original |
| `+hot-test` | all agree, identical to keep-alive off | all agree, identical to keep-alive off |
| rustmod sequence | matches Node | matches Node |
| notes, 814 requests | 0 different, 947 ms | 0 different, 962 ms |
| SQL, 367 requests | 0 different, 3470 ms | 0 different, 42321 ms |
| poker, 905 requests | 0 different, 2136 ms | 0 different, 2140 ms |
| forced drops / bails / faults | 0 / 0 / 0 | 22 / 0 / 0 |

The forced run is slow for SQL because each dropped state is recomputed from the seed; it is there to show the answers stay right.

### Keep-alive: fourth review round, at high reasoning effort (2026-11-27)

The first three Codex passes ran at the config default, `model_reasoning_effort = "low"` (gpt-6.2-astra). A fourth pass at `high`
(`codex review --base urwasm-fast-clean -c 'model_reasoning_effort="high"'`) found one P1 and five P2 that the low passes had missed.
All six are addressed in a third commit on `urwasm-hot` (5fc5ec7, `patches/0006-*`), written by Claude Opus 5.5 and checked here.

- Signal aborts (P1). SIGINT, SIGTERM and SIGVTALRM longjmp out of whatever is running, straight to `u3m_soft_top`. They are now
  blocked (`pthread_sigmask`, nestable `_uw_hot_hold`/`_uw_hot_move`) around every malloc/free/munmap of live-instance state and
  while a slot changes hands, and `_uw_hot_free` makes a slot unmatchable and forgets its buffers before freeing them.
- Abandoned running slots. The stack-address guess is gone. `u3m_soft_top`'s signal recovery calls a new `u3we_lia_reap()`, which
  frees every slot that is not ready. This is the one change outside `urwasm.c` (6 lines in `manage.c`, 1 in `jets/w.h`): only the
  recovery point knows that every running slot is abandoned.
- Entropy. The per-process id part is made at admission; if `ent_getentropy` fails no ids are issued and calls load the ordinary way.
- Linux commit. Both reservations are mapped `PROT_NONE` and opened with `mprotect` in 1 MiB steps as they fill. Refusal before the
  call runs takes the ordinary path; refusal while wasm runs bails `%meme` (never a failed `memory.grow`).
- Compile-order buffer. A live instance gets room for every function up front, with its scratch table and first memory, so failure
  there takes the ordinary path.
- An instance too big to keep beside the running ones is dropped before trimming the others.

Checks on `urwasm-hot-test`, run independently after the subagent's own run:

| | plain | `URWASM_BIG=1` |
|---|---|---|
| upstream wasm tests | 48/48, same as original | 48/48, same as original |
| `+hot-test` | all agree, identical to keep-alive off | all agree, identical to keep-alive off |
| rustmod sequence | matches Node | matches Node |
| notes, 814 requests | 0 different, 1027 ms | 0 different, 1033 ms |
| SQL, 367 requests | 0 different, 3816 ms | 0 different, 43868 ms |
| poker, 905 requests | 0 different, 2231 ms | 0 different, 2209 ms |
| bails / faults | 0 / 0 | 0 / 0 |

- rustmod with a 300 MB `memory.grow` mid-run: matches Node; the instance is dropped afterwards ("drop self").
- Interrupts: `kill -INT` to the `urbit work` process during SQL and poker runs, 8 times: 8 `recover: dig: intr`, 8 reaps, same
  worker pid, then notes 814 / SQL 367 / poker 905 all 0 different on that worker, no bails or faults. (The subagent's own run: 29
  aborts with SIGINT and SIGVTALRM, same outcome; forced entropy failure, order-buffer failure and pre-call commit refusal all took
  the ordinary path with 0 different; forced mid-call commit refusal bailed `%meme` and the worker kept serving.)

Not tested: any Linux run (only an aarch64-linux-musl cross-compile; the commit behaviour the change is for has not been observed),
a signal landing inside a held section, a stack overflow inside one, code-commit refusal while an instance is being built, and
Windows (keep-alive is compiled out there; checked only by compiling with the block disabled).

### Keep-alive: fifth review round, at high reasoning effort (2026-11-27)

A second Codex pass at `high` over the whole branch, including the fourth round's fixes, found one P1, five P2 and one P3. All
seven are addressed in a fourth commit on `urwasm-hot` (a16e285, `patches/0007-*`).

- Signals on other threads (P1). `pthread_sigmask` holds a signal off on the calling thread only. A signal sent to the process
  during a hold is delivered to another thread instead (the worker has libuv's pool, used for disk commits), and that thread's
  handler would `siglongjmp` to `u3_Signal`, which is a place on the event thread's stack. `_cm_signal_deep` now records the event
  thread, and the SIGINT, SIGTERM and SIGVTALRM handlers pass a signal that arrives anywhere else to it with `pthread_kill` and
  return (`_cm_signal_pass`, 36 lines in `manage.c`). This is what the Windows `rsignal_longjmp` already does. The jump from
  another thread was possible before keep-alive whenever the kernel picked a pool thread; the holds made it certain.
- Stack overflow while emptying a slot. The hold does not stop that one. `_uw_hot_free` marks the slot (state 3), unmaps each
  mapping and only then forgets it, and forgets each heap block before freeing it. A jump out leaves the mappings for
  `u3we_lia_reap()` to finish; a heap block caught mid-free is lost rather than freed twice.
- Refused commit with idle instances. `_uw_hot_open` drops ready instances, least recently used first, and retries the `mprotect`
  before giving up. Only then does a call fall back (before it runs) or bail `%meme` (while wasm runs).
- Budget. `_uw_hot_size` counts wasm memory and code as far as they were opened (`mec_d`, `com_d`), not as far as they are in use.
  The per-module limit still goes by the logical length.
- Sizing before eviction. There are now `UW_HOT + 1` slots, so one is always free to build in. `_uw_hot_take` evicts nothing.
  `_get_state` computes what the instance takes once the image is unpacked (struct image, scratch and order tables, memory, and
  the code a suspended computation needs rebuilt) and calls `_uw_hot_fit` before any of it is committed: the others make way only
  if that is enough, otherwise the call loads the ordinary way.
- Emptied memo cache. `u3we_lia_wipe()` drops ready instances at the three places the persistent cache is replaced: `_mars_post`
  at threshold 0, `u3_melt_all` with `u3_melt_memo`, and `u3u_melt` (one line each, plus the include).
- The saved image goes into a `u3i_slab_bare` slab with only its last word cleared (P3).

Checks on `urwasm-hot-test` (`bench/chk.sh`, then `bench/sig5.sh` and `bench/chk5.sh` for the new paths):

| | plain | `URWASM_BIG=1` |
|---|---|---|
| upstream wasm tests | 48/48, same as original | 48/48, same as original |
| `+hot-test` | all agree, identical to keep-alive off | all agree, identical to keep-alive off |
| rustmod sequence | matches Node | matches Node |
| notes, 814 requests | 0 different, 913 ms | 0 different, 916 ms |
| SQL, 367 requests | 0 different, 3353 ms | 0 different, 40127 ms |
| poker, 905 requests | 0 different, 2033 ms | 0 different, 2068 ms |
| bails / faults | 0 / 0 | 0 / 0 |

- Signal during a hold (`sig5.sh`): the test build naps 2.5 s inside the admission hold and `kill -INT` goes to the worker 0.3 s
  in. With the fix: 6 sent, 6 delivered to another thread, 6 passed on, each arriving after the hold ended (reap saw hold 0 and one
  running slot), 6 `recover: dig: intr`, same worker pid, then SQL 367 with 0 different. With the handlers as they were
  (`URWASM_NOPASS`): the first one killed the worker (`Assertion '0' failed` in `manage.c`, "pier: serf unexpectedly shut down").
- Refused commit (`URWASM_OPENBUSY`: every open fails while a ready instance exists): notes, SQL, poker, notes, SQL in one worker,
  all 0 different, 4 idle instances dropped, no event failed.
- Sizing (`URWASM_FITLOG`): over the upstream tests and the three workloads 29 instances were sized and 9 were dropped by count or
  budget. Of 19 price/held pairs, 17 were equal and 2 held 1 MiB more after a call that grew. With every fit refused
  (`URWASM_FITMAX=1000`): 386 refusals, nothing dropped for them, SQL 0 different.
- Wipe: `|meld, =memo &` after an SQL run released the one ready instance (worker address space down by 7.9 GiB); the next SQL run
  was 0 different.
- Overflow mid-free (`URWASM_FREEOVER`, a `u3m_signal(c3__over)` after the slot is marked): the reap found one half-emptied slot
  with its mappings and left none; the next SQL run was 0 different.

Not tested: any Linux run (cross-compile only), a real stack overflow inside `free()` (only the simulated jump), the `_mars_post`
threshold-0 and `u3u_melt` call sites of the wipe (the `u3_melt_all` one was), Windows.
