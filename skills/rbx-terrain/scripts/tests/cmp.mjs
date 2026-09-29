import { load, slopes } from '../analyze/analyze.mjs';
const [, , fa, fb, cxs, czs, tol = '0.35', maxSlope = '91'] = process.argv;
const a = load(fa), b = load(fb), D = slopes(b);
let mx = 0, n = 0, at = null;
let skipped = 0;
const near = new Uint8Array(a.H.length);
for (let i = 0; i < a.H.length; i++) if (D[i] > +maxSlope) for (let dr = -2; dr <= 2; dr++) for (let dc = -2; dc <= 2; dc++) { const j = i + dr * b.NX + dc; if (j >= 0 && j < near.length) near[j] = 1; }
for (let i = 0; i < a.H.length; i++) {
  if (near[i]) { skipped++; continue; }
  const d = Math.abs(a.H[i] - b.H[i]);
  if (d > +tol) n++;
  if (d > mx) { mx = d; at = [a.X0 + (i % a.NX) * a.S - +cxs, a.Z0 + Math.floor(i / a.NX) * a.S - +czs]; }
}
console.log(`${mx <= +tol ? 'PASS' : 'FAIL'} chunk seam: whole vs 4 chunks max height diff ${mx.toFixed(2)} (cells > ${tol}: ${n}, worst at ${JSON.stringify(at)}${skipped ? `, ${skipped} cells within 8 studs of faces steeper than ${maxSlope} deg skipped` : ''})`);
process.exitCode = mx <= +tol ? 0 : 1;
