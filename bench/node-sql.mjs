// usage: node node-sql.mjs sqlapp.wasm sql-work.txt [responses-out.txt]
// prints JSON [[responseLength, first8BytesOfSha256AsLEnumber(string), ms, kind, hostCalls], ...]
import fs from 'fs'; import crypto from 'crypto';
export const NOW = 1795608000000n, ENTROPY = 0x123456789abcdef0n;   // the ship test uses the same two values
let calls = 0;
const env = { ship_now: () => (calls++, NOW), ship_entropy: () => (calls++, ENTROPY) };
const {instance:{exports:e}} = await WebAssembly.instantiate(fs.readFileSync(process.argv[2]), {env});
const out = [], texts = [];
for (const line of fs.readFileSync(process.argv[3], 'utf8').split('\n')) {
  if (!line) continue;
  const req = Buffer.from(line, 'utf8'), t = performance.now(); calls = 0;
  const p = e.request(req.length) >>> 0;
  new Uint8Array(e.memory.buffer).set(req, p);
  const n = e.handle(req.length) >>> 0, q = e.response() >>> 0;
  const res = Buffer.from(new Uint8Array(e.memory.buffer, q, n));
  out.push([n, crypto.createHash('sha256').update(res).digest().readBigUInt64LE(0).toString(), performance.now() - t, (calls ? 'needs ship: ' : '') + line.trim().split(/\s+/)[0].toUpperCase(), calls]);
  texts.push(res.toString('utf8'));
}
if (process.argv[4]) fs.writeFileSync(process.argv[4], texts.join('\n') + '\n');
console.log(JSON.stringify(out));
console.error('memory MB', e.memory.buffer.byteLength / 1048576, 'requests that called the host', out.filter(x => x[4]).length);
