# pipeline - ops, settings, traps

## Studio MCP ops (via `$R call <tool> '<json>'`; `$R call help '{"op":"<tool>"}'` for the schema)

- `search_asset`: waterfall universe -> group -> user -> Creator Store; `scope` auto|creator_store|user|group|universe; `assetType` Model|Audio|Mesh|MeshPart|Image|Decal|Video|Package (uploaded textures are Image not Decal; Package needs the filter, keyword search finds nothing); `priceFilter` "free" default; `verifiedCreatorsOnly`; `audioMinDuration`/`MaxDuration` split SFX from loops.
- `insert_asset`: numeric `assetId` + `assetName` (else generic) + `parentPath` (default workspace is usually wrong: use a staging folder).
- `generate_mesh`: one textured MeshPart. `size` = bounding box in studs; `segmentation` omit | "none" | "explicit" + `partNames` (max 8); `maxTriangles` 12-20k hero, ~4k props.
- `segment_mesh`: split an existing MeshPart/Model into <= 5 named sub-parts; needs the source `uniqueId` from `inspect_instance`.
- `generate_procedural_model`: tunable Model of primitives, self-inserts to workspace, exposes attributes for retuning; `attachedImageUri` from `store_image` (local png/jpg < 5 MB -> `IMAGEID_<id>`).
- `generate_material`: MaterialVariant; set both `Material` and `MaterialVariant` on the part.
- `upload_image`: http(s) URLs -> rbxassetid, batch in one call; moderation delay.
- `http_get`: allowlisted to create.roblox.com/docs and github.com/Roblox/libmp, URL ends `.md` or `llms.txt`; prefer `skill(rbx-docs-search)`.
- `execute_luau` needs `datamodel_type:"Edit"`; it cannot create Scripts (use `multi_edit`), but Parts/MeshParts/Accessories are fine.

## Blender + Hyper3D/Rodin (hero assets)

- Addon socket `127.0.0.1:9876`, JSON `{type, params}` -> `{status, result}`. Ops: `get_scene_info`, `execute_code`, `get_hyper3d_status`, `create_rodin_job`, `poll_rodin_job_status`, `import_generated_asset`.
- Enable headless: `execute_code` setting `blendermcp_use_hyper3d=True`, mode `MAIN_SITE`, `set_hyper3d_free_trial_api_key`.
- Loop: `create_rodin_job(prompt)` -> poll until Done -> `import_generated_asset` -> `execute_code`: join, center, normalise to ~2.4 u, shade smooth, export GLB (draco) -> user imports via File > Import 3D (or upload + `insert_asset`).
- `scripts/rodin.py "<prompt>" out.glb` wraps the loop. First run: check `get_hyper3d_status` output by hand.

## Import settings by role

| Role | Anchored | CanCollide | CanQuery/Touch | CastShadow | RenderFidelity | CollisionFidelity |
|---|---|---|---|---|---|---|
| Foliage / instanced clutter | true | false | false | false | Performance | Box |
| Prop (walkable) | true | true | true | true | Automatic | Hull |
| Hero / character | per rig | per rig | true | true | Precise | Precise (once) |
| Grass bones (cloned) | true | false | false | false | Performance | none, no TextureID |

`MobileQuality` pass: 1,310 Precise MeshParts -> Automatic, particle rate halved, clouds off on phone.

## Traps

- "Object too huge" was a leftover R6 Head part 1,624 studs from the root inflating `GetExtentsSize()`.
- Orbit radius `Size.Magnitude * 0.5` = cube diagonal, 1.73x too far.
- 35 swords authored by different people share no orientation convention: `OrientOffset` per asset, `localExtents` for hitboxes, trail on the longest local axis, verify by sampling `UpVector`/`LookVector`.
- Skinned mesh `MeshPart.Size` (153 studs around 21-96 stud bones) defeated frustum culling; only a tighter re-export fixes it. `DoubleSided` doubles triangles, baked.
- 4 vestigial Decals on a template cost 40% of batches.
- Roblox `generate_mesh` output is instant in workspace; no upload gate for previews.
