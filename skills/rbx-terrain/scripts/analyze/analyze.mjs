import fs from 'fs';
import zlib from 'zlib';

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const DEC = new Int16Array(128).fill(-1);
for (let i = 0; i < 64; i++) DEC[B64.charCodeAt(i)] = i;
export const NAMES = { G: 'Grass', L: 'LeafyGrass', S: 'Limestone', B: 'Basalt', R: 'Rock', W: 'Water', P: 'Pavement', M: 'Mud', D: 'Ground', A: 'Sand', N: 'Sandstone', C: 'Cobblestone', T: 'Slate', X: 'Salt', Y: 'Asphalt', Z: 'Concrete', O: 'Snow', I: 'Glacier', E: 'Ice', K: 'Brick', H: 'WoodPlanks', Q: 'SmoothPlastic', V: 'CrackedLava', _: 'none', '?': 'other' };
const BLADE = new Set(['G', 'L', 'S', 'T', 'C']);
const PAY = new Set(['G', 'L', 'S']);
const COL = { G: [82, 159, 52], L: [98, 181, 59], S: [162, 217, 89], T: [93, 195, 70], C: [72, 199, 109], B: [70, 70, 76], R: [112, 112, 118], W: [60, 130, 220], M: [110, 80, 50], D: [140, 110, 70], A: [220, 200, 140], X: [250, 250, 250], Y: [80, 84, 84] };

export const DEFAULTS = { blurR: 8, nms: 32, minProm: 3, minR: 16, rays: 32, maxR: 420, tol: 0.75, footRatio: 0.25, footRun: 16, climbDeg: 25, climbBase: 16, edgeDeg: 35, cliffDeg: 55, closure: 0.8, closeFrac: 0.25, grassMin: 80, minRH: 1.5, flatDeg: 3, scale: 3, gapMin: 8, reliefWin: 100, pathMats: 'MD', pathMinArea: 2000, patchMin: 4, islandMin: 16, kinkBase: 8, kinkScore: 4.5 };

export function load(file) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  const hdr = lines[0].trim().split(/\s+/);
  if (hdr[0] !== '#grab') throw new Error(`${file}: missing #grab header`);
  const [X0, Z0, NX, NZ, S] = hdr.slice(1, 6).map(Number);
  const rows = lines.filter(l => l[0] === '|');
  if (rows.length !== NZ) throw new Error(`${file}: ${rows.length}/${NZ} rows`);
  const g = { X0, Z0, NX, NZ, S, H: new Float64Array(NX * NZ), M: new Array(NX * NZ), GAP: new Float32Array(NX * NZ) };
  for (let r = 0; r < NZ; r++) {
    const row = rows[r];
    if (row.length !== 1 + NX * 5) throw new Error(`${file}: row ${r} has ${row.length - 1} chars, want ${NX * 5}`);
    for (let c = 0; c < NX; c++) {
      const o = 1 + c * 5, i = r * NX + c, m = row[o + 3];
      g.M[i] = m;
      g.H[i] = m === '_' ? NaN : (DEC[row.charCodeAt(o)] * 4096 + DEC[row.charCodeAt(o + 1)] * 64 + DEC[row.charCodeAt(o + 2)]) / 16 - 2048;
      g.GAP[i] = DEC[row.charCodeAt(o + 4)] * 2;
    }
  }
  return g;
}

export function synth(X0, Z0, NX, NZ, S, fn) {
  const g = { X0, Z0, NX, NZ, S, H: new Float64Array(NX * NZ), M: new Array(NX * NZ).fill('G'), GAP: new Float32Array(NX * NZ) };
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) g.H[r * NX + c] = fn(X0 + c * S, Z0 + r * S);
  return g;
}

function sample(g, A, x, z) {
  const fc = (x - g.X0) / g.S, fr = (z - g.Z0) / g.S;
  const c0 = Math.floor(fc), r0 = Math.floor(fr);
  if (c0 < 0 || r0 < 0 || c0 >= g.NX - 1 || r0 >= g.NZ - 1) return NaN;
  const tc = fc - c0, tr = fr - r0, i = r0 * g.NX + c0;
  return (A[i] * (1 - tc) + A[i + 1] * tc) * (1 - tr) + (A[i + g.NX] * (1 - tc) + A[i + g.NX + 1] * tc) * tr;
}

function blur1(g, A, rad) {
  const { NX, NZ } = g, T = new Float64Array(NX * NZ), O = new Float64Array(NX * NZ);
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) {
    let s = 0, n = 0;
    for (let k = Math.max(0, c - rad); k <= Math.min(NX - 1, c + rad); k++) { const v = A[r * NX + k]; if (v === v) { s += v; n++; } }
    T[r * NX + c] = n ? s / n : NaN;
  }
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) {
    let s = 0, n = 0;
    for (let k = Math.max(0, r - rad); k <= Math.min(NZ - 1, r + rad); k++) { const v = T[k * NX + c]; if (v === v) { s += v; n++; } }
    O[r * NX + c] = n ? s / n : NaN;
  }
  for (let i = 0; i < A.length; i++) if (A[i] !== A[i]) O[i] = NaN;
  return O;
}

function filt(g, A, rad, pick) {
  const { NX, NZ } = g, T = new Float64Array(NX * NZ), O = new Float64Array(NX * NZ);
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) {
    let b = NaN;
    for (let k = Math.max(0, c - rad); k <= Math.min(NX - 1, c + rad); k++) { const v = A[r * NX + k]; if (v === v) b = b === b ? pick(b, v) : v; }
    T[r * NX + c] = b;
  }
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) {
    let b = NaN;
    for (let k = Math.max(0, r - rad); k <= Math.min(NZ - 1, r + rad); k++) { const v = T[k * NX + c]; if (v === v) b = b === b ? pick(b, v) : v; }
    O[r * NX + c] = b;
  }
  return O;
}

export function slopes(g) {
  const { NX, NZ, S, H } = g, D = new Float64Array(NX * NZ);
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) {
    const i = r * NX + c, h = H[i];
    if (h !== h) { D[i] = NaN; continue; }
    const xa = c > 0 && H[i - 1] === H[i - 1] ? H[i - 1] : h, xb = c < NX - 1 && H[i + 1] === H[i + 1] ? H[i + 1] : h;
    const za = r > 0 && H[i - NX] === H[i - NX] ? H[i - NX] : h, zb = r < NZ - 1 && H[i + NX] === H[i + NX] ? H[i + NX] : h;
    const wx = (c > 0 ? 1 : 0) + (c < NX - 1 ? 1 : 0), wz = (r > 0 ? 1 : 0) + (r < NZ - 1 ? 1 : 0);
    D[i] = Math.atan(Math.hypot((xb - xa) / (wx * S), (zb - za) / (wz * S))) * 180 / Math.PI;
  }
  return D;
}

const q = (arr, p) => { const a = arr.filter(v => v === v).sort((x, y) => x - y); return a.length ? a[Math.min(a.length - 1, Math.floor(p * (a.length - 1) + 0.5))] : NaN; };
const r1 = v => Math.round(v * 10) / 10;

export function rayProfile(g, V, Vs, x, z, ang, o) {
  const dx = Math.cos(ang), dz = Math.sin(ang), st = g.S / 2;
  const at = (A, t) => sample(g, A, x + dx * t, z + dz * t);
  const v0 = at(V, 0);
  let best = at(Vs, 0), bestT = 0, gmax = 0, runStart = -1, footT = -1, t = 0, edge = false;
  const edgeTan = Math.tan((o.edgeDeg * Math.PI) / 180), cliffTan = Math.tan((o.cliffDeg * Math.PI) / 180);
  const matAt = t2 => { const c = Math.round((x + dx * t2 - g.X0) / g.S), r = Math.round((z + dz * t2 - g.Z0) / g.S); return c >= 0 && r >= 0 && c < g.NX && r < g.NZ ? g.M[r * g.NX + c] : '_'; };
  while (t < o.maxR) {
    t += st;
    if (t >= 4) {
      const gr4 = (at(V, t - 4) - at(V, t)) / 4, m = matAt(t);
      if (gr4 > cliffTan || (gr4 > edgeTan && (m === 'R' || m === 'B'))) { footT = t - 4; edge = true; break; }
    }
    const vs = at(Vs, t);
    if (vs !== vs) { footT = bestT; break; }
    if (vs < best) { best = vs; bestT = t; }
    if (vs > best + o.tol) { footT = bestT; break; }
    if (t >= 8) {
      const gr = (at(V, t - 8) - at(V, t)) / 8;
      gmax = Math.max(gmax, gr);
      if (gr < o.footRatio * gmax) { if (runStart < 0) runStart = t - 4; if (t - runStart >= o.footRun) { footT = runStart; break; } }
      else runStart = -1;
    }
  }
  if (footT < 0) footT = bestT;
  const vf = at(V, footT);
  const drop = v0 - vf;
  let r50 = NaN, climb = 0;
  for (let s = 0; s <= footT; s += st) {
    const v = at(V, s);
    if (r50 !== r50 && v0 - v >= drop / 2) r50 = s;
    if (s + o.climbBase <= footT + 1e-9) climb = Math.max(climb, (at(V, s) - at(V, s + o.climbBase)) / o.climbBase);
  }
  return { footT, drop, r50, climbDeg: Math.atan(Math.max(0, climb)) * 180 / Math.PI, footV: vf, edge };
}

export function features(g, sign, opt = {}) {
  const o = { ...DEFAULTS, ...opt };
  const { NX, NZ, S } = g;
  const V = new Float64Array(NX * NZ);
  for (let i = 0; i < V.length; i++) V[i] = g.M[i] === 'W' ? NaN : sign * g.H[i];
  const rb = Math.max(1, Math.round(o.blurR / S / 2));
  const Vs = blur1(g, blur1(g, V, rb), rb);
  const w = Math.max(2, Math.round(o.nms / S));
  const MX = filt(g, Vs, w, Math.max), MN = filt(g, Vs, w, Math.min);
  const cand = [];
  for (let r = 1; r < NZ - 1; r++) for (let c = 1; c < NX - 1; c++) {
    const i = r * NX + c;
    if (Vs[i] === Vs[i] && Vs[i] >= MX[i] && Vs[i] - MN[i] >= o.minProm * 0.5) cand.push(i);
  }
  cand.sort((a, b) => Vs[b] - Vs[a]);
  const kept = [], out = [];
  for (const i of cand) {
    const c = i % NX, r = (i - c) / NX;
    if (kept.some(k => Math.hypot(k[0] - c, k[1] - r) * S < o.nms)) continue;
    kept.push([c, r]);
    const x = g.X0 + c * S, z = g.Z0 + r * S;
    const rs = [];
    for (let k = 0; k < o.rays; k++) rs.push(rayProfile(g, V, Vs, x, z, (2 * Math.PI * k) / o.rays, o));
    const drops = rs.map(p => p.drop), prom = Math.min(...drops);
    const rEq = 2 * q(rs.map(p => p.r50), 0.5);
    if (!(prom >= o.minProm) || !(rEq >= o.minR)) continue;
    if (out.some(f => Math.hypot(f.x - x, f.z - z) < 0.7 * f.r)) continue;
    const cl = rs.map(p => p.climbDeg);
    let gc = 0, gn = 0;
    const rc = Math.ceil(rEq / S);
    for (let a2 = -rc; a2 <= rc; a2++) for (let b2 = -rc; b2 <= rc; b2++) {
      const cc = c + a2, rr = r + b2;
      if (cc < 0 || rr < 0 || cc >= NX || rr >= NZ || (a2 * a2 + b2 * b2) * S * S > rEq * rEq) continue;
      gn++; if (BLADE.has(g.M[rr * NX + cc])) gc++;
    }
    const open = rs.filter(p => !p.edge), hMed = q(drops, 0.5), closure = open.length ? open.filter(p => p.drop >= Math.max(o.minProm, o.closeFrac * hMed)).length / open.length : 0;
    out.push({
      closed: closure >= o.closure, closure: Math.round(closure * 100), grass: Math.round((gc / Math.max(1, gn)) * 100),
      x: Math.round(x), z: Math.round(z), top: r1(g.H[i]),
      h: r1(q(drops, 0.5)), prom: r1(prom), hMax: r1(Math.max(...drops)),
      r: Math.round(rEq), foot: Math.round(q(rs.map(p => p.footT), 0.5)),
      rOverH: r1(rEq / Math.max(0.1, q(drops, 0.5))),
      climbWorst: r1(Math.max(...cl)), climbMed: r1(q(cl, 0.5)), climbEasy: r1(Math.min(...cl)),
      climbOk: cl.filter(v => v <= o.climbDeg).length, rays: o.rays, edgeRays: rs.filter(p => p.edge).length, steepOpen: rs.filter(p => !p.edge && p.climbDeg > o.climbDeg).length,
      steepDirs: rs.map((p, k) => (!p.edge && p.climbDeg > o.climbDeg ? [Math.round((360 * k) / o.rays), r1(p.climbDeg), Math.round(p.footT)] : null)).filter(Boolean),
    });
  }
  return out;
}

function components(g, keyOf) {
  const { NX, NZ } = g, lab = new Int32Array(NX * NZ).fill(-1), comps = [];
  for (let s = 0; s < NX * NZ; s++) {
    if (lab[s] >= 0) continue;
    const k = keyOf(s);
    if (k === null) continue;
    const stack = [s]; lab[s] = comps.length; let n = 0;
    while (stack.length) {
      const i = stack.pop(); n++;
      const c = i % NX;
      for (const j of [c > 0 ? i - 1 : -1, c < NX - 1 ? i + 1 : -1, i - NX, i + NX]) {
        if (j >= 0 && j < NX * NZ && lab[j] < 0 && keyOf(j) === k) { lab[j] = comps.length; stack.push(j); }
      }
    }
    comps.push({ k, n, x: g.X0 + (s % NX) * g.S, z: g.Z0 + Math.floor(s / NX) * g.S });
  }
  return comps;
}

export function reach(g, o) {
  const { NX, NZ, S, H, M } = g, N = NX * NZ;
  const Hs = blur1(g, H, 1), R = new Uint8Array(N), q = new Int32Array(N), D = slopes({ ...g, H: Hs });
  const up = Math.tan((o.climbDeg * Math.PI) / 180);
  let head = 0, tail = 0;
  const ok = i => Hs[i] === Hs[i] && M[i] !== 'W';
  const border = [];
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) if ((r === 0 || c === 0 || r === NZ - 1 || c === NX - 1) && ok(r * NX + c)) border.push(r * NX + c);
  let seeds = border;
  if (typeof o.start === 'string' && o.start.includes(',')) {
    const [sx, sz] = o.start.split(',').map(Number);
    seeds = [Math.round((sz - g.Z0) / S) * NX + Math.round((sx - g.X0) / S)].filter(ok);
  } else if (o.start !== 'border') {
    const hs = border.map(i => Hs[i]).sort((a, b) => a - b), cut = hs[hs.length >> 1] + 10;
    seeds = border.filter(i => Hs[i] <= cut);
  }
  for (const i of seeds) if (!R[i]) { R[i] = 1; q[tail++] = i; }
  const nb = [[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [1, 1, Math.SQRT2], [1, -1, Math.SQRT2], [-1, 1, Math.SQRT2], [-1, -1, Math.SQRT2]];
  while (head < tail) {
    const i = q[head++], c = i % NX, r = (i - c) / NX;
    for (const [dc, dr, d] of nb) {
      const c2 = c + dc, r2 = r + dr;
      if (c2 < 0 || r2 < 0 || c2 >= NX || r2 >= NZ) continue;
      const j = r2 * NX + c2;
      if (R[j] || !ok(j)) continue;
      const rise = Hs[j] - Hs[i];
      if (rise < -0.05 || (D[j] <= o.climbDeg && rise <= up * d * S)) { R[j] = 1; q[tail++] = j; }
    }
  }
  let n = 0, un = 0;
  for (let i = 0; i < N; i++) if (ok(i)) { n++; if (!R[i]) un++; }
  const isl = components(g, i => (ok(i) && !R[i] ? 1 : null)).filter(p => p.n >= o.islandMin).sort((a, b) => b.n - a.n);
  const top = isl.slice(0, 8).map(p => [p.x, p.z, p.n * S * S]);
  return { R, pct: Math.round(((n - un) / Math.max(1, n)) * 1000) / 10, islands: isl.length, islandArea: isl.reduce((t, p) => t + p.n * S * S, 0), at: top };
}

export function analyze(g, opt = {}) {
  const o = { ...DEFAULTS, ...opt };
  const { NX, NZ, S, H, M } = g, N = NX * NZ;
  const D = slopes(g);
  const valid = [];
  for (let i = 0; i < N; i++) if (H[i] === H[i]) valid.push(i);
  const n = valid.length;
  const bins = [0, 3, 8, 13, 20, 25, 30, 35, 45, 66, 91], hist = new Array(bins.length - 1).fill(0);
  let flat = 0, flatDry = 0, dry = 0, gap = 0;
  for (const i of valid) {
    const d = D[i];
    for (let b = 0; b < hist.length; b++) if (d >= bins[b] && d < bins[b + 1]) { hist[b]++; break; }
    if (d < o.flatDeg) flat++;
    if (M[i] !== 'W') { dry++; if (d < o.flatDeg) flatDry++; }
    if (g.GAP[i] >= o.gapMin) gap++;
  }
  const pc = v => r1((v / Math.max(1, n)) * 100);
  const wc = Math.max(2, Math.round(o.reliefWin / S)), relief = [];
  for (let r = 0; r + wc <= NZ; r += wc) for (let c = 0; c + wc <= NX; c += wc) {
    const vals = [];
    for (let a = r; a < r + wc; a++) for (let b = c; b < c + wc; b++) vals.push(H[a * NX + b]);
    if (vals.filter(v => v === v).length > wc * wc * 0.8) relief.push(q(vals, 0.9) - q(vals, 0.1));
  }
  const B1 = blur1(g, H, 1), B2 = blur1(g, B1, 1);
  let bump = 0, bn = 0;
  for (const i of valid) if (B2[i] === B2[i] && D[i] < 45) { bump += Math.abs(H[i] - 2 * B1[i] + B2[i]); bn++; }
  const mats = {}, PMS = new Set(o.pathMats.split(''));
  let blade = 0, pay = 0, specks = 0;
  for (const i of valid) {
    mats[M[i]] = (mats[M[i]] || 0) + 1;
    if (BLADE.has(M[i]) && D[i] <= 55) blade++;
    if (PAY.has(M[i])) pay++;
    const c = i % NX;
    if (c === 0 || c === NX - 1 || i < NX || i >= N - NX || PMS.has(M[i])) continue;
    const nb = [i - 1, i + 1, i - NX, i + NX, i - NX - 1, i - NX + 1, i + NX - 1, i + NX + 1];
    if (nb.every(j => H[j] === H[j] && M[j] === M[nb[0]] && M[j] !== M[i])) specks++;
  }
  const comps = components(g, i => (H[i] === H[i] ? M[i] : null));
  const patches = {};
  for (const [m, cnt] of Object.entries(mats)) {
    const cs = comps.filter(p => p.k === m).map(p => p.n * S * S);
    patches[NAMES[m] || m] = { share: pc(cnt), n: cs.length, small: cs.filter(a => a < 4 * S * S).length, p50: Math.round(q(cs, 0.5)), p90: Math.round(q(cs, 0.9)), max: Math.round(cs.reduce((m, v) => Math.max(m, v), 0)) };
  }
  const steepC = components(g, i => (H[i] === H[i] && D[i] > o.climbDeg && M[i] !== 'W' ? 1 : null)).filter(p => p.n >= o.patchMin);
  const K2 = new Float64Array(N).fill(NaN), k2 = Math.max(1, Math.round(o.kinkBase / S / 2));
  const Hk = blur1(g, H, 1);
  const w8 = 2 * k2, w16 = 4 * k2;
  const ang = (a2, b2) => Math.abs(Math.atan(b2) - Math.atan(a2)) * 180 / Math.PI;
  for (let r = w16; r < NZ - w16; r++) for (let c = w16; c < NX - w16; c++) {
    const i = r * NX + c;
    if (D[i] > 45 || M[i] === 'W') continue;
    const sl = (st, w, dir) => (Hk[i + dir * st * w] - Hk[i + (dir - 1) * st * w]) / (w * S);
    const score = st => ang(sl(st, w8, 0), sl(st, w8, 1)) - ang(sl(st, w16, 0), sl(st, w16, 1)) / 2;
    K2[i] = Math.max(score(1), score(NX));
  }
  const kinkC = components(g, i => (K2[i] > o.kinkScore ? 1 : null)).filter(p => p.n >= o.patchMin);
  const RC = reach(g, o);
  const kinkCells = new Uint8Array(N);
  for (let i = 0; i < N; i++) if (K2[i] > o.kinkScore) kinkCells[i] = 1;
  const hf = features(g, 1, o), bf = features(g, -1, o);
  for (const f of hf) { const c = Math.round((f.x - g.X0) / S), r = Math.round((f.z - g.Z0) / S); f.reachable = !!RC.R[r * NX + c]; }
  const soft = f => f.closed && f.grass >= o.grassMin && f.rOverH >= o.minRH;
  const openF = [...hf.filter(f => !f.closed).map(f => ({ ...f, kind: 'ridge' })), ...bf.filter(f => !f.closed).map(f => ({ ...f, kind: 'trough' }))];
  const hills = hf.filter(soft), bowls = bf.filter(soft), ridges = hf.filter(f => !f.closed).length, troughs = bf.filter(f => !f.closed).length;
  const rockHills = hf.filter(f => f.closed && !soft(f)).length, rockBowls = bf.filter(f => f.closed && !soft(f)).length;
  hills.forEach((f, k) => (f.id = 'H' + (k + 1))); bowls.forEach((f, k) => (f.id = 'B' + (k + 1)));
  const hs = valid.map(i => H[i]);
  const PM = new Set(o.pathMats.split('')), DT = new Float64Array(N), BIG = 1e9;
  for (let i = 0; i < N; i++) DT[i] = PM.has(M[i]) ? BIG : 0;
  const relax = (i, j, w) => { if (j >= 0 && j < N && DT[j] + w < DT[i]) DT[i] = DT[j] + w; };
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) { const i = r * NX + c; if (!DT[i]) continue; if (c > 0) { relax(i, i - 1, 1); relax(i, i - NX - 1, 1.414); } relax(i, i - NX, 1); if (c < NX - 1) relax(i, i - NX + 1, 1.414); if (c === 0 || r === 0) DT[i] = Math.min(DT[i], 1); }
  for (let r = NZ - 1; r >= 0; r--) for (let c = NX - 1; c >= 0; c--) { const i = r * NX + c; if (!DT[i]) continue; if (c < NX - 1) { relax(i, i + 1, 1); relax(i, i + NX + 1, 1.414); } relax(i, i + NX, 1); if (c > 0) relax(i, i + NX - 1, 1.414); if (c === NX - 1 || r === NZ - 1) DT[i] = Math.min(DT[i], 1); }
  const pathComps = components(g, i => (PM.has(M[i]) ? 1 : null)).filter(p => p.n * S * S >= o.pathMinArea).length;
  const widths = [];
  for (let r = 1; r < NZ - 1; r++) for (let c = 1; c < NX - 1; c++) {
    const i = r * NX + c, d = DT[i];
    if (d < 2 || d >= BIG) continue;
    if ([i - 1, i + 1, i - NX, i + NX, i - NX - 1, i - NX + 1, i + NX - 1, i + NX + 1].every(j => DT[j] <= d)) widths.push(2 * d * S);
  }
  const out = {
    defs: {
      grid: 'raycast top surface every S studs (grab.lua); heights 1/16 stud; water cells excluded from hills/bowls',
      slope: 'deg from central differences over 2S studs',
      flat: `share of cells with slope < ${o.flatDeg} deg`,
      relief: `p90 - p10 height inside tiled ${o.reliefWin}x${o.reliefWin} stud windows`,
      bump: 'mean |h - 2Bh + BBh|, B = 3x3 mean, cells < 45 deg (curvature cancels; lumps and voxel steps score)',
      feature: `summit/floor = local extreme of ${o.blurR}-stud blurred height, ${o.nms}-stud NMS; ${o.rays} rays walk out until the blurred height turns back (> ${o.tol}) or the descent rate stays < ${o.footRatio} x its max for ${o.footRun} studs (= foot/rim)`,
      closed: `hill/bowl when >= ${o.closure * 100}% of the rays that do not stop at a cliff edge drop >= max(${o.minProm}, ${o.closeFrac} x median h) (an uneven rim still closes; a trough's axis rays drop ~0); otherwise ridge (hill side) or trough (bowl side)`,
      open: 'ridges and troughs (summits/floors whose rays do not close, e.g. a hill on a plateau edge or a spiral groove) with the same per-feature numbers',
      soft: `hills/bowls counted only when closed, >= ${o.grassMin}% blade-material cells inside r, and r/h >= ${o.minRH}; the rest are rockHills/rockBowls (boulders, cliffs, pits, plateau drops)`,
      h: 'median over rays of summit - foot (bowls: rim - floor); prom = min over rays (lowest saddle / spill point); hMax = max',
      r: '2 x median half-height distance (exact radius for cosine profiles); foot = median foot distance',
      edge: `a ray stops at a cliff edge (boundary, not an approach): > ${o.cliffDeg} deg over 4 studs, or > ${o.edgeDeg} deg on Rock/Basalt paint; edgeRays counts them`,
      climb: `per ray: steepest ${o.climbBase}-stud rise (ball contact ~25 studs; an 8-stud baseline reads +-1.5 deg voxel mesh noise) between foot and summit/floor; climbWorst = max over rays, climbEasy = min, climbOk = rays <= ${o.climbDeg} deg`,
      reach: `flood fill from ${typeof o.start === 'string' && o.start.includes(',') ? 'start ' + o.start : o.start === 'border' ? 'every border cell' : 'border cells at base level (<= border median + 10)'}: downhill always, level or uphill only onto cells whose own slope is <= ${o.climbDeg} deg with a rise <= ${o.climbDeg} deg (3x3-smoothed heights, so no zig-zag up a steep flank); pct = reachable share of ground cells, islands = unreachable groups >= ${o.islandMin} cells (x, z of first cell, area); hills get reachable = summit reached`,
      kinks: `crease detector: slope change across a cell over ${o.kinkBase}-stud stretches minus half the change over ${2 * o.kinkBase}-stud stretches (x and z, 3x3-smoothed heights, cells < 45 deg). Smooth curvature scores ~0. Calibrated on synthetic breaks: 15 deg scores 3.8, 10 deg 2.5; Roblox mesh noise p99 1.2-2.3 on lab sites. Crease patches = >= ${o.patchMin} connected cells scoring over ${o.kinkScore} (about an 18 deg slope break; 20 deg is caught, 15 deg is not)`,
      steepPatches: `connected groups of >= ${o.patchMin} cells steeper than ${o.climbDeg} deg (ball-sized; lone cells are voxel mesh noise, about +-3 deg vs the plan)`,
      specks: `lone cells inside a uniform patch: all 8 neighbours share one other material (user R6 "stray specks/flecks"; cells at 3-tone junctions are raycast sampling, not paint), path materials (${o.pathMats}) excluded: Mud/Ground speckle on lanes is the user's A2 style`,
      blade: 'Grass/LeafyGrass/Limestone/Slate/Cobblestone at <= 55 deg; pay = Grass/LeafyGrass/Limestone',
      path: `cells of materials ${o.pathMats} (M Mud, D Ground); width = 2 x chamfer distance to the edge at ridge cells (local max), p25/p50/p90; pieces = connected areas >= ${o.pathMinArea} sq studs`,
      gap: `air under the top surface >= ${o.gapMin} studs (roof + clear)`,
    },
    grid: { X0: g.X0, Z0: g.Z0, NX, NZ, S, cells: n, miss: N - n, x1: g.X0 + (NX - 1) * S, z1: g.Z0 + (NZ - 1) * S },
    height: { p10: r1(q(hs, 0.1)), p50: r1(q(hs, 0.5)), p90: r1(q(hs, 0.9)), min: r1(hs.reduce((m, v) => Math.min(m, v), Infinity)), max: r1(hs.reduce((m, v) => Math.max(m, v), -Infinity)) },
    slope: { bins: bins.slice(0, -1).map((b, k) => `${b}-${bins[k + 1]}`), pct: hist.map(pc), p50: r1(q(valid.map(i => D[i]), 0.5)), p90: r1(q(valid.map(i => D[i]), 0.9)), over25: pc(valid.filter(i => D[i] > 25).length), over35: pc(valid.filter(i => D[i] > 35).length) },
    flat: pc(flat), flatDry: r1((flatDry / Math.max(1, dry)) * 100),
    relief100: { p25: r1(q(relief, 0.25)), p50: r1(q(relief, 0.5)), p90: r1(q(relief, 0.9)), windows: relief.length },
    bump: Math.round((bump / Math.max(1, bn)) * 1000) / 1000,
    paint: patches, blade: pc(blade), pay: pc(pay), specks, gap: pc(gap),
    kinks: { n: kinkC.length, cells: kinkC.reduce((t, p) => t + p.n, 0), p99: r1(q(Array.from(K2), 0.99)), at: kinkC.sort((p, q2) => q2.n - p.n).slice(0, 12).map(p => [p.x, p.z, p.n]) },
    steepPatches: { n: steepC.length, cells: steepC.reduce((t, p) => t + p.n, 0), max: steepC.reduce((m, p) => Math.max(m, p.n), 0), at: steepC.sort((p, q) => q.n - p.n).slice(0, 12).map(p => [p.x, p.z, p.n]) },
    reach: { pct: RC.pct, islands: RC.islands, islandArea: RC.islandArea, at: RC.at },
    path: { mats: o.pathMats, pieces: pathComps, share: pc(valid.filter(i => PM.has(M[i])).length), wP25: Math.round(q(widths, 0.25)), wP50: Math.round(q(widths, 0.5)), wP90: Math.round(q(widths, 0.9)) },
    hills, bowls, ridges, troughs, rockHills, rockBowls, open: openF,
  };
  Object.defineProperty(out, 'kinkCells', { value: kinkCells, enumerable: false });
  return out;
}

export function verdict(a) {
  const rows = [];
  const add = (label, v, ok, rule) => rows.push(`${ok ? 'PASS' : 'FAIL'} ${label}: ${v} [${rule}]`);
  const hs = a.hills.filter(f => (f.steepOpen ?? f.rays - f.climbOk) > 0);
  add('hills with an approach > 25 deg (non-cliff-edge rays)', `${hs.length}/${a.hills.length}${hs.length ? ' ' + hs.slice(0, 6).map(f => f.id).join(' ') : ''}`, hs.length === 0, 'user R7');
  const bs = a.bowls.filter(f => (f.steepOpen ?? f.rays - f.climbOk) > 0);
  add('bowls with an exit > 25 deg', `${bs.length}/${a.bowls.length}${bs.length ? ' ' + bs.slice(0, 6).map(f => f.id).join(' ') : ''}`, bs.length === 0, 'user R5');
  const basins = a.bowls.filter(f => f.r >= 150 && f.prom >= 10), bw = basins.filter(f => f.climbWorst > 15.75);
  add('basin walls > 15 deg (+0.75 noise), bowls with r >= 150 and prominence >= 10 (dips between hills excluded)', `${bw.length}/${basins.length}${bw.length ? ' ' + bw.slice(0, 6).map(f => f.id).join(' ') : ''}`, bw.length === 0, 'user R6, R12 r 170-230');
  add('steep patches (>= 4 cells over 25 deg)', a.steepPatches.n, a.steepPatches.n === 0, 'user R5/R7; cliffs, wall-ride faces and portals are expected here');
  add('crease patches (slope breaks >= ~18 deg)', a.kinks.n, a.kinks.n === 0, 'user R6');
  add('ground reachable from base level', `${a.reach.pct}%`, a.reach.pct >= 99.5, 'user R5/R7');
  add('flat (< 3 deg)', `${a.flat}%`, a.flat <= 8, 'lab brief, user R2/R10 (designed floors count here too)');
  add('relief/100 p50', a.relief100.p50, a.relief100.p50 >= 13.6, 'scan A4 13.6 = lowest user area');
  const lime = a.paint.Limestone ? a.paint.Limestone.share : 0;
  add('highlight (Limestone) share', `${lime}%`, lime >= 10 && lime <= 20, 'scans v4 10.7 / A3 19.2, user R14');
  const banned = ['Cobblestone', 'Pavement', 'Concrete'].reduce((t, k) => t + (a.paint[k] ? a.paint[k].share : 0), 0);
  add('banned materials share', `${Math.round(banned * 10) / 10}%`, banned === 0, 'user R11/R12');
  add('isolated paint cells per 10,000', Math.round((a.specks / a.grid.cells) * 1e5) / 10, a.specks / a.grid.cells <= 1e-4, 'user R6');
  return rows;
}

export function summary(name, a) {
  const L = [];
  const gr = a.grid;
  L.push(`scan ${name}: x ${gr.X0}..${gr.x1} z ${gr.Z0}..${gr.z1} @${gr.S} (${gr.cells} cells, ${gr.miss} miss)`);
  L.push(`height p10 ${a.height.p10} p50 ${a.height.p50} p90 ${a.height.p90}; relief/100 p25 ${a.relief100.p25} p50 ${a.relief100.p50} p90 ${a.relief100.p90}; bump ${a.bump}`);
  L.push(`slope % ${a.slope.bins.map((b, k) => `${b}:${a.slope.pct[k]}`).join(' ')} | p50 ${a.slope.p50} p90 ${a.slope.p90} >25 ${a.slope.over25} >35 ${a.slope.over35} | flat(<3) ${a.flat} dry ${a.flatDry}`);
  const pt = Object.entries(a.paint).sort((x, y) => y[1].share - x[1].share);
  L.push(`paint ${pt.map(([k, v]) => `${k} ${v.share}% (${v.n} patches p50 ${v.p50} p90 ${v.p90} small ${v.small})`).join('; ')}`);
  L.push(`reachable from base-level border (uphill <= ${DEFAULTS.climbDeg} deg): ${a.reach.pct}% of ground, ${a.reach.islands} unreachable islands (${a.reach.islandArea} sq studs)${a.reach.at.length ? ' first at ' + a.reach.at.slice(0, 4).map(p => `(${p[0]},${p[1]}) ${p[2]}`).join(' ') : ''}; unreachable hill summits: ${a.hills.filter(f => !f.reachable).map(f => f.id).join(' ') || 'none'}`);
  L.push(`creases (slope breaks >= ~18 deg, score > ${DEFAULTS.kinkScore}, >= ${DEFAULTS.patchMin} cells): ${a.kinks.n} patches (${a.kinks.cells} cells), p99 score ${a.kinks.p99}`);
  L.push(`steep patches (>${DEFAULTS.climbDeg} deg, >= ${DEFAULTS.patchMin} cells): ${a.steepPatches.n} (${a.steepPatches.cells} cells, largest ${a.steepPatches.max})`);
  L.push(`blade ${a.blade}% pay ${a.pay}% specks ${a.specks} air-under ${a.gap}% | path(${a.path.mats}) ${a.path.share}% pieces ${a.path.pieces} width p25 ${a.path.wP25} p50 ${a.path.wP50} p90 ${a.path.wP90}`);
  const fl = (lab, f) => `${f.id} (${f.x},${f.z}) h ${f.h} prom ${f.prom} r ${f.r} r/h ${f.rOverH} climb easy/med/worst ${f.climbEasy}/${f.climbMed}/${f.climbWorst} ok ${f.climbOk}/${f.rays} closure ${f.closure}%${f.edgeRays ? ' cliff-edge rays ' + f.edgeRays : ''}`;
  const agg = (fs, lab) => {
    if (!fs.length) return `${lab}: none`;
    const h = fs.map(f => f.h), r = fs.map(f => f.r), rh = fs.map(f => f.rOverH), w = fs.map(f => f.climbWorst), e = fs.map(f => f.climbEasy);
    return `${lab}: n ${fs.length}; h p50 ${q(h, 0.5)} p90 ${q(h, 0.9)}; r p50 ${q(r, 0.5)}; r/h p10 ${q(rh, 0.1)} p50 ${q(rh, 0.5)}; climbWorst p50 ${q(w, 0.5)} p90 ${q(w, 0.9)}; climbEasy p50 ${q(e, 0.5)}; all rays <=25: ${fs.filter(f => f.climbOk === f.rays).length}/${fs.length}; no ray <=25: ${fs.filter(f => f.climbOk === 0).length}`;
  };
  L.push(agg(a.hills, 'hills'));
  for (const f of [...a.hills].sort((x, y) => y.h - x.h).slice(0, 8)) L.push('  ' + fl('hill', f));
  L.push(agg(a.bowls, 'bowls'));
  for (const f of [...a.bowls].sort((x, y) => y.h - x.h).slice(0, 8)) L.push('  ' + fl('bowl', f));
  return L.join('\n');
}

function png(w, h, px, file) {
  const crcT = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
  const crc = b => { let c = -1; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const cr = Buffer.alloc(4); cr.writeUInt32BE(crc(td)); return Buffer.concat([l, td, cr]); };
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) px.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}

const FONT = { 0: '111101101101111', 1: '010110010010111', 2: '111001111100111', 3: '111001111001111', 4: '101101111001001', 5: '111100111001111', 6: '111100111101111', 7: '111001001001001', 8: '111101111101111', 9: '111101111001111', H: '101101111101101', B: '110101110101110' };

export function overlay(g, a, file, k = 3) {
  const { NX, NZ, S, H, M } = g, D = slopes(g), W = NX * k, HH = NZ * k, px = Buffer.alloc(W * HH * 3);
  const put = (X, Y, col) => { if (X >= 0 && Y >= 0 && X < W && Y < HH) px.set(col, (Y * W + X) * 3); };
  const wx = x => Math.round(((x - g.X0) / S) * k), wy = z => HH - 1 - Math.round(((z - g.Z0) / S) * k);
  for (let r = 0; r < NZ; r++) for (let c = 0; c < NX; c++) {
    const i = r * NX + c;
    if (H[i] !== H[i]) continue;
    const dx = ((c < NX - 1 ? H[i + 1] : H[i]) - (c > 0 ? H[i - 1] : H[i])) / (2 * S), dz = ((r < NZ - 1 ? H[i + NX] : H[i]) - (r > 0 ? H[i - NX] : H[i])) / (2 * S);
    const sh = Math.max(0.2, (-dx * 0.5 + 0.62 + dz * 0.6) / Math.hypot(dx, 1, dz));
    let col = COL[M[i]] || [255, 0, 255];
    if (D[i] > 45) col = [230, 40, 40]; else if (D[i] > 25) col = [240, 150, 30]; else if (a.kinkCells && a.kinkCells[i]) col = [40, 220, 230];
    col = col.map(v => Math.min(255, v * (0.35 + 0.8 * sh)));
    for (let a2 = 0; a2 < k; a2++) for (let b2 = 0; b2 < k; b2++) put(c * k + a2, (NZ - 1 - r) * k + b2, col);
  }
  const text = (X, Y, str, col) => {
    [...str].forEach((ch, n) => { const f = FONT[ch]; if (!f) return; for (let p = 0; p < 15; p++) if (f[p] === '1') for (let u = 0; u < 2; u++) for (let v = 0; v < 2; v++) put(X + n * 8 + (p % 3) * 2 + u, Y + Math.floor(p / 3) * 2 + v, col); });
  };
  const ring = (f, col) => {
    for (let d = 0; d < 720; d++) { const t = (d * Math.PI) / 360; for (const e of [0, 1]) put(wx(f.x + Math.cos(t) * f.r) + e, wy(f.z + Math.sin(t) * f.r), col); }
    for (let d = -4; d <= 4; d++) { put(wx(f.x) + d, wy(f.z), col); put(wx(f.x), wy(f.z) + d, col); }
    text(wx(f.x) + 4, wy(f.z) + 3, f.id, [0, 0, 0]); text(wx(f.x) + 3, wy(f.z) + 2, f.id, col);
  };
  for (const f of a.hills) ring(f, f.climbOk === f.rays ? [255, 255, 255] : [255, 0, 0]);
  for (const f of a.bowls) ring(f, f.climbOk > 0 ? [0, 60, 255] : [255, 0, 200]);
  png(W, HH, px, file);
}

function selftest() {
  const cos = (d, r) => (d >= r ? 0 : 0.5 + 0.5 * Math.cos((Math.PI * d) / r));
  const cases = [
    { name: 'mound h20 r100', at: [300, 300], h: 20, r: 100, sign: 1 },
    { name: 'steep hill h30 r60', at: [300, 760], h: 30, r: 60, sign: 1 },
    { name: 'bowl d30 r180', at: [720, 700], h: 30, r: 180, sign: -1 },
    { name: 'dish d8 r60', at: [760, 250], h: 8, r: 60, sign: -1 },
  ];
  const tilt = 0.03;
  const g = synth(0, 0, 257, 257, 4, (x, z) => 100 + tilt * x + cases.reduce((s, k) => s + k.sign * k.h * cos(Math.hypot(x - k.at[0], z - k.at[1]), k.r), 0));
  const a = analyze(g);
  let fails = 0;
  const lines = [];
  for (const k of cases) {
    const list = k.sign > 0 ? a.hills : a.bowls;
    const f = list.find(p => Math.hypot(p.x - k.at[0], p.z - k.at[1]) < 12);
    const flank = Math.atan((k.h * Math.PI) / (2 * k.r)) * 180 / Math.PI;
    const tiltDeg = Math.atan(tilt) * 180 / Math.PI;
    const ok = f && Math.abs(f.h - k.h) <= 0.12 * k.h + 1 && Math.abs(f.r - k.r) <= 0.12 * k.r && f.climbWorst <= flank + tiltDeg + 1 && f.climbWorst >= flank - 1.5 && (flank + tiltDeg <= 25) === (f.climbOk === f.rays);
    if (!ok) fails++;
    lines.push(`${ok ? 'PASS' : 'FAIL'} ${k.name}: ${f ? `h ${f.h} r ${f.r} climb ${f.climbEasy}..${f.climbWorst} ok ${f.climbOk}/${f.rays}` : 'not found'} (designed flank ${r1(flank)} + tilt ${r1(tiltDeg)})`);
  }
  const extra = a.hills.length + a.bowls.length - cases.length;
  if (extra !== 0) { fails++; lines.push(`FAIL ${extra} extra features: ${JSON.stringify([...a.hills, ...a.bowls].map(f => [f.x, f.z, f.h]))}`); } else lines.push('PASS no phantom features');
  const reachOk = a.hills.find(p => Math.hypot(p.x - 300, p.z - 300) < 12)?.reachable === true && a.hills.find(p => Math.hypot(p.x - 300, p.z - 760) < 12)?.reachable === false;
  if (!reachOk) fails++;
  lines.push(`${reachOk ? 'PASS' : 'FAIL'} reachability: 17 deg mound summit reachable, 38 deg hill summit not (${a.reach.pct}% of ground reachable, ${a.reach.islands} islands)`);
  const plat = (x, z, ramp) => { const cl = Math.min(1, Math.max(0, (z - 200) / 12)); let h = 100 + 60 * cl; if (ramp && x > 180 && x < 240 && z < 212) h = Math.max(h, 100 + 60 * Math.min(1, Math.max(0, z / 212))); return h; };
  const ra = analyze(synth(0, 0, 101, 101, 4, (x, z) => plat(x, z, true)), { start: '20,20' }), rb = analyze(synth(0, 0, 101, 101, 4, (x, z) => plat(x, z, false)), { start: '20,20' });
  const platOk = ra.reach.pct > 90 && rb.reach.pct < 60;
  if (!platOk) fails++;
  lines.push(`${platOk ? 'PASS' : 'FAIL'} plateau behind a 79 deg cliff: with a 16 deg ramp ${ra.reach.pct}% reachable, without ${rb.reach.pct}%`);
  let seed = 7;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647 - 0.5);
  const lipBowl = (d, r, D, lip) => (d < r ? -D * cos(d, r) : 0) + lip * cos(Math.abs(d - 1.1 * r), 0.3 * r);
  const g2 = synth(0, 0, 257, 257, 4, (x, z) => {
    const pair = Math.max(30 * cos(Math.hypot(x - 250, z - 250), 150), 30 * cos(Math.hypot(x - 430, z - 250), 150));
    const roll = 5 * Math.sin(x / 70) * Math.cos(z / 90);
    const hill = z > 480 ? 25 * cos(Math.hypot(x - 720, z - 760), 120) : 0;
    const bowl = lipBowl(Math.hypot(x - 300, z - 760), 150, 24, 5);
    return 100 + pair + roll * (1 - cos(Math.max(0, x - 480), 160)) + hill + bowl + rnd() * 0.5;
  });
  const b = analyze(g2);
  const pa = b.hills.find(p => Math.hypot(p.x - 250, p.z - 250) < 16), pb = b.hills.find(p => Math.hypot(p.x - 430, p.z - 250) < 16);
  const saddle = 30 * cos(90, 150), pairOk = pa && pb && Math.abs(pa.prom - (30 - saddle)) <= 2.5 && Math.abs(pb.prom - (30 - saddle)) <= 2.5;
  if (!pairOk) fails++;
  lines.push(`${pairOk ? 'PASS' : 'FAIL'} overlapping pair 180 apart (r 150): prominence ${pa ? pa.prom : '-'} / ${pb ? pb.prom : '-'} vs saddle-derived ${r1(30 - saddle)}`);
  const hr = b.hills.find(p => Math.hypot(p.x - 720, p.z - 760) < 20);
  const hrOk = hr && Math.abs(hr.r - 120) <= 0.15 * 120 && hr.h >= 22 && hr.h <= 34 && hr.climbWorst <= Math.atan((25 * Math.PI) / 240) * 180 / Math.PI + 5;
  if (!hrOk) fails++;
  lines.push(`${hrOk ? 'PASS' : 'FAIL'} hill h25 r120 on 5-stud rolling + 0.5 noise: ${hr ? `h ${hr.h} r ${hr.r} worst ${hr.climbWorst}` : 'not found'} (flank 18.1 + rolling)`);
  const bl = b.bowls.find(p => Math.hypot(p.x - 300, p.z - 760) < 16);
  const blOk = bl && Math.abs(bl.h - 29) <= 2.5 && bl.climbWorst <= 15.5;
  if (!blOk) fails++;
  lines.push(`${blOk ? 'PASS' : 'FAIL'} bowl r150 depth 24 + lip 5 at 1.1r (K.bowl shape) with noise: ${bl ? `depth ${bl.h} r ${bl.r} wall ${bl.climbWorst}` : 'not found'} (want depth 29 +-2.5, wall <= 15.5)`);
  const cr = analyze(synth(0, 0, 101, 101, 4, (x, z) => 100 + (x > 200 ? (x - 200) * Math.tan((20 * Math.PI) / 180) : 0)));
  const cr10 = analyze(synth(0, 0, 101, 101, 4, (x, z) => 100 + (x > 200 ? (x - 200) * Math.tan((10 * Math.PI) / 180) : 0)));
  const offSaddle = b.kinks.at.filter(([x, z]) => Math.abs(x - 340) > 24 || Math.abs(z - 250) > 160).length;
  const crOk = a.kinks.n === 0 && b.kinks.n >= 1 && offSaddle === 0 && cr.kinks.n >= 1 && cr10.kinks.n === 0;
  if (!crOk) fails++;
  lines.push(`${crOk ? 'PASS' : 'FAIL'} creases: smooth hills/bowls ${a.kinks.n} (want 0), hard-max hill pair ${b.kinks.n} on the saddle line + ${offSaddle} elsewhere (want >= 1 + 0), a 20 deg slope break ${cr.kinks.n} patch (want >= 1), 10 deg break ${cr10.kinks.n} (want 0, below threshold)`);
  const ca = Math.cos(0.6), sa = Math.sin(0.6);
  const el = analyze(synth(0, 0, 151, 151, 4, (x, z) => { const u = (x - 300) * ca + (z - 300) * sa, v = -(x - 300) * sa + (z - 300) * ca; return 100 + 24 * cos(Math.hypot(u / 170, v / 100), 1); }));
  const ef = el.hills[0], shortFlank = Math.atan((24 * Math.PI) / 200) * 180 / Math.PI;
  const elOk = el.hills.length === 1 && ef.r >= 95 && ef.r <= 175 && Math.abs(ef.climbWorst - shortFlank) <= 1.5 && Math.abs(ef.h - 24) <= 2;
  if (!elOk) fails++;
  lines.push(`${elOk ? 'PASS' : 'FAIL'} rotated ellipse rx 170 rz 100 h 24: ${ef ? `r ${ef.r} (between axes) worst ${ef.climbWorst} vs short-axis flank ${r1(shortFlank)}, h ${ef.h}` : 'not found'}`);
  const flatG = synth(0, 0, 101, 101, 4, () => 100);
  const fa = analyze(flatG);
  const flatOk = fa.flat === 100 && fa.hills.length === 0 && fa.bowls.length === 0;
  if (!flatOk) fails++;
  lines.push(`${flatOk ? 'PASS' : 'FAIL'} flat plane: flat ${fa.flat}% hills ${fa.hills.length} bowls ${fa.bowls.length}`);
  const tt = Math.tan((10 * Math.PI) / 180), dg = v => (Math.atan(v) * 180) / Math.PI;
  const tp = analyze(synth(0, 0, 151, 151, 4, x => 100 + tt * x));
  const tm = analyze(synth(0, 0, 151, 151, 4, (x, z) => 100 + tt * x + 20 * cos(Math.hypot(x - 300, z - 300), 100)));
  const tb = analyze(synth(0, 0, 151, 151, 4, (x, z) => 100 + tt * x - 20 * cos(Math.hypot(x - 300, z - 300), 120)));
  const crit = (A, r) => { const u = Math.asin((tt * 2 * r) / (A * Math.PI)); return [(r * u) / Math.PI, (r * (Math.PI - u)) / Math.PI]; };
  const [m1, m2] = crit(20, 100), mound = d => 10 + 10 * Math.cos((Math.PI * d) / 100);
  const mProm = tt * m1 + mound(m1) - (tt * m2 + mound(m2)), mWorst = dg(tt + (20 * Math.PI) / 200);
  const [b1, b2] = crit(20, 120), dish = d => -10 - 10 * Math.cos((Math.PI * d) / 120);
  const bProm = dish(b2) - tt * b2 - (dish(b1) - tt * b1), bWorst = dg(tt + (20 * Math.PI) / 240);
  const th = tm.hills[0], tbw = tb.bowls[0];
  const tiltOk = tp.hills.length + tp.bowls.length === 0 && tm.hills.length === 1 && tm.bowls.length === 0 && tb.bowls.length === 1 && tb.hills.length === 0
    && Math.abs(th.x - (300 + m1)) <= 6 && Math.abs(th.prom - mProm) <= 1 && Math.abs(th.climbWorst - mWorst) <= 1.5
    && Math.abs(tbw.x - (300 - b1)) <= 6 && Math.abs(tbw.prom - bProm) <= 1 && Math.abs(tbw.climbWorst - bWorst) <= 1.5;
  if (!tiltOk) fails++;
  lines.push(`${tiltOk ? 'PASS' : 'FAIL'} 10 deg tilt: plane ${tp.hills.length + tp.bowls.length} features; mound h20 r100 prom ${th ? th.prom : '-'} vs col-derived ${r1(mProm)}, worst ${th ? th.climbWorst : '-'} vs ${r1(mWorst)}; bowl d20 r120 spill depth ${tbw ? tbw.prom : '-'} vs ${r1(bProm)}, wall ${tbw ? tbw.climbWorst : '-'} vs ${r1(bWorst)}`);
  console.log(lines.join('\n'));
  process.exit(fails ? 1 : 0);
}

if (process.argv[1] && process.argv[1].endsWith('analyze.mjs')) {
  const args = process.argv.slice(2);
  if (args[0] === '--selftest') selftest();
  else if (args[0] === '--compare') {
    const [A, B] = args.slice(1, 3).map(f => JSON.parse(fs.readFileSync(f, 'utf8')));
    const med = (l, k) => { const v = l.map(f => f[k]).sort((x, y) => x - y); return v.length ? v[v.length >> 1] : NaN; };
    const rows = [
      ['flat % (<3 deg)', A.flat, B.flat], ['slope > 25 %', A.slope.over25, B.slope.over25], ['steep patches', A.steepPatches.n, B.steepPatches.n],
      ['relief/100 p50', A.relief100.p50, B.relief100.p50], ['bump', A.bump, B.bump], ['reachable %', A.reach.pct, B.reach.pct],
      ['hills', A.hills.length, B.hills.length], ['hill h p50', med(A.hills, 'h'), med(B.hills, 'h')], ['hill worst approach p50', med(A.hills, 'climbWorst'), med(B.hills, 'climbWorst')],
      ['hills all rays <= 25', A.hills.filter(f => f.climbOk === f.rays).length, B.hills.filter(f => f.climbOk === f.rays).length],
      ['bowls', A.bowls.length, B.bowls.length], ['bowl depth p50', med(A.bowls, 'h'), med(B.bowls, 'h')], ['bowl wall p50', med(A.bowls, 'climbWorst'), med(B.bowls, 'climbWorst')],
      ['blade %', A.blade, B.blade], ['specks', A.specks, B.specks],
    ];
    console.log(`compare ${A.name} -> ${B.name}`);
    for (const [k, x, y] of rows) console.log(`${k.padEnd(26)} ${String(x).padStart(8)} -> ${String(y).padEnd(8)} ${typeof x === 'number' && typeof y === 'number' && x === x && y === y ? (y - x >= 0 ? '+' : '') + r1(y - x) : ''}`);
  }
  else {
    const file = args[0];
    if (!file) { console.log('usage: node analyze.mjs <scan.grab> [name] [key=value ...] | --selftest | --compare before.json after.json   (writes <scan>.json and <scan>.png)'); process.exit(1); }
    const name = args[1] || file.replace(/^.*[\\/]/, '').replace(/\.grab$/, '');
    const opt = {};
    for (const kv of args.slice(2)) { const [k, v] = kv.split('='); opt[k] = isNaN(+v) ? v : +v; }
    const g = load(file), a = analyze(g, opt), o2 = opt;
    const base = file.replace(/\.grab$/, '');
    fs.writeFileSync(base + '.json', JSON.stringify({ name, at: new Date().toISOString(), ...a }, null, 1));
    overlay(g, a, base + '.png', o2.scale || DEFAULTS.scale);
    console.log(summary(name, a));
    console.log('verdict vs user targets (whole scan area; reference/grammar.md):' + String.fromCharCode(10) + '  ' + verdict(a).join(String.fromCharCode(10) + '  '));
    console.log(`-> ${base}.json, ${base}.png (white ring = hill all rays <=25, red = some ray >25; blue = bowl with an exit <=25, magenta = no exit <=25; orange cells >25 deg, red >45)`);
  }
}
