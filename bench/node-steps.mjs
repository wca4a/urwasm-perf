// usage: node node-steps.mjs MODULE.wasm '<json steps>'   -> prints [fn, lastResult, msPerCall] per step
import fs from 'fs';
const {instance:{exports:e}} = await WebAssembly.instantiate(fs.readFileSync(process.argv[2]), {});
const out = [];
for (const [fn, n, args] of JSON.parse(process.argv[3])) {
  let r; const a = performance.now();
  for (let i = 0; i < n; i++) r = e[fn](...(args === 'i' ? [i] : args));
  out.push([fn, r >>> 0, (performance.now() - a) / n]);
}
console.log(JSON.stringify(out));
