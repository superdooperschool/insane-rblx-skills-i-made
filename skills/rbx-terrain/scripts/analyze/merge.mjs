import fs from 'fs';
import { load } from './analyze.mjs';

const [, , out, ...files] = process.argv;
if (!out || !files.length) { console.log('usage: node merge.mjs out.grab a.grab b.grab ...  (same step; later files win on overlap)'); process.exit(1); }
const gs = files.map(load), S = gs[0].S;
if (gs.some(g => g.S !== S)) throw new Error('grabs have different steps');
const X0 = Math.min(...gs.map(g => g.X0)), Z0 = Math.min(...gs.map(g => g.Z0));
const X1 = Math.max(...gs.map(g => g.X0 + (g.NX - 1) * S)), Z1 = Math.max(...gs.map(g => g.Z0 + (g.NZ - 1) * S));
const NX = (X1 - X0) / S + 1, NZ = (Z1 - Z0) / S + 1;
const cells = new Array(NX * NZ).fill('AAA_A');
const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const ch = n => B64[n];
for (const g of gs) for (let r = 0; r < g.NZ; r++) for (let c = 0; c < g.NX; c++) {
  const i = r * g.NX + c, h = g.H[i];
  if (h !== h) continue;
  const q = Math.max(0, Math.min(262143, Math.round((h + 2048) * 16)));
  const R = (g.Z0 - Z0) / S + r, C = (g.X0 - X0) / S + c;
  cells[R * NX + C] = ch(q >> 12) + ch((q >> 6) & 63) + ch(q & 63) + g.M[i] + ch(Math.min(63, g.GAP[i] / 2));
}
const rows = [`#grab ${X0} ${Z0} ${NX} ${NZ} ${S}`];
for (let r = 0; r < NZ; r++) rows.push('|' + cells.slice(r * NX, (r + 1) * NX).join(''));
fs.writeFileSync(out, rows.join('\n'));
console.log(`merged ${files.length} grabs -> ${out} (${NX} x ${NZ} @ ${S})`);
