# Draft: private security report for urbit/vere

**Title:** Out-of-bounds write in wasm3 call compilation lets a Wasm module crash the runtime

## Summary

A Wasm module can make vere write past the end of a fixed-size array while
compiling it, which corrupts interpreter state and crashes the process
(`loom: external fault`). Any ship that runs a Wasm module it did not write is
exposed. The bug is in the wasm3 fork vere pins
(urbit/wasm3 at 268894556ac471c88089d88c84b7922c8d9b9d72), reached through the
urwasm jets in `pkg/noun/jets/e/urwasm.c`.

I am reporting it here because urbit/wasm3 has no issue tracker or private
reporting enabled.

## Details

`CompileCallArgsAndReturn` in `source/m3_compile.c` places a callee's arguments
and results above every slot currently in use, then marks the result slots in
`o->m3Slots` (size `d_m3MaxFunctionSlots`, 4000) without checking the index.

A function body that makes a long chain of calls, each one consuming the
previous call's result, raises `topSlot` by two per call. After roughly 2,000
such calls the index passes 4000 and the writes land in the rest of
`M3Compilation` and in the `M3Runtime` that embeds it, including the code page
lists. The next code page lookup then faults.

The other slot allocators in the same file already refuse with
`m3Err_functionStackOverflow`; this path does not.

## Reproduction

- A module with one function that calls another function about 3,000 times in
  a chain (each call takes the previous result) crashes a ship on first load
  through `run:wasm`, in `EnsureCodePageNumLines` / `RemoveCodePageOfCapacity`.
- A standalone wasm3 build with ASan/UBSan reports
  `index 4000 out of bounds for type 'u8[4000]'` at the marking loop.
- The threshold on this build: a chain of 1,997 calls compiles and runs; 1,998
  overflows.

I can share the test modules and the standalone reproducer.

## Impact

Demonstrated: reliable crash of the runtime process from a Wasm module supplied
as data. It is a memory-corrupting write, so I have not ruled out worse than a
crash; I did not investigate that.

It is independent of any other change: it reproduces on unmodified vere develop.

## Suggested fix

One bounds check before the frame is laid out (6 lines, patch available):

```c
_throwif (m3Err_functionStackOverflow,
          (u32) topSlot + ((u32) numArgs + numRets) * c_ioSlotCount > d_m3MaxFunctionSlots);
```

With it, the 1,997-call chain still runs, 1,998 and above are refused with a
compile error, and a function with 10,000 unchained calls is unaffected. On a
ship the offending command fails with "compiling function overran its stack
height limit" and the ship stays up.

I have not checked whether upstream wasm3 (wasm3/wasm3) has the same bug.

## Reporter

William Arzt (wca4a), Tlon. Found while benchmarking urwasm; diagnosis and patch
prepared with Claude Code.
