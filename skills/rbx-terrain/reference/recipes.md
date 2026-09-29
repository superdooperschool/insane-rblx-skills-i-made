# Recipes and parameters that passed

Every row below is a lab test in `scripts/tests/` (far sites at x -30000.., built, measured, erased). Run
`bash scripts/tests/run_all.sh` to see the live numbers; `bash scripts/tests/run.sh <test> keep` keeps one site
standing to render it. A recipe is `return K.run(box, maskOpts, setup(G) -> features, composeOpts, checks(G))`.

## Defaults you get without asking (compose)

| Default | Value | Turn off / change |
|---|---|---|
| climb guard | free cells <= 22 deg: local Lipschitz envelopes (sources <= 160 studs), changes only within 56 + 48 studs of a violation, capped 16 studs; `f.steep` pieces exempt | `climb`, `guardSource`, `guardReach`, `guardFeather`, `guardCap` |
| deliberate faces | cells >= 55 deg plus their connected >= 35 deg body (cliff shoulders and end tapers) + 3 cells are kept; kept cells bordering free ground anchor the guard (no step at the face) | `faceDeg`, `faceGrow`, `faceBand` |
| rock paint neighbours | a cell is rock-painted only with >= 4 of 8 neighbours also >= 35 deg (lone rock specks came from slopes hovering at 35) | via `rock` |
| sun paint | 4 tones: Grass shadow, LeafyGrass flat, Slate lit (> 0.05), Limestone brightest (> 0.12); sun (0.755, 0.553, -0.352) | `sun = false` (old rule paint), `shade = "lit"`, `sunHi = ...` |
| rock paint | K.stone (Rock/Basalt noise) on every unpainted cell >= 35 deg | `rock = false` or `{deg, mat}` |
| despeck | up to 6 passes; a lone cell (no same-material 4-neighbour, rock-painted cells included) takes its 8-neighbour majority | `despeck = n` |
| union of overlapping pieces | smooth max/min k = 12 (k 4 left a crease in the saddle of two mounds) | `unionK = k` |
| edge paint fade | ruled paint dithers back to the untouched material through the feather | `edgeFade = false` |
| old talus limiter | off (it flattened wall-rides to 39 deg) | `maxSlope = 34` |
| mask corners | rounded, radius 0.15 x box size (world coords, same in chunks) | maskOpts `round = 0` |

## Pieces

| Piece | Call (test) | Numbers that passed |
|---|---|---|
| Hill | `K.mound{x,z,r,h}` (mound) | h 40 r 180: measured h 39.2, r 180, worst approach 20.6. WARN above 20.5 deg design flank (r < 4.5 h) |
| Stacked hill | `K.mound{..., on = feature}` | mound height added to another additive piece (TOPS on an additive cliff) |
| Hill field | `K.hillField{rect, seed, skip}` defaults grid 150, h 28-44, union max; + `K.rolling{}` (hillfield, freeroam) | 600 x 600 core: 9 placed, 6 detected, h p50 33, core flat 4.1, relief/100 p50 13.7, 0 steep patches, 0 creases. `union = "sum"` (v4 additive) stacks to h 70 |
| Rolling | `K.rolling{}` defaults amp 24/600, 8/240, 7/110, warp 60 (rolling) | 0 steep patches with the guard; pair it with a hill field for flat <= 8 |
| Bowl | `K.bowl{x,z,r = 190, depth = 29, lip = 5}` (bowl) | rim 202, depth 33.8, walls 14.9 (lip sits at 1.1r, width 0.3r; planned wall 13.5). WARN when the planned wall > 13.8 (depth > ~r/6.4): builds add 1.0-1.4 deg |
| Donut | `K.ring{R = 70, w = 24, h = 6, dish = 3}` (ring) | w auto-widens so the rim stays <= 20 (w 16 h 8 -> w 35; it was 34 deg) |
| Pad under a 3D piece | `K.pad{x,z,r,blend}` (pad) | blend grows with the height it bridges (<= 20 deg); on a 36-high hill: 0 steep patches (was a 44 deg cut) |
| Main lane | `K.path{mode = "lane", halfW = 52, bank = 16, depth = 8, floorMat = K.DIRT}` (paths) | floor width 107 (A2 104/120/155); banks widen with the drop to <= 22 |
| Berm / trough | `K.path{mode = "berm", h = 15}`, `{mode = "trough", halfW = 40, depth = 18}` (paths, trough) | halfW auto-widens (berm 40 -> 65, trough 40 -> 70); bends bank outward |
| Wall-ride | `K.path{mode = "wall", bank = 240, inner = 40, R = 24, ang = 74, h = 34, backDeg = 20, crestR = 12, taper = 140}` (paths) | face 12-ray median 73.6, back 20.4, crest 2nd difference 0.49 (blendK default 16; 6 left creases where the wall meets hills). Needs a flat or `baseAt` floor |
| Tunnel hill | host `K.mound{r = 260, h = 56}` + `K.path{mode = "dive", halfW = 40, bank = 200, covers = {{x, z, len = 170}}, dips = {{x, z, depth = 14, flat = 200}}}` + `K.slot{halfW = 30, arch = true, prof: roofed at yf + 50 when ground >= yf + 58}` (bore) | clear 52, roof 19.5, arch widths within 8 of a true arch, lining Rock 36 / Mud 29 / Ground 34, host 0 approaches > 25 |
| Ravine under a hill | `K.path{mode = "dive", floor = fn(s, L), covers = {{fFrom = 0.36, fTo = 0.62}}, notchDeg = 42}` + `K.slot` on the same pts (caves) | clear 48, roof 11-18 |
| Cave pair joined underground | `K.slot{arch = true, prof: yf = base - 40 x (0.5 - 0.5 cos(2 pi s / L)), roofed at yf + 50}` through a cliff (caves) | clear >= 48 at 5 points, roof >= 46, dips 36 below the portals |
| Land bridge | `K.archBridge(G, name, {a, b, ya, yb, width = 28, floor, clear = 50, thick = 10, open = 70})` over a dive gully (bridge, built in 4 chunks, crosses the chunk line) | underpass 52, deck max 4-stud step 1.02, max slope 12.3, whole vs chunks 0.00 |
| River | `K.path{mode = "lane", halfW = 40, bank = 60, depth = 14, floorMat = Sand, calm = {110, 200}}` + `K.water(G, name, river, {depth = 9})` (river, 4 chunks) | water on 31/31 centre samples, surface within 2.5 of floor + 9, 0 wet bank tops, 0 steep patches, seam 0.00, pass 2 identical |
| Cliff (create) | `K.cliff{pts, outside, h, w = 50, rel, ends}` additive, face exempt from the guard | ends taper over `ends` |
| Cliff (revamp a step) | `K.cliff{..., base = low ground y, reach = 300}` + maskOpts `maxSlope = 91` (cliff) | face median 60.6, full-edge coverage, max face dent 1.3 (no holes), rock on 93.7% of >= 40 deg cells, TOPS worst 21.6, ramp p95 13.4 |
| Ramp up a cliff | `K.path{mode = "ramp", halfW = 30, bank = 40, y0, y1 = base + cliff.hAt(end)}` ~670 long for 80 rise (cliff) | floor p95 13.4 deg |

Clearances: K.clearance counts whole air voxels, so a designed clear of 50 reads 48 or 52. Design >= 52 when
48 is the floor.

## Everything together (freeroam, 960 box, 4 chunks, chunkMargin 288)

`reference/example_freeroam.lua` (the freeroam test with a literal BOX: set center/size/chunks, run `run.sh plan`
first): rolling + hill field (`skip = K.clearOf({lane, wall, bowls...}, 0.4)`) + 2 bowls + a main
lane + a wall-ride (last run_all, lab/out/t_freeroam_built.txt): hills 7/7 with every approach <= 25 (worst p50
21.1), bowls 5/6 (the sixth's steep exit ends on the wall-ride face, excluded by the grade), 0 steep patches outside
the wall face, 0 creases outside it, 100% reachable, free-roam flat 5.8% (floors excluded), highlight 12.1% (outside
lip bands), whole vs chunks 0.00, second pass 0 columns. Relief/100 p50 11.1 is below the user-area minimum (A4
13.6): lane and bowl floors are flat by design; the pure hill field reaches 13.7.

## Mask options

| Case | Options |
|---|---|
| Create on a meadow | `{ yMin = floor - 60, yMax = floor + 40, buffer = 24, feather = 80 }` (lab); big boxes used feather 200 |
| Revamp steep banks / a raw step | add `maxSlope = 45` (banks) or `91` (vertical step you are reshaping) |
| Gate / level block | `K.keep(G, xa, xb, za, zb, 16)` |
| Chunks | `chunks = {{xa, xb, za, zb}, ...}`; compute margin defaults to 288 (assembled from 96-stud snapshots when needed); index 0 snapshots baselines, 1..n build; pass 2 rewrites 0 heightfield columns; whole vs chunks 0.00 (tests chunk, bridge, chunkguard) |

Keep every piece inside `box - buffer - feather` (the WARN names any piece that is not): the feather multiplies
the edit and squashes whatever sits in it.

## Placement

- `K.spots(G, 40, 24)` lists free discs (x, z, r = clearance, y). Put the biggest piece in the biggest disc.
- `K.route(G, waypoints, halfW + bank/2, 90)` threads a lane through props; "no gap" means narrow it.
- Dense tree areas (meadows: 126-287 pads per box) fit trails and bowls, not race loops.
