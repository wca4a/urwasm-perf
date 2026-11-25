// usage: node node-notes.mjs notes.wasm notes-work.txt [responses-out.txt]
// prints JSON [[responseLength, first8BytesOfSha256AsLEnumber(string), ms, op], ...]
import fs from 'fs'; import crypto from 'crypto';
const {instance:{exports:e}} = await WebAssembly.instantiate(fs.readFileSync(process.argv[2]), {});
const out = [], texts = [];
for (const line of fs.readFileSync(process.argv[3], 'utf8').split('\n')) {
  if (!line) continue;
  const req = Buffer.from(line, 'utf8'), t = performance.now();
  const p = e.request(req.length) >>> 0;
  new Uint8Array(e.memory.buffer).set(req, p);
  const n = e.handle(req.length) >>> 0, q = e.response() >>> 0;
  const res = Buffer.from(new Uint8Array(e.memory.buffer, q, n));
  const ms = performance.now() - t;
  let op = 'bad'; try { op = JSON.parse(line).op } catch {}
  out.push([n, crypto.createHash('sha256').update(res).digest().readBigUInt64LE(0).toString(), ms, op]);
  texts.push(res.toString('utf8'));
}
if (process.argv[4]) fs.writeFileSync(process.argv[4], texts.join('\n') + '\n');
console.log(JSON.stringify(out));
console.error('memory MB', e.memory.buffer.byteLength / 1048576);
