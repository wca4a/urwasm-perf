#!/usr/bin/env python3
"""Hand-assemble a small Wasm module for benchmarking.

usage: mkwasm.py PAGES FILLERS OUT.wasm

Exports:
  nop()        -> i32   returns 1 (measures pure per-call overhead)
  spin(n)      -> i32   n-iteration loop (measures engine speed)
  touch(addr)  -> i32   increments the i32 at addr, returns it (proves state)
PAGES   = initial linear memory, in 64 KiB pages
FILLERS = number of extra never-called functions (scales code size)
"""
import sys


def leb(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def vec(items):
    return leb(len(items)) + b"".join(items)


def section(i, body):
    return bytes([i]) + leb(len(body)) + body


def name(s):
    b = s.encode()
    return leb(len(b)) + b


def body(locals_, code):
    b = locals_ + code
    return leb(len(b)) + b


def module(pages, fillers):
    types = vec([b"\x60\x00\x01\x7f", b"\x60\x01\x7f\x01\x7f"])
    funcs = vec([b"\x00", b"\x01", b"\x01"] + [b"\x01"] * fillers)
    mem = vec([b"\x00" + leb(pages)])
    exports = vec([
        name("nop") + b"\x00\x00",
        name("spin") + b"\x00\x01",
        name("touch") + b"\x00\x02",
    ])
    nop = body(b"\x00", b"\x41\x01\x0b")
    spin = body(
        b"\x01\x01\x7f",
        bytes.fromhex(
            "0240 0340"
            "2000 45 0d01"
            "2001 2000 6a 2101"
            "2000 4101 6b 2100"
            "0c00 0b 0b"
            "2001 0b"
        ),
    )
    touch = body(
        b"\x00",
        bytes.fromhex("2000 2000 280200 4101 6a 360200 2000 280200 0b"),
    )
    fill = body(b"\x00", b"\x20\x00" + bytes.fromhex("4107 6c 4103 6a") * 8 + b"\x0b")
    code = vec([nop, spin, touch] + [fill] * fillers)
    return (
        b"\x00asm\x01\x00\x00\x00"
        + section(1, types)
        + section(3, funcs)
        + section(5, mem)
        + section(7, exports)
        + section(10, code)
    )


if __name__ == "__main__":
    pages, fillers, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    data = module(pages, fillers)
    with open(out, "wb") as f:
        f.write(data)
    print(f"{out}: {len(data)} bytes, {pages} pages, {fillers} fillers")
