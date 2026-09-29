import fs from 'fs';
import { load, slopes } from '../analyze/analyze.mjs';

const near = (list, x, z, d = 40) => list.find(f => Math.hypot(f.x - x, f.z - z) <= d);
const val = (f, k) => (f ? f[k] : NaN);

export const SPECS = {
  river: (a) => [['steep patches (water excluded) along the river banks', a.steepPatches.n, '==', 0, 'feedback R5: banks rollable <= 25']],
  freeroam: (a, c, g, core) => {
    const W3 = [[60, 150], [200, 230], [330, 330]];
    const segD = (px, pz, [ax, az], [bx, bz]) => { const dx = bx - ax, dz = bz - az, t = Math.max(0, Math.min(1, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz))); return Math.hypot(px - ax - dx * t, pz - az - dz * t); };
    const wallZone = ([x, z]) => Math.min(segD(x - c.x, z - c.z, W3[0], W3[1]), segD(x - c.x, z - c.z, W3[1], W3[2])) < 244;
    return [
      ['every hill: all approaches <= 25 (non-edge rays)', a.hills.filter(f => f.steepOpen > 0).length, '==', 0, 'feedback R7'],
      ['every bowl: all exits <= 25 (rays ending on the wall-ride piece excluded)', a.bowls.filter(f => (f.steepDirs || []).some(([ang, , foot]) => !wallZone([f.x + Math.cos((ang * Math.PI) / 180) * foot, f.z + Math.sin((ang * Math.PI) / 180) * foot]))).length, '==', 0, 'feedback R5'],
      ['steep patches outside the wall-ride face', a.steepPatches.at.filter(p => !wallZone(p)).length, '==', 0, 'feedback R7'],
      ['crease patches in the core outside the wall-ride', a.kinks.at.filter(p => !wallZone(p) && Math.max(Math.abs(p[0] - c.x), Math.abs(p[1] - c.z)) < 376).length, '==', 0, 'feedback R6'],
      ['ground reachable from base level', a.reach.pct, '>=', 99.5, 'feedback R5/R7'],
      ['free-roam flat (<3 deg) % of core, lane floors, bowl bottoms (0.5 r) and the wall-ride strip excluded', (() => {
        const D = slopes(g); let n = 0, fl = 0;
        for (let i = 0; i < g.H.length; i++) {
          const x = g.X0 + (i % g.NX) * g.S, z = g.Z0 + Math.floor(i / g.NX) * g.S;
          if (Math.max(Math.abs(x - c.x), Math.abs(z - c.z)) >= 376 || g.M[i] === 'M' || g.M[i] === 'D' || wallZone([x, z])) continue;
          if (a.bowls.some(b => Math.hypot(x - b.x, z - b.z) < 0.5 * b.r)) continue;
          n++; if (D[i] < 3) fl++;
        }
        return Math.round((fl / Math.max(1, n)) * 1000) / 10;
      })(), '<=', 8, 'lab brief, feedback R2/R10: flat meadow is a failure (designed floors are not meadow)'],
      ['sun highlight (Limestone) % of core outside the bowl lip bands (lips are R12 feature paint)', (() => {
        const lips = [[-200, 180, 150], [220, -250, 110]];
        let n = 0, lime = 0;
        for (let i = 0; i < g.H.length; i++) {
          const x = g.X0 + (i % g.NX) * g.S - c.x, z = g.Z0 + Math.floor(i / g.NX) * g.S - c.z;
          if (Math.max(Math.abs(x), Math.abs(z)) >= 376 || lips.some(([bx, bz, r]) => { const d = Math.hypot(x - bx, z - bz); return d > 0.95 * r && d < 1.3 * r; })) continue;
          n++; if (g.M[i] === 'S') lime++;
        }
        return Math.round((lime / Math.max(1, n)) * 1000) / 10;
      })(), 'in', [10, 20], 'scans v4 10.7 / A3 19.2, R14'],
      ['isolated paint cells per 10,000', Math.round((a.specks / a.grid.cells) * 1e5) / 10, '<=', 1, 'feedback R6; single cells at 3-tone junctions are raycast sampling (test paint holds 0)'],
      ['lane width p50', a.path.wP50, '>=', 96, 'feedback R3'],
    ];
  },
  cliffadd: (a, c) => {
    const all = [...a.hills, ...a.open];
    const tops = [near(all, c.x - 120, c.z + 40, 50), near(all, c.x + 140, c.z + 60, 50)];
    const off = a.steepPatches.at.filter(([x, z]) => !(Math.abs(z - c.z + 120) < 110) && !(Math.abs(Math.abs(x - c.x) - 420) < 200));
    return [
      ['TOPS mounds stacked on the additive cliff (on = cliff) found (hill or plateau-edge ridge)', tops.filter(Boolean).length, '==', 2, 'v4 TOPS, K.mound on'],
      ['TOPS prominence (mound h 18 / 16 above the plateau)', Math.min(...tops.map(f => (f ? f.prom : 0))), '>=', 12, 'K.mound on keeps the mound height on the cliff'],
      ['TOPS worst approach deg', Math.max(...tops.map(f => (f ? f.climbWorst : 99))), '<=', 22.75, 'feedback R5/R7'],
      ['steep patches away from the cliff face band and its tapered ends', off.length, '==', 0, 'feedback R7'],
    ];
  },
  caves: (a, c) => {
    const off = a.steepPatches.at.filter(([x, z]) => {
      const u = x - c.x, v = z - c.z;
      return !(Math.abs(v - 120) < 110) && !(Math.abs(v + 180) < 90 && u > -200 && u < 170);
    });
    return [['steep patches outside the cliff face band and the ravine portal notches', off.length, '==', 0, 'feedback R5: no sheer walls in free roam']];
  },
  trough: (a) => [
    ['steep patches > 25 deg', a.steepPatches.n, '==', 0, 'feedback R5/R7: every depression keeps rollable sides <= 25'],
    ['trough site slope p90', a.slope.p90, '<=', 22.75, 'SKILL rule banks <= 22 (+0.75 noise)'],
  ],
  paint: (a, c, g, core) => {
    const L = [0.755, 0.553, -0.352], ln = Math.hypot(...L);
    const sun = L.map(v => v / ln), acc = {};
    for (let r = 1; r < g.NZ - 1; r++) for (let q = 1; q < g.NX - 1; q++) {
      const i = r * g.NX + q, x = g.X0 + q * g.S - c.x, z = g.Z0 + r * g.S - c.z;
      if (Math.max(Math.abs(x), Math.abs(z)) > 346) continue;
      const dx = (g.H[i + 1] - g.H[i - 1]) / (2 * g.S), dz = (g.H[i + g.NX] - g.H[i - g.NX]) / (2 * g.S), nl = Math.hypot(dx, 1, dz);
      const lit = (-dx * sun[0] + sun[1] - dz * sun[2]) / nl - sun[1];
      const m = g.M[i];
      acc[m] = acc[m] || [0, 0];
      acc[m][0] += lit; acc[m][1]++;
    }
    const mean = m => (acc[m] ? Math.round((acc[m][0] / acc[m][1]) * 1000) / 1000 : NaN);
    const order = [mean('G'), mean('L'), mean('T'), mean('S')];
    const ordered = order.every((v, k) => k === 0 || v > order[k - 1]);
    const banned = ['C', 'P', 'Z'].reduce((t, m) => t + (acc[m] ? acc[m][1] : 0), 0);
    const tones = ['G', 'L', 'T', 'S'].filter(m => acc[m] && acc[m][1] > 50).length;
    return [
      [`sun exposure order Grass < Leafy < Slate < Limestone (${order.join(' < ')})`, ordered ? 1 : 0, '==', 1, 'feedback R14: 4-tone fake sun'],
      ['tones present (>50 cells each)', tones, '==', 4, 'feedback R14: Limestone, LeafyGrass, Grass and Slate'],
      ['specks (cells with no same-material 4-neighbour)', a.specks, '==', 0, 'feedback R6: no isolated paint cells'],
      ['banned material cells (Cobblestone/Pavement/Concrete)', banned, '==', 0, 'feedback R11/R12'],
      ['core highlight (Limestone) %', core.lime, 'in', [10, 20], 'scans: claude_big_test v4 10.7, user A3 19.2; feedback R14 highlight more'],
      ['steep patches > 25 deg', a.steepPatches.n, '==', 0, 'feedback R7'],
    ];
  },
  cliff: (a, c, g) => {
    const D = slopes(g);
    let steep = 0, steepRock = 0, gentle = 0, gentleRock = 0;
    for (let i = 0; i < g.H.length; i++) {
      const x = g.X0 + (i % g.NX) * g.S - c.x, z = g.Z0 + Math.floor(i / g.NX) * g.S - c.z;
      if (Math.max(Math.abs(x), Math.abs(z)) > 346) continue;
      const rock = g.M[i] === 'R' || g.M[i] === 'B';
      if (D[i] >= 40) { steep++; if (rock) steepRock++; }
      if (D[i] < 25) { gentle++; if (rock) gentleRock++; }
    }
    const off = a.steepPatches.at.filter(([x, z]) => !(Math.abs(z - c.z - 60) < 110));
    const tops = [near(a.hills, c.x - 150, c.z + 230, 50), near(a.hills, c.x + 170, c.z + 240, 50)];
    const ramp = [];
    for (let i = 0; i < g.H.length; i++) if ((g.M[i] === 'M' || g.M[i] === 'D') && D[i] === D[i]) ramp.push(D[i]);
    ramp.sort((p, q) => p - q);
    return [
      ['cells >= 40 deg painted Rock/Basalt %', Math.round((steepRock / Math.max(1, steep)) * 1000) / 10, '>=', 90, 'feedback R12: stone = Rock + Basalt on every face (paint by slope)'],
      ['cells < 25 deg painted Rock/Basalt %', Math.round((gentleRock / Math.max(1, gentle)) * 1000) / 10, '<=', 2, 'feedback R5: open ground stays grass-family'],
      ['steep patches away from the cliff face band', off.length, '==', 0, 'feedback R7'],
      ['TOPS mounds found on the plateau', tops.filter(Boolean).length, '==', 2, 'v4 TOPS'],
      ['ramp floor slope p95 deg', Math.round(ramp[Math.floor(ramp.length * 0.95)] * 10) / 10, '<=', 15, 'movement.md: long gentle ramps <= 15'],
      ['TOPS worst approach deg', Math.max(...tops.map(f => (f ? f.climbWorst : 99))), '<=', 22.75, 'feedback R5/R7: hills <= 20 + guard 22 + 0.75 noise'],
    ];
  },
  bore: (a, c) => {
    const off = a.steepPatches.at.filter(([x, z]) => !(Math.abs(z - c.z) < 110 && Math.abs(x - c.x) < 260));
    const host = near(a.hills, c.x, c.z, 80);
    return [
      ['steep patches outside the portal notches', off.length, '==', 0, 'feedback R7: only portal notches may be steep'],
      ['host hill found', host ? 1 : 0, '==', 1, 'grade target'],
      ['host hill approaches > 25 deg (rays that do not end at a lined portal edge)', host ? host.steepOpen : 99, '==', 0, 'feedback R7: every approach to every mound <= 25'],
    ];
  },
  paths: (a, c) => {
    const off = a.steepPatches.at.filter(([x, z]) => !(z - c.z > 40 && z - c.z < 200));
    return [
      ['steep patches outside the wall-ride face zone', off.length, '==', 0, 'feedback R7: only portal notches and wall-ride faces may be steep'],
      ['lane floor width p50 (halfW 52)', a.path.wP50, '>=', 96, 'feedback R3: paths >= 2x, A2 lanes 96-168 (scan A2 104/120/155)'],
    ];
  },
  bowl: (a, c) => {
    const big = near(a.bowls, c.x - 40, c.z - 40), small = near(a.bowls, c.x + 190, c.z + 190);
    return [
      ['big bowl found', big ? 1 : 0, '==', 1, 'feedback R12: bowls read'],
      ['big bowl rim radius (190)', val(big, 'foot'), 'in', [165, 230], 'feedback R12: r 170-230'],
      ['big bowl depth rim-floor (29 + lip 5)', val(big, 'h'), 'in', [26, 38], 'feedback R12: depth ~ r/6.5'],
      ['big bowl steepest wall deg', val(big, 'climbWorst'), '<=', 15, 'feedback R6: walls <= 15'],
      ['small bowl steepest wall deg', val(small, 'climbWorst'), '<=', 15, 'feedback R6'],
      ['every bowl: all 32 exits <= 25', a.bowls.filter(f => f.climbOk < f.rays).length, '==', 0, 'feedback R5: every exit a gentle ramp'],
      ['steep patches > 25 deg', a.steepPatches.n, '==', 0, 'feedback R5: nothing steep at a bowl rim'],
    ];
  },
  ring: (a, c) => [
    ['every ring rim: all approaches <= 22', a.hills.concat(a.bowls).filter(f => f.climbWorst > 22).length, '==', 0, 'feedback R7: approaches <= 25, hills <= 20'],
    ['steep patches > 25 deg', a.steepPatches.n, '==', 0, 'feedback R7'],
  ],
  pad: (a, c, g, core) => [
    ['steep patches > 25 deg (pad blend on a hill)', a.steepPatches.n, '==', 0, 'feedback R7: every approach <= 25'],
  ],
  hillfield: (a, c, g, core) => [
    ['every hill: all 32 approaches <= 25', a.hills.filter(f => f.climbOk < f.rays).length, '==', 0, 'feedback R7: every approach to every mound <= 25'],
    ['steep patches > 25 deg', a.steepPatches.n, '==', 0, 'feedback R7'],
    ['core flat (<3 deg) %', core.flat, '<=', 8, 'feedback R2/R10: no flat ground (<= 8%)'],
    ['hills found in 600x600 core', a.hills.length, '>=', 5, 'feedback R5: features every ~250 studs'],
    ['hill h p50', a.hills.length ? [...a.hills].sort((p, q) => p.h - q.h)[a.hills.length >> 1].h : NaN, 'in', [30, 50], 'feedback R10: hills h 30-50'],
    ['core relief/100 p50', core.relief, '>=', 13.6, 'scans: lowest user area A4 13.6 (A2 15.6, A3 26.9); feedback R2/R10 more up-down'],
    ['core highlight (Limestone) %', core.lime, 'in', [10, 20], 'scans: claude_big_test v4 10.7, user A3 19.2; feedback R14 highlight more'],
  ],
  rolling: (a, c, g, core) => [
    ['steep patches > 25 deg', a.steepPatches.n, '==', 0, 'feedback R7: free roam crossable'],
  ],
  mound: (a, c) => {
    const big = near(a.hills, c.x - 110, c.z - 110), small = near(a.hills, c.x + 180, c.z + 150);
    return [
      ['big hill h (40 designed)', val(big, 'h'), 'in', [36, 44], 'recipes: mound h reads as designed'],
      ['big hill r (180 designed)', val(big, 'r'), 'in', [160, 200], 'recipes'],
      ['big hill worst approach deg', val(big, 'climbWorst'), '<=', 22, 'feedback R5/R7: hills <= 20 deg, every approach <= 25'],
      ['small hill worst approach deg', val(small, 'climbWorst'), '<=', 22, 'feedback R7'],
      ['every hill: all 32 approaches <= 25', a.hills.filter(f => f.climbOk < f.rays).length, '==', 0, 'feedback R7'],
      ['steep patches > 25 deg', a.steepPatches.n, '==', 0, 'feedback R7 + movement.md: no ball-sized patch over 25 deg'],
    ];
  },
};

const BASEF = { cliff: (x, z, c) => (z - c.z >= 60 ? 182 : 102), caves: (x, z, c) => (z - c.z >= 120 ? 192 : 102) };
function edge(g, cx, cz, half, bf) {
  const D = slopes(g);
  let seam = 0, blend = 0;
  const ring = [];
  for (let r = 0; r < g.NZ; r++) for (let c = 0; c < g.NX; c++) {
    const cheb = Math.max(Math.abs(g.X0 + c * g.S - cx), Math.abs(g.Z0 + r * g.S - cz));
    const lo = Math.min(Math.abs(g.X0 + c * g.S - cx), Math.abs(g.Z0 + r * g.S - cz));
    if (cheb > half + 4 && cheb < 504 && lo < 470) ring.push(g.H[r * g.NX + c]);
  }
  ring.sort((p, q) => p - q);
  const med = ring[ring.length >> 1];
  for (let r = 0; r < g.NZ; r++) for (let c = 0; c < g.NX; c++) {
    const i = r * g.NX + c, x = g.X0 + c * g.S, z = g.Z0 + r * g.S, cheb = Math.max(Math.abs(x - cx), Math.abs(z - cz));
    const ref = bf ? bf(x, z, { x: cx, z: cz }) : med;
    const nearStep = bf && Math.abs(bf(x, z + 6, { x: cx, z: cz }) - bf(x, z - 6, { x: cx, z: cz })) > 0;
    const lo2 = Math.min(Math.abs(x - cx), Math.abs(z - cz));
    if (cheb > half + 4 && cheb < 504 && lo2 < 470 && !nearStep) seam = Math.max(seam, Math.abs(g.H[i] - ref));
    if (cheb > half - 60 && cheb <= half + 4 && !(bf && Math.abs(bf(x, z + 40, { x: cx, z: cz }) - bf(x, z - 40, { x: cx, z: cz })) > 0)) blend = Math.max(blend, D[i]);
  }
  return { seam, blend, ringN: ring.length };
}

const [, , name, out, cxs, czs] = process.argv;
const a = JSON.parse(fs.readFileSync(`${out}/${name}.json`, 'utf8'));
const g = load(`${out}/${name}.grab`);
const c = { x: +cxs, z: +czs };
const BIG9 = { mound: 1, bowl: 1, paths: 1, bore: 1, bridge: 1, cliff: 1, paint: 1, trough: 1, caves: 1, cliffadd: 1, chunk: 1, chunkguard: 1, river: 1 };
const HALFS = { freeroam: [480, 376] };
const e = edge(g, c.x, c.z, +(process.env.HALF || (HALFS[name] ? HALFS[name][0] : BIG9[name] ? 450 : 400)), BASEF[name]);
const D = slopes(g), cs = [];
for (let r = 0; r < g.NZ; r++) for (let q = 0; q < g.NX; q++) if (Math.max(Math.abs(g.X0 + q * g.S - c.x), Math.abs(g.Z0 + r * g.S - c.z)) < (HALFS[name] ? HALFS[name][1] : BIG9[name] ? 346 : 296)) cs.push(D[r * g.NX + q]);
const pct = f => Math.round((cs.filter(f).length / cs.length) * 1000) / 10;
const half = HALFS[name] ? HALFS[name][1] : BIG9[name] ? 346 : 296, rel = [], mats = {};
for (let z0 = c.z - half; z0 + 100 <= c.z + half; z0 += 100) for (let x0 = c.x - half; x0 + 100 <= c.x + half; x0 += 100) {
  const v = [];
  for (let z = z0; z < z0 + 100; z += g.S) for (let x = x0; x < x0 + 100; x += g.S) { const i = Math.round((z - g.Z0) / g.S) * g.NX + Math.round((x - g.X0) / g.S); v.push(g.H[i]); mats[g.M[i]] = (mats[g.M[i]] || 0) + 1; }
  v.sort((p, q) => p - q); rel.push(v[Math.floor(v.length * 0.9)] - v[Math.floor(v.length * 0.1)]);
}
rel.sort((p, q) => p - q);
const nm = Object.values(mats).reduce((t, v) => t + v, 0);
const core = { flat: pct(d => d < 3), over25: pct(d => d > 25), over22: pct(d => d > 22), max: Math.round(Math.max(...cs) * 10) / 10, relief: Math.round(rel[rel.length >> 1] * 10) / 10, lime: Math.round(((mats.S || 0) / nm) * 1000) / 10 };
const coreHalf = HALFS[name] ? HALFS[name][1] : BIG9[name] ? 346 : 296;
const coreCreases = a.kinks.at.filter(([x, z]) => Math.max(Math.abs(x - c.x), Math.abs(z - c.z)) < coreHalf).length;
const creaseRow = ['crease patches in the core (slope breaks >= ~18 deg)', coreCreases, '==', 0, 'feedback R6: no straight creases, blends continuous in value and slope'];
const reachRow = ['ground reachable from base level (uphill only onto <= 25 deg cells)', a.reach.pct, '>=', 99.5, 'feedback R7/R5: every hill, bowl and plateau climbable; lone unreachable cells are mesh noise'];
const rows = [
  ['edge seam into untouched flat (max |dy|)', e.ringN > 100 ? Math.round(e.seam * 100) / 100 : NaN, '<=', 0.1, 'feedback R4: zero seam at the box edge (NaN = no untouched ring measured)'],
  ['edge blend max slope (last 60 studs)', Math.round(e.blend * 10) / 10, '<=', 25, 'feedback R3/R7: long blends, every approach <= 25'],
  ...(SPECS[name] ? SPECS[name](a, c, g, core) : []),
  ...(['mound', 'bowl', 'ring', 'pad', 'rolling', 'hillfield', 'paint', 'trough', 'cliff', 'paths'].includes(name) ? [reachRow] : []),
  ...(['mound', 'bowl', 'ring', 'pad', 'rolling', 'hillfield', 'paint', 'trough'].includes(name) ? [creaseRow] : []),
];
let fail = 0;
for (const [label, v, op, t, rule] of rows) {
  const ok = op === '<=' ? v <= t : op === '>=' ? v >= t : op === '==' ? v === t : op === 'in' ? v >= t[0] && v <= t[1] : false;
  if (!ok) fail++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}: ${label} = ${v} (want ${op} ${JSON.stringify(t)}) [${rule}]`);
}
const s = fs.readFileSync(`${out}/${name}.txt`, 'utf8').split('\n');
console.log(s.filter(l => /^(slope|hills|bowls|not counted|  [HB]\d)/.test(l)).map(l => '  ' + l.slice(0, 260)).join('\n'));
process.exitCode = fail ? 1 : 0;
