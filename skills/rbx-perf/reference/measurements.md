# measurements - every number the perf hunts produced (2026-08-01 .. 2026-09-24)

## Diagnostics that told the truth vs lied

| Lied | Truth |
|---|---|
| MicroProfiler frame ms (230 Hz ticks) | multiply by ~4 |
| Perf_FPS attribute counting Heartbeat (192-230 in Studio) | RenderStepped count (~50 real) |
| `workspace:GetRealPhysicsFPS()` (always 60) | `Stats.FrameRateManager.RenderAverage` |
| mean 5.98 ms | p99 82 ms, max 235 ms |
| Studio p50 (vsync illusion) | p95/p99 while moving |
| single run (60/120/170 fps at same load) | two runs per config |
| `GrassLOD` own `Perf_GrassMs` 0.08 | real 1-1.4 ms |
| LibMP capture (0 threads after 2026-09-02) | engine attributes + disable/detach A/B |

## Root causes found

| Symptom | Cause | Fix | Result |
|---|---|---|---|
| 30 fps everywhere | RainScript `ActivePreset="Ultra"` (Rate 180, MaxParts 1600, MaxTrails 900) | preset "Low" | moving 15.3 -> 96.4 fps, p50 64 -> 9.5 ms |
| fps halves near grass | render-bound: 70% of batches | detach test 34 -> 68 fps, batches 1549 -> 545 | re-export tighter bounds |
| culling only removes 18% | clump MeshPart.Size 153 studs vs 21-stud bones | asset re-export | - |
| +40% batches | 4 vestigial Decals per template | delete | batches 1385 -> 819, 2140 -> 1713 |
| fps 240 -> 47 moving | MeshPart anchored to player, bones on own cell: 170-stud bound never culled | anchor = own cell | - |
| 50 -> 123 fps | >half of 27k bones were invisible duplicates (jitter broke lattice tiling) | exact stride 10 x pitch | - |
| grass "in one clump" | round-robin gave first 9 jobs the whole budget | slice = budget / jobs waiting | - |
| fps loss at speed | unbudgeted `_stepPlacements` (~560 conforms/frame), no Perf mark | budget it | - |
| 15.8 ms trample loop | recomputed identical Transform every SimHz tick | cache pct | 0.69 ms |
| RadiusSearch grows forever | octree top regions never pruned | `Octree:Prune()` at 5 Hz | - |
| client crash | PerBoneCulling + LODBonesOnlyMove both on | never both | - |
| 87 live Sounds | 135 Sounds/s from collision debounce bug | rate-limit 0.12 s, 24-slot pool | peak 18-24 |
| 1128 ms join stall | TreeUI built 654 nodes (18,300 GuiObjects) on join | build on first view | - |
| slow join | PlayerGui 4,028 authored -> 16,641 live | `Panels.onFirstOpen` | 5,410 |
| slow join | ReplicatedStorage 8,300 descendants of dead kits, unstreamed | park to ServerStorage | 1,918 (regressed to 8,046 later, parked again 3,098) |
| 2 x 750 ms join stalls | TexturePack PBR DependenciesPermissionDenied | unfixed | - |
| 33 fps (shooter) | SpatialHash scanned 274,625 cells per recipient per tick | O(players) loop | 237 fps |
| 17.5 ms slimes | 201 entities x 60 Hz nearestSibling with fresh GetTagged | 10 Hz decisions | 13.4 ms at 201 |
| DOF live in game | ZoneLighting never copied PostEffect.Enabled | copy Enabled | blur 0 in all presets |

## Floors and formulas

- Scene geometry only: 190-212 fps, 5.24 ms p50. All client scripts on: 25.8 fps, 38.98 ms. 240 fps = 4.17 ms is unreachable.
- PlayerScripts only = 60 fps; PlayerGui (110 scripts) only = 29 fps: grass was ~4% of the problem that day.
- Grass CPU worst: Step 5.27 + Place 3.43 + Blockers 0.54 + Scan 0.05 = 10.7 ms; trample avg 0.124 ms.
- Skinning cost ~38 us render per clump; Transparency=1 changed fps by 1 (skinning, not fill).
- Steady clumps ~ pi (R + DropMargin)^2 / cell^2 x 0.93; outer rings overshoot 55-81%.
- Ring2 keep-chance must stay above ~0.59 (square-lattice percolation) or holes join.
- Footprint ~ 9.5 x BladeHexPitch. GrassPlaceHz must equal RetireHz. GrassClumpCap re-derived per retune.
- At ~450 studs/s 94% of bones were underground.
- Wind: `WindAtPointFast`, `WindSpeedCutoff = 70` studs/s skips the loop.
