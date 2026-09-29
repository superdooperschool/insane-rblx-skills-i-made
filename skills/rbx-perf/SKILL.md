---
name: rbx-perf
description: Use when a Roblox place is slow, stuttery, drops fps when moving, takes long to join, or when asked to measure/optimise/profile anything - grass, particles, UI weight, scripts, draw calls, join stalls. Also use before claiming a perf change helped.
---

# rbx-perf

**Measure moving, report percentiles, bisect additively.** Weeks were lost to Studio's fps counter,
to mean frame times, and to subtracting scripts one at a time. Every number below is from the
grass/RainScript/join-load hunts (2026-08 to 2026-09); `reference/measurements.md` has them all.

## The ladder (stop at the first rung that explains it)

| # | Question | How | Decides |
|---|---|---|---|
| 0 | Is it a preset? | `$R find "ActivePreset"`, `find "Ultra"`, `find "MaxParts"` in client scripts | RainScript "Ultra" alone took 60 -> 34 fps; one-line fix gave 15 -> 96 moving |
| 1 | Baseline | `bash scripts/run.sh move 8 base` and `stand 8` (Play, real client) | p50/p95/p99, fps, Batches |
| 2 | Render or CPU? | Compare `RenderThreadAverage` vs `PerformAverage`; disable all client LocalScripts -> geometry-only floor | Scene floor 5.0 ms / 195 fps; script-free 240 unreachable |
| 3 | Draw calls | `Batches` in the sample; detach the suspect container for one run | Grass was 70% of batches; 4 stray Decals per template = +40% batches |
| 4 | Which script | ALL client scripts off, add back one group per run (additive from floor) | found a 28 ms culprit instantly; subtractive found 0.2 ms noise |
| 5 | Which function | `os.clock()` marks around phases, attributes on the owning instance, read after 5 s | `_stepPlacements` unbudgeted conforms; trample loop 15.8 -> 0.7 ms |
| 6 | Join stall | count `PlayerGui:GetDescendants()` on join, `ReplicatedStorage` descendants, TexturePack failures in console | 16,641 -> 5,410 GuiObjects via lazy build; RS 8,300 -> 1,918 |

## Rules that came from being wrong

- MicroProfiler "frames" are 230 Hz scheduler ticks: multiply by ~4 for per-frame cost. `GetRealPhysicsFPS` is always 60. Studio fps reads 190-230 while the real number is 50.
- Sample `RunService.RenderStepped` count + `Stats.FrameRateManager` values every 0.25 s. Report p50 / p95 / p99 / max and frames over 16 ms and 33 ms. A mean of 5.98 ms hid a p99 of 82 ms.
- Measure **moving** (60 / 150 / 400 studs/s straight line), not standing, not circles.
- Studio swings 60 / 120 / 170 fps run to run at identical load (focus, editor). Two runs per config, never one.
- Ablate by setting a config value to 0 or a flag, never by reparenting (moving 65 clumps cost more than the clumps).
- `require(Config)` inside `lua` is a private copy: a config edit there is a no-op. Drive a value to an impossible number and watch the engine's own attribute react.
- Re-enabling a disabled LocalScript mid-Play duplicates it (batches 1242 -> 2049 -> 2829). Restart Play between runs.
- Wall-clock `task.wait` loops throttle ~4x when Play is backgrounded; trust `os.clock` marks on attributes.
- `MeshPart.Size` of a skinned mesh is baked at export; an oversized bound defeats culling and only a re-export fixes it. `DoubleSided` doubles triangles and is baked too.
- `PerBoneCulling` + `LODBonesOnlyMove` together crash the client.
- Sound floods: cap the pool (24 slots), destroy on `Ended`, never `Debris` timers.

## Budgets

| Thing | Number |
|---|---|
| 60 fps frame | 16.7 ms; 120 fps 8.3 ms |
| Client Lua per frame (moving) | under 4 ms total; one system over 1 ms is a suspect |
| PlayerGui on join | under ~6,000 GuiObjects; build panels on first open |
| ReplicatedStorage descendants | under ~2,000; park kits in ServerStorage |
| Live Sounds | under 24 |
| Per-entity AI decisions | 10 Hz, not 60 |

## Harness (`scripts/`)

`run.sh <move|stand> <seconds> [label]` drives player 1 along the A-B line (`move.lua`, server) and samples
the client (`measure.lua`); appends to `results.txt`. Set `BENCH_A`/`BENCH_B` env for another place.
Needs Play running with one player. Two runs per config. Report the table, not a sentence.

## Red flags

- An fps number from the Studio corner, or a single run
- "The grass is the problem" before rung 0 and 2
- Reparenting to ablate
- A perf claim without before/after p50 and p99 from the same harness
