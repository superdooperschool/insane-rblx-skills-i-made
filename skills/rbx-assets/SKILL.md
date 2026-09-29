---
name: rbx-assets
description: Use when a Roblox task needs a 3D model, mesh, accessory, texture, material, sound or image brought into Studio - "make a sword model", "add a tree", "find a sound", "generate a mesh", UGC previews, importing GLBs from Blender, or when a model looks huge/misoriented after import.
---

# rbx-assets

**Real meshes from Blender or Studio's generator, never geometry in code.** `reference/pipeline.md`
has every op, setting and trap. Two sources, picked by need:

| Need | Source | Command |
|---|---|---|
| Quick prop, preview, placeholder that must exist NOW | Studio `generate_mesh` (textured MeshPart in place) | `$R call generate_mesh '{"prompt":"...","size":[x,y,z],"maxTriangles":4000,"parentPath":"ReplicatedStorage.Staging"}'` |
| Hero asset, character, anything the user will look at closely | Blender + Hyper3D/Rodin -> GLB -> import | `python scripts/rodin.py "<prompt>" out.glb` then Studio File > Import 3D (user) or `insert_asset` after upload |
| Existing free asset (sound, image, mesh) | `search_asset` -> `insert_asset` | `$R call search_asset '{"query":"...","assetType":"Audio","priceFilter":"free"}'` |
| Tunable primitive model (fence, gate, sign) | `generate_procedural_model` (exposes attributes) | see pipeline.md |
| Material | `generate_material` -> set `Material` AND `MaterialVariant` | see pipeline.md |

## Rules

- Never `Instance.new("Part")` sculptures, never procedural bpy primitives for a thing that should be modelled. Blender first (Rodin free tier -> Sketchfab/PolyHaven -> bpy with modifiers), Meshy only as a named exception, no paid 3D APIs.
- Insert into a staging folder (`ReplicatedStorage.Staging` or `ServerStorage._Incoming`), never straight into Workspace. Confirm before any paid asset: Robux spend is irreversible.
- `generate_mesh` size is real studs; generate at final size, `MeshPart.Size` after generation is clamped. `maxTriangles` 4k for props spawned many times, 12-20k for a hero.
- Every imported MeshPart gets: `Anchored true`, `CanCollide/CanQuery/CanTouch` per role (grass: all false), `CastShadow false` for foliage, `RenderFidelity Performance` for anything instanced, `CollisionFidelity Box/Hull` unless it must be walked on.
- Check `Model:GetExtentsSize()` first on any "too huge" report: a stray part 1,624 studs away inflated a sword's bounds. Orbit radius uses `Size.X * 0.5`, not `Size.Magnitude * 0.5` (1.73x overshoot).
- Orientation: sample `PrimaryPart.CFrame.UpVector/LookVector` live, never eyeball; per-asset `OrientOffset` (Vector3Value, degrees) escape hatch; hitboxes measured with a `localExtents` walk of all part corners, trail along the longest local axis.
- Skinned meshes: `Size` and `DoubleSided` are baked at export; culling bound = re-export.
- Uploaded images take minutes to moderate: a fresh id renders blank; batch `upload_image` calls.
- Shop/asset lookup by NAME only; tier is separate plumbing (`SourceFolder`).

## UGC (accessories)

Single mesh, <= 4,000 tris, <= 2048 textures. Attachment name decides the snap: Hat -> HatAttachment,
Face -> FaceFrontAttachment, Neck -> NeckAttachment, Shoulder -> RightCollarAttachment, Front ->
BodyFrontAttachment, Back -> BodyBackAttachment, Waist -> WaistCenterAttachment. Preview loop:
`generate_mesh` -> wrap as Accessory + `CreateHumanoidModelFromDescription` R15 + `Humanoid:AddAccessory`
-> capture. Publishing is human-gated (Premium, fee, moderation, authed upload).

## Red flags

- A `for i = 1, 12 do Instance.new("Part")` tree
- Inserting into `workspace` root
- Rescaling after generation to fix size
- "I'll eyeball the rotation"
