---
name: rbx-verify
description: Use before reporting any Roblox Studio change as done, after editing more than one script, before a publish, when tempted to start Play mode to "check it works", or when a task ends with "verified" and no evidence. Also use to test data/service code that cannot be required in Edit.
---

# rbx-verify

**One batched proof instead of a play-mode loop.** 185 play toggles and the same compile-all helper
re-sent 60+ times across 114 sessions. Everything below runs in the Edit datamodel, read-only, and
returns one table.

## The pass (every task, in this order)

| Step | Command | Must show |
|---|---|---|
| 1 Static | `$R lua ~/.claude/skills/rbx-verify/scripts/verify.lua` | `!`-prefixed rows = 0 (or each one explained in the report). Scope one service: `sed "s\|__SCOPE__\|ServerStorage\|" verify.lua \| $R lua -` |
| 2 Fresh module | `$R lua 'local M = RBX.req("ReplicatedStorage.X") return { a = M.f(1) == 2, b = ... }'` | every boolean true. `RBX.req` clones first; plain `require` returns the pre-edit module |
| 3 Read-back | `$R read <script> --from N --to M` after `edit`/`write`, or `$R lua` reading the property in a **separate** call | the new text/value is there (same-call reads can revert) |
| 4 Anchor count | before `multi_edit`: `$R find "<anchor>" --path <script>` | exactly 1 hit |
| 5 Behaviour (server) | one `$R lua --dm Server` with setup + asserts + return, never split across calls | table of booleans |
| 6 UI | `ui` skill audit + one capture | `ISSUES: 0`, capture read once |

Play mode: only for behaviour that needs a real client (input, camera, replication). Some places cannot be playtested over MCP: try once, then fall back to static probes. Setup + assert + return in
ONE call; auto-stops in seconds when Studio is backgrounded.

## What verify.lua checks

Compile every script (`loadstring`), Net contract (`fire` without `handle`, `handle` never fired,
`reply/broadcast` never listened), `print()` calls, debug flags (`local FAKE/DEBUG/AUTO_*/TEST/BYPASS = true`),
font literals outside UIKit, `.Source =` writes, DataStore calls in LocalScripts, `LocalPlayer` in
server scripts, legacy `wait`/`spawn`, `a and true or b`, attribute strings near the 1024-byte cap,
remote instances no script references. `_Parked/_Removed/_Archive/_Backup` folders are skipped.
Known blind spot: channels registered via a variable look unhandled - check by hand, say so.

## Testing what cannot be required (DataService, BazaarService, anything with BindToClose)

`reference/harness.md`: the setfenv harness. Load the module source with `loadstring`, give it a fake
`game.GetService` returning in-memory DataStore/MemoryStore doubles, a `require` shim for its deps,
an `os.time` you can step, and swap its final `return X.start()` for `return { svc = X, ... }`. Deep-copy
on every fake store read/write so serialisation round-trips are real. Run scenarios as asserts.

## Rules

- "Verified" in a report means step 1 output + the booleans from steps 2/5 are in the report.
- Never trust an edit tally or a success string; read back.
- Same error twice = stop and re-read the trap list (`studio` skill), not a third retry.
- Re-enabling a disabled LocalScript mid-Play spawns a duplicate; restart Play instead.

## Red flags

- "Let me start Play to see if it works" before step 1 has run
- `require(` in a `lua` call after editing that module
- A report with "should work" / "compiles" and no table of booleans
- Writing the compile-all loop inline again instead of running verify.lua
