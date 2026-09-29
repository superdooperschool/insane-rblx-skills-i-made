---
name: studio
description: Roblox Studio work through the rbx MCP server (one `studio` dispatch tool, op + args). Preflights the place, picks a lane, offloads recon to the Studio-side explore subagent, edits with verified writes, proves behaviour statically in the Edit datamodel, and hands back a playtest checklist. Use for any Luau, instance, UI, asset, performance, or debugging work inside Roblox Studio.
---

# studio

**TOKEN PROTOCOL (token-minimizer, always on with this skill):** cost = context x calls. Outline/find before read; read only a window (`--from/--to`); anything over ~4k chars goes `--out` + grep; anchored `edit` not full `write`; one batched `lua` with N asserts; independent calls in one message; `health` only after an error; capture once, read once; no narration between calls; STATUS + new session at ~150k context. Full rules: `~/.claude/skills/token-minimizer/SKILL.md`.

**Roblox skill routing (load the one that matches before working):** `ui` any GUI; `rbx-map` session open on a big place (grep `<project>/MAP.md`); `rbx-verify` before any "done"; `rbx-handoff` multi-session/overnight; `rbx-perf` fps/join/stutter; `rbx-data` DataStore/attributes/MemoryStore; `rbx-economy` XP/prices/odds; `rbx-net` remotes/channels/exploits; `rbx-release` before publish; `rbx-assets` meshes/sounds/images; `rbx-mobile` phone/console layout; `rbx-terrain` any Smooth Terrain build, revamp, smoothing or paint (roblox studio terrain).

Everyday driver for Roblox Studio work through the `rbx` MCP server: one `mcp__rbx__studio` tool taking
`op` and `args`. It fronts all 28 Studio tools for ~5% of the schema cost, and its preferred ops fix
six bugs the raw tools have. `op:"help"` returns any op's argument schema.

This file is the loop. The heavy detail lives in `reference/` and is loaded ONLY when the
task needs it. Do not read a reference file speculatively.

| Load | When |
|---|---|
| `luau` skill | Before writing or debugging any Luau. Runtime targeting, the readability contract, the error-to-cause index. |
| `reference/probes.md` | Any verification step. Contains the preflight and all 15 probes. |
| `reference/traps.md` | A symptom in the index below matches, or something behaves impossibly. |
| `reference/ui.md` | ScreenGui, Frame, layout, mobile, or anything the player looks at. |
| `reference/assets.md` | Need a mesh, model, image, audio, material, or a Toolbox asset. |
| `reference/playtest.md` | Play mode, runtime errors, console output, profiling, input automation. |
| `reference/systems.md` | Building a system that does not exist yet (the interrogation). |

## Step 0. Preflight (one round trip, always)

1. `op:"health"` → port, studio, and the open place. `studio_id` is filled in automatically when one
   Studio is connected. `(NO PLACE OPEN)`: stop, "Open Studio and set the place active."
2. `op:"get_studio_state"` → play state and which datamodels (`Edit`/`Client`/`Server`) are
   reachable. Never guess a `datamodel_type`; a wrong one fails, though the error now names what is
   available.
3. One `op:"lua"` (Edit) for identity:
   `return { name = game.Name, placeId = game.PlaceId, streaming = workspace.StreamingEnabled, published = game.PlaceId ~= 0 }`
   PlaceId 0 means the place has never been published: grey/missing meshes are streaming
   placeholders, not a bug you introduced.
4. Place memory: `Grep` for the place name across `~/.claude/projects/*/memory/`. Read every hit.
   These hold locked user decisions and traps that cost real money to relearn. No memory
   directory, no hits: continue silently, never mention it.

Task is not Studio work → say so and exit the skill. Never touch Studio settings, plugins, or
MCP config. Never web-search Luau syntax; use `skill(rbx-docs-search)` or test it in-engine.

## Step 1. Efficiency doctrine (this is where the budget goes)

Context spent on reading is context not spent on thinking. In order of leverage:

0. **Two transports, both `rbx`.** The `mcp__rbx__studio` tool is the default and covers everything.
   For a burst of calls, load the `rbx` skill and use its CLI instead: a Studio call becomes a shell
   command (~104ms measured), so ten calls cost one turn rather than ten. Prefer the ops named
   `lua/read/grep/tree/write/edit/capture` over the raw tool names - they fix six reproduced bugs
   (`script_grep` pattern escaping, detached `.Source` writes, non-unique `multi_edit` anchors, the
   `replace_all` silent no-op, the stale `require` cache, reverting property writes). Anything
   returning an image is saved to disk and handed back as a path; `Read` that path.
1. **Offload recon to the Studio-side subagent.** `subagent(subagent_type: "explore")` searches the
   place and returns a summary; the file dumps never enter this conversation. Use it for "where is
   X handled", "which scripts touch Y", "map the flow from A to B". Give it one concrete question
   and tell it to return exact instance paths and function names.
2. **Never `script_read` a whole large script.** `script_grep` first, then read a window:
   `should_read_entire_file: false, start_line_one_indexed: N, end_line_one_indexed_inclusive: M`.
   Full reads are for files under ~200 lines or a final self-review of something you wrote.
3. **Batch asserts into one `execute_luau`.** Each MCP call is a round trip. Ten checks in one
   script that returns one table beats ten calls, every time.
4. **Filter the tree, do not dump it.** `search_game_tree` takes `path`, `instance_type`,
   `keywords`, `max_depth`, `head_limit`. An unfiltered call on a real place is thousands of
   wasted tokens.
5. **Use the built-in Roblox skills instead of reinventing.** `skill(<name>)`:
   `rbx-debug` (breakpoints, thread state), `rbx-perf-profiling` (MicroProfiler via LibMP),
   `rbx-scene-analysis` (render/memory/instance audit), `rbx-device-simulator-lua` (UI across
   device form factors), `rbx-unit-test`, `rbx-docs-search` (Engine API via `http_get`).
6. **`run_as_job`** for `generate_mesh` / `generate_material` / `generate_procedural_model`, then
   keep working. Only block on the result when the next edit genuinely needs it.

## Step 2. Pick the lane (automatic, never ask which)

| Situation | Lane |
|---|---|
| Default, anything not covered below | QUICK |
| A system that does not exist yet | SYSTEM interrogation (`reference/systems.md`), then QUICK |

**QUICK is the default and you do the work yourself.** Size is not a reason to hand work off. If a job is genuinely too large for this session, say so and ask.

QUICK is: recon, edit, static verify, short report. One clarifying question maximum, and only if
the target is truly ambiguous.

## Step 3. Playtest list BEFORE code

Three to six bullets of what to try in Play and what should happen. This is a design check, not a
test suite. **If you cannot write a bullet, the feature is not specified: go back and ask.** Carry
the list to the report as PLAYTEST GOALS.

## Step 4. Recon

- Exact paths only. `search_game_tree` + `inspect_instance`. Never a guessed path.
- `script_grep` / `script_search` for existing logic before writing new. Reuse beats duplicate.
- `script_grep` treats the query as a Luau **pattern**: `( ) [ ] . - % + * ?` are special, so
  `FindFirstChild("X")` matches nothing. Grep a plain literal substring instead.
- `script_grep` line numbers are OFFSET from `script_read` on large scripts. Match edits by
  CONTENT, never by line number.
- `inspect_instance` returns every readable property of one instance. Use it before writing a
  property, not after being surprised.

## Step 5. Edit with landed-write discipline

- Read before you edit. Never blind-edit.
- `multi_edit`'s `old_string` is a raw substring search, first match wins, no uniqueness check.
  Verify the anchor is unique (Probe 8) before using it. Short anchors like `return GameConfig`
  have spliced whole blocks into the middle of an unrelated one-liner: valid Lua, fails at runtime.
- Inserting before a module's final `return`: anchor on enough trailing context to be
  unmistakably the last one, or append and re-read the tail.
- Full-file rewrite:
  `game:GetService("ScriptEditorService"):UpdateSourceAsync(inst, function() return newSrc end)`.
  Setting `script.Source = "..."` from `execute_luau` writes a DETACHED in-VM copy that never
  syncs. `script_read` and Play keep seeing the old source.
- Property and attribute writes from `execute_luau` can silently revert. Wrap them:

```lua
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("studio-edit")
inst.SomeProperty = value
CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
```

- `execute_luau` runs in a SANDBOXED global env. Its `_G` is isolated from game scripts, so
  `_G.Foo = x` never reaches them, and `require` is not exposed (use Probe 2). Drive live systems
  through Instance APIs (`Remote:FireClient(plr, payload)`).
- `require` errors mentioning capabilities: check `Sandboxed` and `Capabilities` on BOTH the
  module and the requiring script. Fixing one side only flips the error.
- `execute_luau`/`lua` can NEVER create a Script/LocalScript/ModuleScript, in any service
  (`...cannot reparent ... Capabilities property: LoadUnownedAsset...` - a sandboxed-thread
  limit, reproduced everywhere from ServerScriptService to Workspace). This is not a blocker:
  the raw `multi_edit` op creates scripts fine (it uses `ScriptEditorService`, not the sandboxed
  thread) - pass `className` and a first edit with `old_string: ""` to seed the source, then
  `write`/`edit` it normally afterward. Never conclude a script needs to be inserted by hand.
- After every write, read it back in a SEPARATE call. An edit you did not verify did not happen.
- `multi_edit` only works in the `Edit` datamodel and FAILS during Play.

## Step 6. Verify statically (default: no Play)

Load `reference/probes.md`. Minimum bar:

| You did | Run |
|---|---|
| Anything at all | Preflight (compile + container + duplicate + disabled, one call) |
| Edited a ModuleScript | Probe 2 (real exports) and Probe 3 (fresh state) |
| Used `multi_edit` | Probe 8 (anchor uniqueness) before, re-read after |
| Wrote attributes | Probe 4 (1024-byte cap) and Probe 9 (read-back) |
| Touched UI | Probe 7 (scale audit) and `screen_capture` |
| Touched world geometry | `screen_capture` with `camera_position` + `look_at_position` |
| Added a RemoteEvent | Probe 12 (remote surface) |
| Perf complaint | Probe 14 (render budget) then `skill(rbx-scene-analysis)` |

`screen_capture` is the only way to know a build looks right. Use it for any visual change; a
tree that reads correct in JSON can render as a grey box in the viewport.

## Step 7. Self-review

- Re-read every changed script end to end.
- Trim anything the request did not ask for.
- No TODO, placeholder, or mock left unflagged. No `print()` spam.
- Zero comments in code you write (no exceptions, see rbx skill). No headers, banners or why-notes.
- State the edge cases the user implied but did not say.

## Step 8. Report

```
DONE: <one line on what shipped>
VERIFIED: <exact probe + the output that proves it, yours, not a worker's claim>
SCRIPTS TOUCHED: <full instance paths>
SKIPPED: <what was not done and why>
BLOCKERS: <specific question or missing access>

PLAYTEST GOALS: <the Step 3 list, 3-6 bullets, what to try and what should happen>
YOUR CHANGES: <what the user does by hand: restyle, retune, decide, or "none">
```

The last two lines are MANDATORY on every lane including QUICK. Never omit, never reorder, never
put anything after them. Never end with a save or publish reminder; assume the place autosaves.

## Hard rules (enforced silently, never asked about)

**UI** (detail in `reference/ui.md`; load the `ui` skill for the house style, kit, motion defaults and audit)
- Author real instances. Clone authored Templates. Never `Instance.new` a UI tree.
- One root `UIScale` named `Fit`. Offset-only sizing is banned.
- Pop animations go on an INNER `UIScale` so they multiply with `Fit`.
- `UIAspectRatioConstraint` is a DIRECT child of the frame it constrains.

**Code**
- No `print()` for status. `warn()` only for real errors.
- Surgical diffs. No drive-by refactors, no reformatting adjacent code. Mention dead code, do not
  delete it. Remove only what this change orphaned.
- Luau idioms: `task.wait` / `task.spawn`, `:GetService()`, attributes and CollectionService over
  name matching.
- Server decides, client sends intent only, never values.

## Stuck rules

- Same error twice: stop. Report the exact error and the last attempt. No blind retry.
- Runtime misbehaviour with no obvious cause: `get_console_output` FIRST. It is the primary error
  channel and it is free.
- Session lost mid-task: `list_roblox_studios`, ask the user to resume.
- More than 15 tool calls with no measurable progress: stop, summarise, ask.
- Irreversible action (deleting an instance, overwriting an hand-authored script with no backup,
  touching live player data): confirm first, always.

## Trap index (symptom → cause)

Full detail in `reference/traps.md`.

| Symptom | Cause |
|---|---|
| Last attribute written vanishes, others fine | 1024-byte attribute cap on that instance |
| Explorer value change does nothing | In-file tuning table beats the Value instance in the getter |
| Edited module still runs old code | `require` caches per instance in Edit; clone-require-destroy |
| `script.Source = ...` did not stick | Detached in-VM copy; use `UpdateSourceAsync` or `multi_edit` |
| Property reverts on the next call | Missing `ChangeHistoryService` recording wrapper |
| Edit spliced into the wrong function | Short `multi_edit` anchor, first match wins |
| `_G` write invisible to game scripts | `execute_luau` global env is sandboxed; use Instance APIs |
| World build resets every restart | Built at server boot instead of from the Edit datamodel |
| Script exists, never runs, no error | Wrong container or class, or `Disabled = true` (preflight) |
| `FindFirstChild` returns the wrong twin | Duplicate sibling names (preflight) |
| Quest or objective never completes, no error | Name derived from a stripped attribute; unknown names only warn |
| Long join stall, huge Frames count | A closed panel building its whole tree on the join frame |
| `require` capability error | `Sandboxed` / `Capabilities` mismatch between module and caller |
| New Script/LocalScript/ModuleScript won't reparent from `lua` | Sandboxed thread can't inject scripts anywhere; use `multi_edit` with `className` instead |
| Grey or missing meshes | Place never published, or StreamingEnabled placeholders |
| FPS looks fine in Studio, bad in game | Studio viewport is vsync-locked; Studio FPS lies |
| Server script not found while reading | You are in Play: reads see the CLIENT datamodel only |
