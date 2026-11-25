// sqlapp: SQLite as a Wasm program with no operating system underneath.
//
// One request in (SQL text, any number of statements), one response out (JSON).
// The database lives in Wasm memory between calls.
//
// Host protocol:
//   ptr = request(len)    reserve len bytes for the SQL text
//   (host writes the SQL at ptr)
//   n   = handle(len)     run it; returns the response length
//   ptr = response()      where the response text is
//
// The program asks its host for two things it cannot know by itself:
//   env.ship_now()        the time, in milliseconds since 1970
//   env.ship_entropy()    64 random bits (asked once, to seed SQLite's generator)
#include "sqlite3.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define IMPORT(name) __attribute__((import_module("env"), import_name(name)))
#define EXPORT(name) __attribute__((export_name(name)))
IMPORT("ship_now") extern long long ship_now(void);
IMPORT("ship_entropy") extern long long ship_entropy(void);

// ---- the "operating system" SQLite sees: no files, host-provided time and randomness
static int vOpen(sqlite3_vfs *v, const char *n, sqlite3_file *f, int fl, int *o) { return SQLITE_CANTOPEN; }
static int vDelete(sqlite3_vfs *v, const char *n, int s) { return SQLITE_OK; }
static int vAccess(sqlite3_vfs *v, const char *n, int fl, int *out) { *out = 0; return SQLITE_OK; }
static int vFullPathname(sqlite3_vfs *v, const char *n, int nOut, char *out) { sqlite3_snprintf(nOut, out, "%s", n); return SQLITE_OK; }
static int vRandomness(sqlite3_vfs *v, int n, char *out) {
  unsigned long long x = (unsigned long long)ship_entropy();
  for (int i = 0; i < n; i++) {
    if ((i & 7) == 0) { x += 0x9e3779b97f4a7c15ull; unsigned long long z = x;
      z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ull; z = (z ^ (z >> 27)) * 0x94d049bb133111ebull; x = z ^ (z >> 31); }
    out[i] = (char)(x >> ((i & 7) * 8));
  }
  return n;
}
static int vSleep(sqlite3_vfs *v, int us) { return us; }
static int vCurrentTimeInt64(sqlite3_vfs *v, sqlite3_int64 *out) { *out = ship_now() + 210866760000000ll; return SQLITE_OK; }
static int vCurrentTime(sqlite3_vfs *v, double *out) { sqlite3_int64 t; vCurrentTimeInt64(v, &t); *out = t / 86400000.0; return SQLITE_OK; }
static sqlite3_vfs ship_vfs = {
  2, 8, 256, 0, "ship", 0, vOpen, vDelete, vAccess, vFullPathname, 0, 0, 0, 0, vRandomness, vSleep, vCurrentTime, 0, vCurrentTimeInt64
};
int sqlite3_os_init(void) { return sqlite3_vfs_register(&ship_vfs, 1); }
int sqlite3_os_end(void) { return SQLITE_OK; }

// ---- request and response buffers
static char *inbuf; static unsigned incap;
static char *out; static unsigned outlen, outcap;
static sqlite3 *db;

static void put(const char *s, unsigned n) {
  if (outlen + n + 1 > outcap) { outcap = (outlen + n + 1) * 2; out = realloc(out, outcap); }
  memcpy(out + outlen, s, n); outlen += n;
}
static void puts_(const char *s) { put(s, (unsigned)strlen(s)); }
static void put_json_string(const char *s, int n) {
  static const char hex[] = "0123456789abcdef";
  put("\"", 1);
  for (int i = 0; i < n; i++) {
    unsigned char c = (unsigned char)s[i];
    if (c == '"') put("\\\"", 2); else if (c == '\\') put("\\\\", 2);
    else if (c == '\n') put("\\n", 2); else if (c == '\r') put("\\r", 2); else if (c == '\t') put("\\t", 2);
    else if (c < 0x20) { char u[6] = {'\\', 'u', '0', '0', hex[c >> 4], hex[c & 15]}; put(u, 6); }
    else put((const char *)&c, 1);
  }
  put("\"", 1);
}
static void put_value(sqlite3_stmt *st, int i) {
  char num[64];
  switch (sqlite3_column_type(st, i)) {
    case SQLITE_INTEGER: sqlite3_snprintf(sizeof num, num, "%lld", sqlite3_column_int64(st, i)); puts_(num); break;
    case SQLITE_FLOAT: { double d = sqlite3_column_double(st, i);
      if (isfinite(d)) { sqlite3_snprintf(sizeof num, num, "%!.15g", d); puts_(num); } else puts_("null"); break; }
    case SQLITE_TEXT: put_json_string((const char *)sqlite3_column_text(st, i), sqlite3_column_bytes(st, i)); break;
    case SQLITE_BLOB: { const unsigned char *b = sqlite3_column_blob(st, i); int n = sqlite3_column_bytes(st, i);
      static const char hex[] = "0123456789abcdef"; put("\"x'", 3);
      for (int k = 0; k < n; k++) { char h[2] = {hex[b[k] >> 4], hex[b[k] & 15]}; put(h, 2); }
      put("'\"", 2); break; }
    default: puts_("null");
  }
}

EXPORT("request") char *request(unsigned len) {
  if (len + 1 > incap) { incap = len + 1; inbuf = realloc(inbuf, incap); }
  return inbuf;
}

#define ROW_LIMIT 500
EXPORT("handle") unsigned handle(unsigned len) {
  char num[96]; const char *err = 0; int first = 1;
  outlen = 0; inbuf[len] = 0;
  if (!db && sqlite3_open(":memory:", &db) != SQLITE_OK) { puts_("{\"results\":[],\"error\":\"could not open database\"}"); return outlen; }
  puts_("{\"results\":[");
  for (const char *sql = inbuf; *sql && !err;) {
    sqlite3_stmt *st = 0; const char *tail = 0;
    if (sqlite3_prepare_v2(db, sql, -1, &st, &tail) != SQLITE_OK) { err = sqlite3_errmsg(db); break; }
    sql = tail;
    if (!st) continue;                         // blank space or a comment
    int ncol = sqlite3_column_count(st), rc; unsigned rows = 0;
    if (!first) put(",", 1); first = 0;
    puts_("{\"columns\":[");
    for (int i = 0; i < ncol; i++) { if (i) put(",", 1); const char *n = sqlite3_column_name(st, i); put_json_string(n, (int)strlen(n)); }
    puts_("],\"rows\":[");
    while ((rc = sqlite3_step(st)) == SQLITE_ROW) {
      if (rows++ >= ROW_LIMIT) continue;
      if (rows > 1) put(",", 1);
      put("[", 1);
      for (int i = 0; i < ncol; i++) { if (i) put(",", 1); put_value(st, i); }
      put("]", 1);
    }
    if (rc != SQLITE_DONE) err = sqlite3_errmsg(db);
    sqlite3_snprintf(sizeof num, num, "],\"count\":%u,\"changes\":%d}", rows, sqlite3_stmt_readonly(st) ? 0 : sqlite3_changes(db)); puts_(num);
    if (err) { puts_("],\"error\":"); put_json_string(err, (int)strlen(err)); put("}", 1); sqlite3_finalize(st); return outlen; }
    sqlite3_finalize(st);
  }
  puts_("],\"error\":");
  if (err) put_json_string(err, (int)strlen(err)); else puts_("null");
  put("}", 1);
  return outlen;
}

EXPORT("response") const char *response(void) { return out; }
