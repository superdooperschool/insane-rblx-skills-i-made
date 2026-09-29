#!/usr/bin/env node
// rbx-economy/scripts/curve.mjs - progression math as a table.
// power   : cost(L) = max(A*L^k, floor)          node curve.mjs power --A 1.61 --k 2.2 --floor 40 --max 1000 --rate 200
// geo     : cost(L) = base * mult^(L-1)           node curve.mjs geo --base 300 --mult 1.9 --max 100 --rate 200
// anchors : time-anchored, monotone cubic         node curve.mjs anchors --pts 10:10,50:60,100:300,150:600,200:900 --max 1000 --rate 200
// ladder  : price ladder                          node curve.mjs ladder --base 400 --mult 1.4 --n 34
// --rate = XP (or coins) per minute the player earns; --at 10,50,100 = levels to print (default spread)
const a = process.argv.slice(2); const mode = a[0];
const opt = (k, d) => { const i = a.indexOf("--" + k); return i > -1 ? a[i + 1] : d; };
const num = (k, d) => Number(opt(k, d));
const max = num("max", 100), rate = num("rate", 0);
const at = (opt("at", "") || "").split(",").filter(Boolean).map(Number);
const fmt = n => n >= 1e12 ? (n / 1e12).toFixed(2) + "T" : n >= 1e9 ? (n / 1e9).toFixed(2) + "B" : n >= 1e6 ? (n / 1e6).toFixed(2) + "M" : n >= 1e3 ? (n / 1e3).toFixed(1) + "K" : String(Math.round(n));
const hm = m => m < 60 ? m.toFixed(1) + "m" : m < 1440 ? (m / 60).toFixed(1) + "h" : (m / 1440).toFixed(1) + "d";
function rows(cost) {
  const levels = at.length ? at : [...new Set([1, 2, 5, 10, 20, 30, 40, 50, 75, 100, 150, 200, 300, 500, 750, 1000].filter(l => l <= max).concat([max]))];
  let cum = 0, out = []; const cumAt = {};
  for (let L = 1; L <= max; L++) { cum += cost(L); cumAt[L] = cum; }
  console.log("level | cost to next | cumulative" + (rate ? " | time at rate/min" : ""));
  for (const L of levels) console.log(`${String(L).padStart(5)} | ${fmt(cost(L)).padStart(12)} | ${fmt(cumAt[L]).padStart(10)}` + (rate ? ` | ${hm(cumAt[L] / rate)}` : ""));
}
if (mode === "power") { const A = num("A", 1), k = num("k", 2), floor = num("floor", 0); rows(L => Math.max(A * Math.pow(L, k), floor)); }
else if (mode === "geo") { const base = num("base", 100), mult = num("mult", 1.5); rows(L => base * Math.pow(mult, L - 1)); }
else if (mode === "ladder") { const base = num("base", 100), mult = num("mult", 1.4), n = num("n", 10); let cum = 0; console.log("tier | price | cumulative"); for (let t = 1; t <= n; t++) { const p = base * Math.pow(mult, t - 1); cum += p; console.log(`${String(t).padStart(4)} | ${fmt(p).padStart(9)} | ${fmt(cum)}`); } }
else if (mode === "anchors") {
  // anchors "level:minutes,..." -> cumulative XP at level = minutes*rate; monotone cubic (Fritsch-Carlson) on cumulative minutes
  const pts = opt("pts", "10:10,50:60,100:300").split(",").map(s => s.split(":").map(Number)).sort((x, y) => x[0] - y[0]);
  if (pts[0][0] !== 1) pts.unshift([1, 0]);
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]); const n = xs.length;
  const d = [], m = [];
  for (let i = 0; i < n - 1; i++) d[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]);
  m[0] = d[0]; m[n - 1] = d[n - 2];
  for (let i = 1; i < n - 1; i++) m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
  for (let i = 0; i < n - 1; i++) { if (d[i] === 0) { m[i] = m[i + 1] = 0; continue; } const al = m[i] / d[i], be = m[i + 1] / d[i]; const s = al * al + be * be; if (s > 9) { const t = 3 / Math.sqrt(s); m[i] = t * al * d[i]; m[i + 1] = t * be * d[i]; } }
  const minutesAt = L => { if (L >= xs[n - 1]) return ys[n - 1] + (L - xs[n - 1]) * d[n - 2]; let i = 0; while (xs[i + 1] < L) i++; const h = xs[i + 1] - xs[i], t = (L - xs[i]) / h; const h00 = 2 * t ** 3 - 3 * t ** 2 + 1, h10 = t ** 3 - 2 * t ** 2 + t, h01 = -2 * t ** 3 + 3 * t ** 2, h11 = t ** 3 - t ** 2; return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]; };
  const r = rate || 1; rows(L => Math.max(0, (minutesAt(L + 1) - minutesAt(L)) * r));
  console.log(`(cost = minutes between levels x rate ${r}; anchors ${pts.map(p => p.join(":")).join(" ")})`);
}
else { console.log("modes: power | geo | anchors | ladder  (see header)"); }
