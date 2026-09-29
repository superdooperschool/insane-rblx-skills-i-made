---
name: rbx-terrain
description: Roblox Studio terrain add-on for the rbx skill. Use whenever asked to build, sculpt, revamp, smooth, paint or analyse Smooth Terrain - "make this area playable", "add a track / tunnel / bowl / bridge / hills", "the ground feels bumpy", "can the ball climb this", "how steep / big are these hills and bowls", "measure / analyse this area", "improve this terrain", "why does this area feel good", or any Terrain:WriteVoxels / FillBall work. Learned from the user's hand-built areas; builds are reversible and verified by numbers.
---

# rbx-terrain (roblox studio terrain)

Load `rbx` first (transport). Heavy work runs inside Studio through `rbx lua`; only numbers and PASS/FAIL lines
come back. The kit (`scripts/kit.lua`, ~2,650 lines) never enters context: `run.sh` pipes `kit.lua + recipe` to
Studio. Two Studios connected: set `STUDIO=<id>` (run.sh, tests) or pass `--studio <id>` on every rbx call.

```
T="bash $HOME/.claude/skills/rbx-terrain/scripts/run.sh"
$T analyze <Box|x0,z0,x1,z1> [step 4] [name]   measure any area (read-only raycast grab, math offline in node)
                         -> $SCANS/<name>.grab/.json/.txt/.png; ANALYZE_OPTS="start=x,z minProm=3 ..." (key=value
                         overrides analyze.mjs DEFAULTS; start seeds reachability)
$T plan <recipe.lua> [nChunks|0]   compose only, NO writes: analyze the planned surface (same verdict as built)
$T backup <Box>          baseline TerrainRegion + tile hashes -> ServerStorage.TerrainBackups (kept forever)
$T map <recipe.lua>      dry run + ASCII preview (paint | height, lock reasons, T = prop pad); writes nothing
$T build <recipe.lua>    restore baseline, compose, write, 3D ops, graded checks (small boxes only, see Chunks)
$T restore <Box>         paste baseline back, prove every tile hash matches;  $T list;  $T drop <Box>
$T lua <file>            any Luau with the kit (K) loaded;  $T dry scripts/selftest.lua  kit selftest (self-erasing)
node scripts/analyze/analyze.mjs --selftest                      prove the analyzer (14 synthetic cases)
node scripts/analyze/analyze.mjs --compare before.json after.json   metric deltas for a revamp
node scripts/analyze/table.mjs --into reference/grammar.md <scans>.json   regenerate the measured table
bash scripts/tests/run_all.sh    regression suite: 21 suites, far sites 0-19, build/measure/grade/erase, ~250 s
bash scripts/tests/run.sh <test> [keep]   one lab test (keep = leave the site standing to render it)
```

## Numbers are measured, never estimated (user 2026-09-27: "make it not hallucinate")

Any number about terrain (slope, hill size, bowl depth, climbability, paint share) comes from `analyze`/`plan`
output or a test log, quoted with its file. If it was not measured, say "not measured" and run the analyzer.

Reading an analysis (`<name>.txt`):
- `slope %` bins, `flat(<3)`, `relief/100` (height range inside 100-stud windows), `bump` (small-step roughness).
- `hills` / `bowls`: each Hn/Bn found by 32 ray walks from the summit/floor to where the ground stops falling
  (rising). `h` = median drop over the rays, `prom` = smallest drop = the lowest way off (prominence for hills,
  spill depth for bowls; matches the col-derived truth within 1 stud in the selftest). On sloped ground quote `prom`:
  a h 20 mound on a 10 deg tilt reads h 17.9, prom 5.6. `r` = rim radius, `climb easy/med/worst` = steepest 16-stud
  rise along the easiest / median / worst ray, `ok k/32` = rays whose climb stays <= 25 deg, `closure` = share of
  rays that really drop, `cliff-edge rays` = rays stopped at a >= 55 deg edge or a >= 35 deg rock-painted edge
  (excluded from the approach verdict). Reported only with prom >= 3, r >= 16, closure >= 0.8; the verdict counts
  grass features (>= 80% blade paint). A 1.9-stud bump on a 14 deg slope is not a hill (its steep cells still count).
- `reachable`: flood fill from base-level border, uphill only onto <= 25 deg cells, downhill anywhere; lists
  unreachable islands and hill summits. This answers "can the ball get up there".
- `creases`: slope break over 8 studs minus half the break over 16 (round crests score ~0), score > 4.5 = a break
  of ~18 deg, >= 4 cells. `steep patches`: >= 4 connected cells > 25 deg (cliffs, wall faces, portals included).
- `verdict`: PASS/FAIL per user target with the rule source. The PNG rings hills (white = all 32 approaches <= 25,
  red = not) and bowls (blue / magenta), labels match Hn/Bn, steep cells orange (> 25) / red (> 45), creases cyan.
  Read the PNG to check the detector saw what you think it saw.

Why the analyzer can be trusted (selftest, 14/14): hills/bowls h and r within 12%, approach slope within 1.5 deg,
no phantom features on a flat plane, rolling + noise, a rotated ellipse or a 10 deg tilt; overlapping pair
prominence 19.3/19.6 vs saddle-derived 19.6; on a 10 deg tilt mound prominence 5.6 vs col-derived 5.6, worst
approach 25.9 vs 26.1, bowl spill depth 3.5 vs 3.6, wall 23.6 vs 23.7; 17 deg summit reachable, 38 deg not;
plateau behind a 79 deg cliff 95% reachable with a 16 deg ramp, 48% without; 20 deg crease caught, 10 deg not.
A2 lane width 104/120/155 vs 96/120/168 hand-measured. Whole map at step 24 in one call: 26 s.

Measurement physics (do not rediscover):
- Rendered surface = voxel base + 2 + 4 x occupancy (linear): raycast heights sit 2 studs above K.read heights.
- Raycasts right after a write see the old surface: `task.wait()` before probing.
- Slope over an 8-stud baseline carries +-1.5 deg of voxel mesh noise; approaches are measured over 16 studs and
  steep areas as patches of >= 4 cells, never single cells.
- A built slope reads 1.0-1.4 deg steeper than the planned cosine profile (bowl: plan 13.5 -> built 14.9).
- Terrain MaxExtents is +-32000 studs: far test sites live at -30000..-19500, not -40000.
- Grab output is paged at 90 KB per call (rbx returns ~100 KB max); plan output > 90 KB pages through
  ServerStorage.TerrainPlan, removed after the fetch.

## Fast loop (user 2026-09-27: a 3 h revamp was "so slow"; ~30 min of it was Studio)

Wall clock is the budget, not thoroughness:
1. No long design phase, no kit-reading marathons. Change the recipe, `plan` it (no writes, ~16 s per chunk on
   claude_big_test), read the verdict, adjust. Build only the 1-2 chunks the change touches; a full 16-chunk pass
   (~5 min) only once the plan verdict is right.
2. Look without captures (captures move the user's camera and returned stale frames): `analyze ... 8 <name>`
   writes the overlay PNG. 3D look: `CAM=u,y,v LOOK=u,y,v HALF=<half> STEP=<step> node scripts/render/render.mjs
   <name>.grab top.png view.png` (u,v centre-relative, +u = image left, real material colours). User angle
   `CAM=0,2300,-3000 LOOK=0,150,250`.
3. A gate that does not close after one fix attempt: report it with its breakdown, do not loop passes on it.
4. Studio in Play mode = no Edit writes: prep files, poll `rbx lua 'return 1'` every 15 s. Never stop Play.

## Workflow

1. `analyze` the box and a reference box. Targets: `reference/grammar.md` (targets table with sources + generated
   user-area table). Ball limits: `reference/movement.md`. User verdicts: `reference/feedback.md`.
2. Write the recipe (start from `reference/example_freeroam.lua` or a `scripts/tests/t_*.lua`); parameters that
   passed are in `reference/recipes.md`. Place with numbers: `K.spots(G, minR, n)` = largest free discs;
   `K.route(G, waypoints, halfW + bank/2)` = A* lane between props ("no gap" = narrow it).
3. `plan` until the verdict passes on shape and climb targets (lab: plan verdict == built verdict; hill worst
   approach p50 20.9 planned vs 21.2 built).
4. `backup`, then build in chunks. Builds start from the baseline, so re-running never double-applies.
5. `analyze` the built area, `--compare` against the before scan, report numbers.

Mask (`K.run(box, maskOpts, setup, composeOpts, checks)`): locks Basalt/Rock tops, air-under columns, water,
out-of-band heights (`yMin/yMax`) and cells over `maxSlope` (default 30), plus `buffer` and `feather` (defaults
12 / 16; lab 24 / 80, claude_big_test 60 / 200). Every part resting on the ground keeps a pad of untouched terrain
(no prop floats, buries or moves). `K.keep(G, xa, xb, za, zb, 16)` for gates / level blocks. Keep pieces inside
box - buffer - feather: the feather multiplies the edit and steepens whatever sits in it (compose WARNs with the
share). Mask corners are rounded (0.15 x box size, world coords, same in chunks).

## Climbability (the rule behind most user rejections)

Free-roam ground: every approach to every hill, bowl rim and notch side <= 25 deg over a 16-stud rise (R7), and
100% of free ground reachable from base level (R5/R7). Ball facts: wall-ride only on >= 66 deg faces; nothing
driven in 45-66; no loops, corkscrews or ceilings; grounded LaunchCap 18 + Downforce 55 (kickers never launch).

The compose **climb guard** enforces it by default (22 deg): average of local Lipschitz envelopes (sources within
160 studs), changes only within 56 + 48 studs of a violation, capped at 16 studs per cell, clamped between cones
from anchors. Exempt: pieces that declare `f.steep` (wall faces, K.cliff faces) and deliberate faces: any cell
>= 55 deg (`faceDeg`) plus its connected >= 35 deg body (`faceGrow`), + 3 cells (`faceBand`). Kept cells that border
free ground anchor the guard, so no step forms at a face. Build prints `climb guard 22 deg: n cells reshaped ...,
k free cells still > 22.5, m steep-kept`.

Measured effect (claude_big_test v4 recipe, read-only plan, step 4): hills with an approach > 25: 49/85 -> 6/81;
bowls with an exit > 25: 25/66 -> 1/64; steep patches 185 -> 23; creases 243 -> 201; relief/100 p50 14.9 both.
Steep cells guard off -> on: 25-35 deg 53,358 -> 12,501; 35-45 27,627 -> 25,357; 45-55 15,993 -> 16,346; >= 55
unchanged (30,016 -> 30,123). The remaining 35-55 cells are flanks of kept cliff bodies (one T1/T2 cliff complex
holds 78,582 of 84,327 steep cells): fix them in the recipe (spread the terraces, add ramps), not in the guard.

Tried and rejected (do not retry): limiting cliff-body growth to 24 studs (`faceGrowReach = 24`) or growing only
through >= 45 deg (`faceGrow = 45`) lets the guard reshape tapered cliff ends: cliffadd edge blend 46.3 / 52 (want
<= 25), TOPS worst approach 35.6 (want <= 22.75). A global envelope (first guard) reached across cliffs and made
15-26 stud jumps at chunk lines. The old talus limiter (`maxSlope = 34` in compose) flattened wall-rides to 39 deg:
opt-in only.

Portal trade-off (R7 + R5, user call): a heightfield cannot give both a steep headwall above an arch and <= 25
notch sides. Default: 108-stud open trench with walls up to 55 before the roof; `portalKeep = true`: 80-stud trench
+ 2 approaches at 27-31. Cliff caves avoid it (the cliff is the headwall).

## Hills

- Design flank <= 20 deg: r >= 4.5 h (K.mound WARNs above 20.5). Free-roam hills h 30-50 (R10), wide not tall
  (h <= 80). Measured: K.mound h 40 r 180 -> h 39.2, r 180, worst approach 20.6.
- Fill space with `K.hillField{rect, seed, skip}` (defaults grid 150, jitter 80, h 28-44, r 5.2-6 x h, union max;
  `union = "sum"` = v4 additive, stacks to h 70) + `K.rolling{}` (octaves 600/240/110, warp 60). Every random number
  is drawn before any skip, so the set is identical in every chunk. `skip = K.clearOf({pieces}, 0.4)` keeps hills off
  lanes, walls and bowls (bowls include their lip). Measured 600 x 600 core: 9 placed, 6 detected, h p50 33, flat
  4.1%, relief/100 p50 13.7, 0 steep patches, 0 creases.
- `K.mound{..., on = feature}` stacks a hill on another additive piece (TOPS on a cliff: prominence 14.4 for h 16-18).
- Overlapping pieces union by smooth max/min k 12 (k 4 left a crease in the saddle of two mounds).
- Relief target (A4 13.6 = lowest user area) is met by a pure hill field (13.7); a mixed free-roam box with
  lane/bowl floors measured 11.1 (example_freeroam). Flat is failure (R2): <= 8% of free roam under 3 deg.

## Bowls

- User: r 170-230, depth about r/6.5, walls <= 15, every exit <= 25 (R12, R6, R5); dark Grass floor, Limestone lip.
- `K.bowl{x, z, r, depth, lip, floorMat, rimMat}`: lip at 1.1r, width 0.3r (a lip at r made steep rims). The lip adds
  nothing to the max wall: wall = atan(depth x pi / 2r). WARN when that planned wall > 13.8, because builds add
  1.0-1.4 (r 190 depth 29 lip 5: plan 13.5, built 14.9, depth 33.8, rim 202; r 80 depth 12: 13.2 -> 14.2). v4 used
  depth r/6 (plan 14.7) and built 16-17.
- Donut: `K.ring` auto-widens w so the rim stays <= 20 (w 16 h 8 -> w 35; was 34 deg). Raised rings are unreachable
  bowls (R2): prefer depressions.
- The analyzer's bowl `prom` is the spill depth (lowest rim), `h` the mean rim-to-floor depth.

## Pieces (parameters that passed: reference/recipes.md)

Heightfield: `K.mound` `K.hillField` `K.rolling` `K.ring` `K.bowl` `K.pad` (blend grows with the height it bridges)
`K.cliff` (face exempt from the guard, ends taper; `base = y` reshapes an existing step, with maskOpts
`maxSlope = 91`) `K.path` modes `lane` (sunk, floor averaged along s, banks widen with the drop to <= 22, `calm`
damps rolling near it, optional `camber`), `ramp` (eases y0 -> y1), `berm` / `trough` (auto-widened), `wall`
(wall-ride quarter-pipe: face >= 66, rounded crest, back <= 20, tapers to 0; `outside` marker within halfW + bank of
the path), `dive` (sunken route with explicit floor, `dips`, `covers`, `endEase`; a dip left at an end is a pit).
`K.table` is banned (errors without `allowBanned`).
Bores and 3D: `K.slot` on the dive pts bores through covers (`arch = true`, lining `K.lining` Rock/Mud/Ground,
roofs itself only where ground is thick); `K.archBridge` = deck across a fully carved gully with an elliptical arch
(boring through a ridge made 30-45 deg wing walls); `K.water(G, name, lane, {depth = 9})` fills air only, surface =
floor + depth (a flat level spilled where a bank dipped). `K.op3d(G, name, bmin, bmax, "add"|"cut", fn, {floor,
wall})` with `K.sd.ellipsoid/capsule/roundBox/tube/smin`. Bore clear >= 48 (design 52: K.clearance counts whole
voxels), roof >= 8 studs of hill (roofed bores keep the top 8 as grass skin). 3D cut region Y must reach the cut top
+ 16 (lining band 4 voxels; thinner shows green blobs at LOD). Clip pillars to the chamber (`max(pillar,
chamber - 4)`). Bores sample every ~4 studs (coarser = ribs).
Write: `K.write` fills by distance along the surface normal (column-only fill made steep faces a hole/spike lattice),
rewrites a column only when the predicted read-back height differs from LIVE terrain, never writes occupancy below
0.06 (stored ambiguously): a second pass rewrites 0 columns. Voxel regions over 4,194,304 split automatically.

## Paint (compose defaults)

- 4-tone fake sun (R14, `GlobalShadows = false`): sun (0.755, 0.553, -0.352); Grass (82,159,52) shadow faces,
  LeafyGrass (98,181,59) neutral, Slate (93,195,70) lit > 0.05, Limestone (162,217,89) brightest > 0.12 = highlight,
  10-20% of edited ground (v4 10.7, A3 19.2). Test order: mean exposure Grass < Leafy < Slate < Limestone.
- Rock paint `K.stone` (Rock + Basalt noise) on cells >= 35 deg with >= 4 of 8 neighbours also >= 35 (lone rock
  specks came from slopes hovering at 35). Despeck: a lone cell takes its 8-neighbour majority. Paint dithers back to
  the untouched material through the feather. Options: `sun = false`, `shade = "lit"`, `sunHi`, `rock`, `despeck`,
  `edgeFade`, `keepPaint` (user paint stays where shape did not change).
- Banned: Cobblestone, Pavement (user), Concrete (renders magenta 247,0,255 here). Rock renders the same grey as
  Basalt; for contrast use Salt (white) vs Asphalt (dark). Mud + Ground 3:1 speckle only on sunk lanes and floors.
- Blades grow on Grass/Leafy/Limestone/Slate/Cobble up to 55 deg; only Grass/Leafy/Limestone pay swords. Keep edited
  ground >= 70% blade materials; the sun paint puts 15-25% on Slate, so pay share measured 70-96% (K.check prints it).
- Relief must read: a +7 berm is invisible; A3's swirl is ~45 studs of relief.

## Chunks (user R8: full-box builds lag Studio; never on a live place)

Recipe passes `chunks = {{xa, xb, za, zb}, ...}` in maskOpts (pieces inside one rect where possible).
`{ echo "local RUN_MODE = 'chunk' local CHUNK_INDEX = <i>"; cat kit.lua; cat recipe; } | rbx lua -`: index 0
snapshots every chunk's baseline (+`snapMargin` or `chunkMargin` or 96) while the box is clean; 1..n compute on the
rect + 288 studs of context (the guard's reach; assembled from neighbouring 96-stud snapshots at a +20000 scratch
that is erased), write only that rect, clip 3D ops to it. Do not pass `chunkMargin` to old boxes (it caps the guard
at margin - 128 and says so). `RUN_MODE = 'check'` runs only the recipe checks, `'plan'` writes nothing.
Measured: whole vs chunks 0.00, second pass 0 columns, restore exact (tests chunk, bridge, chunkguard, freeroam,
river). Pieces crossing a chunk line must not read `G.Hf` outside the chunk grid (bridge ends: pass `ya/yb` from a
recipe-side ground function). Chunk writes compare with LIVE terrain, not the baseline (baseline compare left stale
5-stud pits). Terrain calls stay <= 2048 studs per axis and <= 4,194,304 voxels, one heavy call at a time.

## Checks and regression suite

`build` prints (all must PASS): unmasked columns unchanged | per tag (lane/flow/ramp/meadow/shape/berm) slope,
roughness, small steps, 45-66 share | blade share + pay share | props grounded | recipe checks (clearances) | climb
guard line. After ANY kit edit: `bash scripts/tests/run_all.sh` must end `RUN_ALL PASS` (last: 21 suites, 249 s,
sites 0-19 = 0 solid voxels, 0 lab baselines). Tests build at far sites k -> (-30000 + (k % 8) x 1500, -30000 +
floor(k / 8) x 1500), assert 100% air before writing, erase and prove 0 solid after. Every user verdict maps to a
default (D), a suite check (C) or review-only (R) in `reference/rules_map.md`.

## Files

`scripts/kit.lua` | `scripts/analyze/`
grab.sh/grab.lua (raycast grab), analyze.mjs, table.mjs, merge.mjs | `scripts/render/render.mjs` | `scripts/tests/`
lab.lua (sites), t_*.lua, grade.mjs (specs per test), chunk.sh, plan_check.sh, run_all.sh | `reference/` grammar.md,
recipes.md, rules_map.md, feedback.md, movement.md, example_freeroam.lua.
(REPORT.md, PROGRESS.md, scans/).

## Training loop

User verdict -> one line in `reference/feedback.md` -> a kit default or a grade.mjs check -> a row in
rules_map.md -> `run_all.sh` passes. Read feedback.md before designing.
