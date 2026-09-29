import fs from 'fs';
import zlib from 'zlib';
const [,, src, outTop, outView] = process.argv;
const HALF = +(process.env.HALF || 2040), STEP = +(process.env.STEP || 8), BASE = +(process.env.BASE || 162);
const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const text = fs.readFileSync(src, 'utf8');
let N, W, H, M;
if (text.startsWith('#grab')) {
  const g = (await import('../analyze/analyze.mjs')).load(src);
  N = g.NZ; W = g.NX; H = new Float32Array(N * W); M = new Array(N * W);
  for (let r = 0; r < N; r++) for (let c = 0; c < W; c++) { const i = (N - 1 - r) * W + (W - 1 - c); H[i] = g.H[r * W + c]; M[i] = g.M[r * W + c]; }
} else {
  const rows = text.split(/\r?\n/).filter(l => /^[A-Za-z0-9+/]{3}/.test(l));
  N = rows.length; W = rows[0].length / 3; H = new Float32Array(N * W); M = new Array(N * W);
  for (let r = 0; r < N; r++) for (let c = 0; c < W; c++) {
    const s = rows[r].substr(c * 3, 3);
    H[r * W + c] = (B64.indexOf(s[0]) * 64 + B64.indexOf(s[1])) / 4; M[r * W + c] = s[2];
  }
}
const COL = { G: [82, 159, 52], L: [98, 181, 59], S: [162, 217, 89], T: [93, 195, 70], B: [58, 58, 64], R: [112, 112, 118], W: [60, 130, 220], P: [255, 0, 255], M: [110, 80, 50], D: [140, 110, 70], A: [220, 200, 140], N: [200, 170, 120], C: [255, 0, 255], _: [0, 0, 0] };
const h = (r, c) => H[Math.min(N - 1, Math.max(0, r)) * W + Math.min(W - 1, Math.max(0, c))];
function png(w, hgt, px, file) {
  const crcT = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
  const crc = b => { let c = -1; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const cr = Buffer.alloc(4); cr.writeUInt32BE(crc(td)); return Buffer.concat([l, td, cr]); };
  const raw = Buffer.alloc((w * 3 + 1) * hgt);
  for (let y = 0; y < hgt; y++) { raw[y * (w * 3 + 1)] = 0; px.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(hgt, 4); ihdr[8] = 8; ihdr[9] = 2;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}
const L = [0.5, 0.6, 0.62]; const ln = Math.hypot(...L); L.forEach((v, i) => L[i] = v / ln);
const top = Buffer.alloc(W * N * 3);
for (let r = 0; r < N; r++) for (let c = 0; c < W; c++) {
  const dx = (h(r, c + 1) - h(r, c - 1)) / (2 * STEP), dz = (h(r + 1, c) - h(r - 1, c)) / (2 * STEP);
  const nl = Math.hypot(dx, 1, dz); const sh = Math.max(0.25, (-dx * L[0] + L[1] - dz * L[2]) / nl);
  const col = COL[M[r * W + c]] || [255, 0, 255];
  for (let k = 0; k < 3; k++) top[(r * W + c) * 3 + k] = Math.min(255, col[k] * (0.35 + 0.8 * sh));
}
png(W, N, top, outTop);
const VW = 1000, VH = 720, cam = (process.env.CAM || "0,1700,-1100").split(",").map(Number), look = (process.env.LOOK || "0,180,260").split(",").map(Number);
const sub = (a, b) => a.map((v, i) => v - b[i]), nrm = a => { const l = Math.hypot(...a); return a.map(v => v / l); }, cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const fwd = nrm(sub(look, cam)), right = nrm(cross([0, 1, 0], fwd)), up = cross(fwd, right);
const view = Buffer.alloc(VW * VH * 3);
const hu = (u, v) => { const c = (HALF - u) / STEP, r = (HALF - v) / STEP; const c0 = Math.floor(c), r0 = Math.floor(r), fc = c - c0, fr = r - r0; return (h(r0, c0) * (1 - fc) + h(r0, c0 + 1) * fc) * (1 - fr) + (h(r0 + 1, c0) * (1 - fc) + h(r0 + 1, c0 + 1) * fc) * fr; };
for (let py = 0; py < VH; py++) for (let px = 0; px < VW; px++) {
  const sx = (px / VW - 0.5) * 1.6, sy = -(py / VH - 0.5) * 1.6 * VH / VW;
  const d = nrm(fwd.map((f, i) => f + right[i] * -sx + up[i] * sy));
  let t = 0, hit = null;
  for (let s = 0; s < 1400 && t < 9000; s++) {
    const p = cam.map((v, i) => v + d[i] * t);
    if (Math.abs(p[0]) > HALF || Math.abs(p[2]) > HALF) { if (p[1] < BASE) { hit = 'out'; break; } t += 6; continue; }
    const g = hu(p[0], p[2]);
    if (p[1] <= g) { hit = p; break; }
    t += Math.max(2, (p[1] - g) * 0.5);
  }
  let col = [150, 200, 240];
  if (hit === 'out') col = [80, 160, 60];
  else if (hit) {
    const c = Math.round((HALF - hit[0]) / STEP), r = Math.round((HALF - hit[2]) / STEP);
    const base = COL[M[Math.min(N - 1, Math.max(0, r)) * W + Math.min(W - 1, Math.max(0, c))]] || [255, 0, 255];
    const dx = (hu(hit[0] - 4, hit[2]) - hu(hit[0] + 4, hit[2])) / 8, dz = (hu(hit[0], hit[2] + 4) - hu(hit[0], hit[2] - 4)) / 8;
    const nl = Math.hypot(dx, 1, dz), sh = Math.max(0, (dx * 0.4 + 0.8 - dz * 0.45) / nl / 1.0);
    col = base.map(v => Math.min(255, v * (0.8 + 0.25 * sh)));
  }
  view.set(col.map(Math.round), (py * VW + px) * 3);
}
png(VW, VH, view, outView);
console.log(`grid ${W}x${N} -> ${outTop}, ${outView}`);
