//! notes: a small notes backend, the kind of thing an app would actually ship.
//!
//! One request in (JSON text), one response out (JSON text). The app keeps its
//! notes, a full-text search index and tag counts in ordinary Rust collections
//! that live in Wasm memory between calls.
//!
//! Host protocol:
//!   ptr = request(len)    reserve len bytes for the request text
//!   (host writes the request at ptr)
//!   n   = handle(len)     run it; returns the response length
//!   ptr = response()      where the response text is
use pulldown_cmark::{html, Options, Parser};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::cell::RefCell;
use std::collections::BTreeMap;

#[derive(Serialize, Clone)]
struct Note {
    id: u32,
    title: String,
    body: String,
    tags: Vec<String>,
    rev: u32,
    words: u32,
    digest: String,
}

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "lowercase")]
enum Req {
    Add { title: String, body: String, #[serde(default)] tags: Vec<String> },
    Get { id: u32 },
    Render { id: u32 },
    Search { q: String, #[serde(default)] limit: Option<usize> },
    Edit { id: u32, body: String },
    Delete { id: u32 },
    Tags,
    Stats,
    Export,
}

#[derive(Default)]
struct App {
    notes: BTreeMap<u32, Note>,
    /// word -> note id -> how many times the word appears in that note
    index: BTreeMap<String, BTreeMap<u32, u32>>,
    next: u32,
    served: u64,
    inbuf: Vec<u8>,
    outbuf: Vec<u8>,
}

fn words(text: &str) -> impl Iterator<Item = String> + '_ {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|w| w.chars().count() >= 2)
        .map(|w| w.to_lowercase())
}

fn digest(title: &str, body: &str) -> String {
    let mut h = Sha256::new();
    h.update(title.as_bytes());
    h.update([0u8]);
    h.update(body.as_bytes());
    h.finalize().iter().take(8).map(|b| format!("{:02x}", b)).collect()
}

fn snippet(body: &str, term: &str) -> String {
    let lower = body.to_lowercase();
    let at = lower.find(term).unwrap_or(0);
    let mut start = at.saturating_sub(30).min(body.len());
    while !body.is_char_boundary(start) { start -= 1; }
    body[start..].chars().take(90).collect::<String>().replace('\n', " ")
}

impl App {
    fn index_note(&mut self, id: u32, title: &str, body: &str) -> u32 {
        let mut n = 0;
        for w in words(title).chain(words(body)) {
            *self.index.entry(w).or_default().entry(id).or_insert(0) += 1;
            n += 1;
        }
        n
    }

    fn unindex_note(&mut self, id: u32, title: &str, body: &str) {
        for w in words(title).chain(words(body)) {
            let gone = match self.index.get_mut(&w) {
                Some(posting) => { posting.remove(&id); posting.is_empty() }
                None => false,
            };
            if gone { self.index.remove(&w); }
        }
    }

    fn run(&mut self, req: Req) -> Value {
        match req {
            Req::Add { title, body, tags } => {
                self.next += 1;
                let id = self.next;
                let words = self.index_note(id, &title, &body);
                let digest = digest(&title, &body);
                self.notes.insert(id, Note { id, title, body, tags, rev: 1, words, digest: digest.clone() });
                json!({"ok": true, "id": id, "words": words, "digest": digest})
            }
            Req::Get { id } => match self.notes.get(&id) {
                Some(n) => json!({"ok": true, "note": n}),
                None => json!({"ok": false, "error": "no such note", "id": id}),
            },
            Req::Render { id } => match self.notes.get(&id) {
                Some(n) => {
                    let mut out = String::with_capacity(n.body.len() * 3 / 2);
                    html::push_html(&mut out, Parser::new_ext(&n.body, Options::all()));
                    json!({"ok": true, "id": id, "bytes": out.len(), "html": out})
                }
                None => json!({"ok": false, "error": "no such note", "id": id}),
            },
            Req::Search { q, limit } => {
                let terms: Vec<String> = words(&q).collect();
                let mut score: BTreeMap<u32, (u32, u64)> = BTreeMap::new();
                for t in &terms {
                    if let Some(posting) = self.index.get(t) {
                        for (id, count) in posting {
                            let len = self.notes[id].words as u64;
                            let e = score.entry(*id).or_insert((0, 0));
                            e.0 += 1;
                            e.1 += (*count as u64) * 100_000 / (len + 50);
                        }
                    }
                }
                // a note must contain every search word
                let mut hits: Vec<(u64, u32)> = score.into_iter()
                    .filter(|(_, (n, _))| *n as usize == terms.len() && !terms.is_empty())
                    .map(|(id, (_, s))| (s, id)).collect();
                hits.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
                let total = hits.len();
                let top: Vec<Value> = hits.into_iter().take(limit.unwrap_or(10)).map(|(s, id)| {
                    let n = &self.notes[&id];
                    json!({"id": id, "score": s, "title": n.title, "snippet": snippet(&n.body, &terms[0])})
                }).collect();
                json!({"ok": true, "total": total, "hits": top})
            }
            Req::Edit { id, body } => match self.notes.get(&id).cloned() {
                Some(old) => {
                    self.unindex_note(id, &old.title, &old.body);
                    let words = self.index_note(id, &old.title, &body);
                    let digest = digest(&old.title, &body);
                    let n = self.notes.get_mut(&id).unwrap();
                    n.body = body; n.rev += 1; n.words = words; n.digest = digest.clone();
                    json!({"ok": true, "id": id, "rev": n.rev, "words": words, "digest": digest})
                }
                None => json!({"ok": false, "error": "no such note", "id": id}),
            },
            Req::Delete { id } => match self.notes.remove(&id) {
                Some(old) => {
                    self.unindex_note(id, &old.title, &old.body);
                    json!({"ok": true, "id": id, "left": self.notes.len()})
                }
                None => json!({"ok": false, "error": "no such note", "id": id}),
            },
            Req::Tags => {
                let mut tags: BTreeMap<&str, u32> = BTreeMap::new();
                for n in self.notes.values() { for t in &n.tags { *tags.entry(t).or_insert(0) += 1; } }
                json!({"ok": true, "tags": tags})
            }
            Req::Stats => {
                let bytes: usize = self.notes.values().map(|n| n.body.len()).sum();
                let postings: usize = self.index.values().map(|p| p.len()).sum();
                json!({"ok": true, "notes": self.notes.len(), "bytes": bytes,
                       "distinct_words": self.index.len(), "postings": postings, "served": self.served})
            }
            Req::Export => json!({"ok": true, "notes": self.notes.values().collect::<Vec<_>>()}),
        }
    }
}

thread_local! { static APP: RefCell<App> = RefCell::new(App::default()); }

#[no_mangle]
pub extern "C" fn request(len: u32) -> *mut u8 {
    APP.with(|a| { let mut a = a.borrow_mut(); a.inbuf.resize(len as usize, 0); a.inbuf.as_mut_ptr() })
}

#[no_mangle]
pub extern "C" fn handle(len: u32) -> u32 {
    APP.with(|a| {
        let mut a = a.borrow_mut();
        a.served += 1;
        let input = std::mem::take(&mut a.inbuf);
        let reply = match serde_json::from_slice::<Req>(&input[..len as usize]) {
            Ok(req) => a.run(req),
            Err(e) => json!({"ok": false, "error": e.to_string()}),
        };
        a.inbuf = input;
        a.outbuf = serde_json::to_vec(&reply).unwrap();
        a.outbuf.len() as u32
    })
}

#[no_mangle]
pub extern "C" fn response() -> *const u8 {
    APP.with(|a| a.borrow().outbuf.as_ptr())
}
