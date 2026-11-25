//! A small but realistic stateful Rust module for benchmarking urwasm.
//! Ordinary std Rust: heap allocation, HashMap, BTreeMap, String formatting,
//! sorting, and a hand-written SHA-256. No imports from the host.
use std::cell::RefCell;
use std::collections::{BTreeMap, HashMap};

struct Store {
    calls: u32,
    notes: HashMap<u32, String>,
    index: BTreeMap<String, u32>,
    blobs: Vec<Vec<u8>>,
}

thread_local! {
    static STORE: RefCell<Store> = RefCell::new(Store {
        calls: 0,
        notes: HashMap::new(),
        index: BTreeMap::new(),
        blobs: Vec::new(),
    });
}

fn sum(s: &str) -> u32 {
    s.bytes().fold(2166136261u32, |h, b| (h ^ b as u32).wrapping_mul(16777619))
}

/// Count calls. Proves state survives between calls.
#[no_mangle]
pub extern "C" fn tick() -> u32 {
    STORE.with(|s| {
        let mut s = s.borrow_mut();
        s.calls += 1;
        s.calls
    })
}

/// Store a formatted note under key k; returns number of notes held.
#[no_mangle]
pub extern "C" fn put(k: u32) -> u32 {
    STORE.with(|s| {
        let mut s = s.borrow_mut();
        let text = format!("note #{k}: {:08x} / {:.3}", k.wrapping_mul(2654435761), k as f64 / 7.0);
        s.index.insert(text.clone(), k);
        s.notes.insert(k, text);
        s.notes.len() as u32
    })
}

/// Read a note back; returns a checksum of its text (0 if missing).
#[no_mangle]
pub extern "C" fn get(k: u32) -> u32 {
    STORE.with(|s| s.borrow().notes.get(&k).map(|t| sum(t)).unwrap_or(0))
}

/// Insert n notes in one call; returns number of notes held.
#[no_mangle]
pub extern "C" fn fill(n: u32) -> u32 {
    let mut r = 0;
    let base = STORE.with(|s| s.borrow().notes.len() as u32);
    for i in 0..n {
        r = put(base + i);
    }
    r
}

/// Walk the whole ordered index; returns a checksum over every entry.
#[no_mangle]
pub extern "C" fn scan() -> u32 {
    STORE.with(|s| {
        s.borrow().index.iter().fold(0u32, |a, (t, k)| a.rotate_left(5) ^ sum(t) ^ *k)
    })
}

/// Hold on to another kb kilobytes of non-zero data; returns total KB held.
#[no_mangle]
pub extern "C" fn grow(kb: u32) -> u32 {
    STORE.with(|s| {
        let mut s = s.borrow_mut();
        let n = s.blobs.len() as u8;
        s.blobs.push((0..kb as usize * 1024).map(|i| (i as u8) ^ n | 1).collect());
        (s.blobs.iter().map(|b| b.len()).sum::<usize>() / 1024) as u32
    })
}

/// Sort n pseudo-random numbers; returns a checksum of the sorted order.
#[no_mangle]
pub extern "C" fn sort(n: u32) -> u32 {
    let mut x = 0x9e3779b9u32;
    let mut v: Vec<u32> = (0..n)
        .map(|_| {
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            x
        })
        .collect();
    v.sort_unstable();
    v.iter().enumerate().fold(0u32, |a, (i, e)| a.wrapping_add(e ^ i as u32))
}

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

fn compress(h: &mut [u32; 8], block: &[u8; 64]) {
    let mut w = [0u32; 64];
    for i in 0..16 {
        w[i] = u32::from_be_bytes([block[4 * i], block[4 * i + 1], block[4 * i + 2], block[4 * i + 3]]);
    }
    for i in 16..64 {
        let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
        let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16].wrapping_add(s0).wrapping_add(w[i - 7]).wrapping_add(s1);
    }
    let mut a = *h;
    for i in 0..64 {
        let s1 = a[4].rotate_right(6) ^ a[4].rotate_right(11) ^ a[4].rotate_right(25);
        let ch = (a[4] & a[5]) ^ (!a[4] & a[6]);
        let t1 = a[7].wrapping_add(s1).wrapping_add(ch).wrapping_add(K[i]).wrapping_add(w[i]);
        let s0 = a[0].rotate_right(2) ^ a[0].rotate_right(13) ^ a[0].rotate_right(22);
        let maj = (a[0] & a[1]) ^ (a[0] & a[2]) ^ (a[1] & a[2]);
        let t2 = s0.wrapping_add(maj);
        a = [t1.wrapping_add(t2), a[0], a[1], a[2], a[3].wrapping_add(t1), a[4], a[5], a[6]];
    }
    for i in 0..8 {
        h[i] = h[i].wrapping_add(a[i]);
    }
}

/// SHA-256 chained n times over one block; returns the first word.
/// hash(1) hashes the 55-byte message "aaaa...a" padded, a checkable value.
#[no_mangle]
pub extern "C" fn hash(n: u32) -> u32 {
    let mut block = [b'a'; 64];
    block[55] = 0x80;
    for b in &mut block[56..] {
        *b = 0;
    }
    block[62] = 0x01;
    block[63] = 0xb8;
    let mut out = 0;
    for _ in 0..n {
        let mut h: [u32; 8] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ];
        compress(&mut h, &block);
        out = h[0];
        for i in 0..8 {
            block[4 * i..4 * i + 4].copy_from_slice(&h[i].to_be_bytes());
        }
    }
    out
}
