# Smoothing and cleanup passes (measured on a large mountain build)

User words: "make it all smoothed", "tiny terrain specs", "spikes", "green streaks on cliffs", "random bump inside path",
"random humps everywhere", "path connecting to nothing", "walls for no reason", "make the whole mountain front-page ready".
Everything below was measured on 211 tiles (256 studs) of workspace.Mountain_Fix. Tools: `scripts/smooth/` (README there).

## Roblox rendering facts (do not rediscover)

- Rendered surface height follows the TOP-MOST NON-ZERO voxel, not the 0.5 iso. Profile test (uniform 8x8 voxel patches, raycast):
  [1,1,1,0] renders 13.4, [1,1,1,0.06] 15.2, [1,1,1,0.3] 15.4, [1,1,1,0.5] 15.7, [1,1,1,1] 17.0, [1,0.97,0.84,0.5,0.16,0.03] 22.6.
  A tail of 0.06 already lifts the surface ~1.8 studs. Consequence: NEVER blur occupancy on ground you want to keep at height.
  A plain 5-pass blur of the whole mountain lifted every surface ~1 voxel (route floor +3.6 studs median, up to +9.7; tunnel
  headroom < 36 in 62 spots, path-material smears climbing the walls). Reverted from snapshots, byte-identical.
- Safe smoothing on steep faces: blur, then re-sharpen `o = clamp(0.5 + (blur - 0.5) * k, 0, 1)` (k about 3.5 for 4 passes) so the ramp
  stays about 1 voxel wide, cut tails below 0.06, and never thin a slab that is thin vertically (roofs, shelves).
  Measured: gentle ground (< 20 deg) moves p50 0.00, p90 <= 0.14, max 0.5 studs; steep faces p50 1.4 studs (spires removed show as big jumps).
- Rock (StrataNoisy, Regular, 20 studs/tile) and Basalt (StrataClean, Organic, 15) are MaterialVariants. Their diagonal stripe / shard
  look on a perfectly planar wall is TEXTURE, not geometry (Mud/Ground/Salt render smooth on the same wall). Geometry smoothing does not
  change it. Bores stay lined with the Rock/Mud/Ground mix (user Round 7).
- K.read height = top voxel base + 4 * occupancy; K.write writes a 1-voxel ramp `o = 0.5 + (hf - yb - 2) * cos / 4`. Use K.read/K.write
  for gentle ground (validated encoding), voxel passes for steep faces.
- Studio replication: every terrain write replicates to Team Create ("Terrain Sync Progress: Replication Queue 769 of 827" when many
  full-tile writes + 211 TerrainRegion snapshots pile up) and Studio lags / drops the place ("Target is closed"). Write only changed
  16-voxel blocks (sparse writer), snapshot once per tile, and gate every batch on `rbx lua 'return 1'` latency < 1.2 s.

## Artifact census (whole mountain, before)

Per tile (`census.lua`): floating chunks (<= 400 voxels, not touching the read box), dust (partial voxels with no solid neighbour),
thin voxels (o - opening > 0.25), grass-family voxels on >= 42 deg faces (21% of all grass voxels), rock on < 28 deg ground, noisy surface
voxels (|o - blur| > 0.3), roughness (angle between raw and coarse normal, mean 10.9 deg, target < 6).

## Pipeline (per tile, in this order)

1. Voxel pass `apply_voxel.lua` (read tile + 48 stud margin, write only the 256 interior):
   dust and small floating components removed; thin blades: width-2 horizontal opening at any height, width-3 opening for vertical runs
   >= 6 voxels; steep faces (>= 45 deg, dilated 1) sharpened-blur; paint: grass-family and path-like materials (Mud/Ground/Sand/
   Sandstone/Asphalt/Salt, outside the route corridor and not covered) on faces >= 38 deg become Rock/Basalt (neighbour majority), narrow
   grass strips (>= 5 voxels tall, <= 4 wide, >= 28 deg) become stone, small exposed rock patches (<= 300 voxels, < 28 deg) take the
   surrounding grass or (inside the corridor only) path material, isolated grass flecks take the neighbour majority.
2. Stray paths `strays.lua`: Mud/Ground pieces that are not the route (91 pieces off the corridor on this mountain) repainted to the
   surrounding grass or stone. Paint only, 28 stud corridor kept around the route.
3. Gentle heightfield smoothing `gentle.lua` (kit K.read / K.write): columns < 32 deg, no air gap below, no water, whole 3x3 neighbourhood
   valid; box blur r = 3 x 3 passes with a soft dead zone (tau 0.5 studs, 0.2 inside the route corridor, cap 4 studs) so only creases,
   seam ridges and bumps move and untouched columns are not rewritten.
4. Verify: `routecheck` vs the pre-pass baseline (floor |dY| and headroom, must stay <= 0.7 / >= 36), `displace.lua` against the tile
   snapshot, `census` again, then captures of the worst spots.

## Undo

Snapshots `ServerStorage.MountainFixBackup.t_<x>_<z>` (TerrainRegion per tile, taken once before the first write of that tile).
`runrestore.mjs` pastes all back; restoring is exact. Delete them only after user sign-off (they add replication weight).

## Gotchas

- `rbx lua` through node spawnSync: a config literal ending in `}}}` gives "Failed to parse command code"; append `, extra={}`.
- Studio 1 trivial call taking 8-50 s means the replication queue is draining: wait, do not add writes.
- Long straight cut walls (78 found, 160-800 studs long, 150-650 drop) are the mountain's block structure. Softening them is a design
  change, ask first.
