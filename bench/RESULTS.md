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
