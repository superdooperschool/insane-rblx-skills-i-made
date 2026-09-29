# Roblox Studio mode

You are working on Roblox games inside Roblox Studio. The `rbx` MCP (`mcp__rbx__studio`) is your hands. The skills in `~/.claude/skills` are your training: load the matching one BEFORE the work, not after the mistake.

## Skill routing

| Task | Load |
|---|---|
| Any Studio work: Luau, instances, assets, debugging | `studio` (the loop), `rbx` (transport), `luau` (what goes in the file) |
| Any GUI: panel, HUD, shop, popup, restyle | `ui` first. `advanced-ui` for animated or full-screen menus. `rbx-mobile` before shipping |
| Smooth Terrain: build, smooth, paint, analyse | `rbx-terrain` |
| Session start on a place with 50+ scripts | `rbx-map` |
| Before you say "done" | `rbx-verify` |
| Remotes, exploits, "can the client cheat this" | `rbx-net` |
| DataStore, attributes, MemoryStore, saved fields | `rbx-data` |
| XP curves, prices, drop odds, income | `rbx-economy` |
| Low fps, join stalls, stutter | `rbx-perf` |
| Before publishing | `rbx-release` |
| Meshes, textures, sounds | `rbx-assets` |
| Work that outlives this session | `rbx-handoff` |
| A task to finish while the user is away | `bulletproof` |
| Context getting large or expensive | `token-minimizer` |
| Why people do or do not come back | `retention-engine` |

## Hard rules

1. Never say "done" without proof from the place. Run the `rbx-verify` probes and quote the output that proves it.
2. Write Luau through `rbx write` and `rbx edit` (hash-verified, anchored, unique). Never assign `script.Source` from `execute_luau`, never use raw `script_grep`, never `multi_edit` with `replace_all`.
3. Read narrowly: outline or find first, then a window. Batch many asserts into one call. No narration between tool calls.
4. Server decides, client sends intent. Every RemoteEvent handler type-checks its arguments, checks ownership, rate-limits, and recomputes cost and eligibility from server state.
5. UI: author real instances, one root `UIScale` named `Fit` clamped to the viewport, no offset-only sizing, `UIAspectRatioConstraint` as a direct child of its frame. It must look the same on phone and PC.
6. Do not enter Play mode unless the behaviour needs a real client (input, camera, replication). Prove behaviour statically in the Edit datamodel first.
7. Surgical diffs. No drive-by refactors, no reformatting neighbours. Mention dead code, do not delete it.
8. Irreversible actions (deleting instances, overwriting hand-built scripts or terrain, touching live player data) need a confirmation first. Terrain work goes through `rbx-terrain`, which builds reversibly.
9. Same error twice: stop and report the exact error. Runtime misbehaviour with no obvious cause: read the console first.
10. Zero comments in Luau you write. Names carry the meaning. (House style. Delete this line if you like comments.)

## Report format

```
DONE: <one line on what shipped>
VERIFIED: <exact probe and the output that proves it>
SCRIPTS TOUCHED: <full instance paths>
SKIPPED: <what was not done and why>
BLOCKERS: <specific question or missing access>

PLAYTEST GOALS: <3-6 bullets, what to try and what should happen>
YOUR CHANGES: <what the user does by hand, or "none">
```
