# assets

Getting meshes, models, images, audio and materials into a place. In rough order of preference:
reuse an existing asset, then buy/insert a Toolbox one, then generate one, then build from parts.

## 1. Find before you build

`search_asset` waterfalls through the universe inventory, the owning group, the user inventory,
then the Creator Store.

- `scope: "auto"` (default) for "find me a sword". `scope: "creator_store"` when the user wants
  marketplace assets or you need price filters. `scope: "user"` / `"group"` / `"universe"` to
  stay inside what they already own.
- `assetType`: `Model`, `Audio`, `Mesh`, `MeshPart`, `Image`, `Decal`, `Video`, `Package`.
  Uploaded textures are almost always `Image`, not `Decal`. Packages are Models with a subtype,
  so a keyword search for "package" finds nothing: filter `assetType: "Package"` instead.
- `priceFilter: "free"` unless the user has said they will pay. `verifiedCreatorsOnly: true`
  when quality matters more than count.
- Audio takes `audioMinDuration` / `audioMaxDuration`, which is the fastest way to separate a
  one-shot SFX from a music loop.
- Every response carries a `context` block (userId, universeId, whether the place is published)
  and a `groups` list. Read those before telling the user something is not available.

Then `insert_asset` with the numeric `assetId`, an `assetName` (always pass it, or the instance
lands with a generic name), and a `parentPath`. Default parent is `workspace`, which is usually
wrong: park imported content in a staging folder, not loose in the world.

**Confirm before inserting a paid asset.** Spending the user's Robux is not reversible.

## 2. Generate when nothing fits

Three generators, all slow. Wrap them in `run_as_job` and keep working; only block when the next
edit truly needs the result.

| Tool | Produces | Use for |
|---|---|---|
| `generate_mesh` | A textured MeshPart | One physical object: a sword, a crate, a tree |
| `generate_procedural_model` | A Model of primitives with tunable attributes | Anything the user will want to retune afterwards: characters, vehicles, buildings |
| `generate_material` | A MaterialVariant | Surfaces. Returns a BaseMaterial + Name that you must set on the part's `Material` and `MaterialVariant` |

Notes that save a regeneration:

- `size` on `generate_mesh` is a bounding box, so pass a real-world estimate in studs. Getting it
  wrong produces a correct mesh at a useless scale.
- `segmentation`: omit it when the user did not mention parts, `"none"` when they said single
  piece, `"explicit"` plus `partNames` (max 8) when they listed parts.
- `maxTriangles` between 12 and 20000. Do not ask for 20000 on a prop that will be spawned 200
  times.
- `generate_procedural_model` inserts itself into the workspace and exposes its knobs as
  attributes. That is the point of it: hand the user the attributes rather than hard-coding
  proportions.
- `segment_mesh` splits an existing MeshPart or Model into up to 5 named sub-parts and returns a
  new Model beside the source. Needs the source's `uniqueId`, which `inspect_instance` returns.

## 3. Images

- `store_image` turns a local png/jpg (under 5MB) into an `IMAGEID_<id>` URI for
  `attachedImageUri` on `generate_procedural_model`. That is how a reference picture becomes a
  model.
- `upload_image` takes http(s) image URLs and uploads them to the Roblox asset server, returning
  a `{ url: "rbxassetid://..." }` map. Batch them in one call. Uploaded assets go through
  moderation, so a fresh id can render blank for a few minutes.

## 4. Docs

`http_get` is allowlisted to `create.roblox.com/docs` and `github.com/Roblox/libmp`, and URLs must
end in `.md` or be `llms.txt`. Pass `query` to get only the matching sections instead of a whole
API page.

```
http_get(url: "https://create.roblox.com/docs/reference/engine/classes/BasePart.md", query: "AssemblyLinearVelocity")
```

Prefer `skill(rbx-docs-search)` when you do not already know the exact page. Never guess Luau API
shapes from memory and never web-search them: the answer is one allowlisted fetch away.
