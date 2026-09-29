---
name: rbx
description: Drive Roblox Studio from the shell instead of through MCP tool calls. Use for ANY Roblox Studio work - Luau, instances, UI, scripts, debugging, performance - whenever the Roblox_Studio MCP would otherwise be called repeatedly. Also use when Studio MCP feels slow, when edits silently fail to land, when script_grep returns nothing for a string that exists, or when a require returns stale module state.
---

# rbx

**TOKEN PROTOCOL (token-minimizer, always on with this skill):** cost = context x calls. Outline/find before read; read only a window (`--from/--to`); anything over ~4k chars goes `--out` + grep; anchored `edit` not full `write`; one batched `lua` with N asserts; independent calls in one message; `health` only after an error; capture once, read once; no narration between calls; STATUS + new session at ~150k context. Full rules: `~/.claude/skills/token-minimizer/SKILL.md`.

**ZERO COMMENTS (no exceptions):** never write a comment in any script you write or edit (Luau, JS, shell, anything) - no `--`, no `--[[ ]]` header blocks, no `//`, no `#` lines, no section banners, no WHY notes, no dated tags. Luau mode directives such as `--!strict` and shebang lines are not comments. Names carry meaning. Leave existing comments in untouched code alone unless asked. Before every `write`/`edit`, check the new text has no `--` comment line. (A `--old`/`--new` value that itself starts with `--` is parsed as a flag: pass it as a file.)

**Roblox skill routing (load the one that matches before working):** `ui` any GUI; `rbx-map` session open on a big place (grep `<project>/MAP.md`); `rbx-verify` before any "done"; `rbx-handoff` multi-session/overnight; `rbx-perf` fps/join/stutter; `rbx-data` DataStore/attributes/MemoryStore; `rbx-economy` XP/prices/odds; `rbx-net` remotes/channels/exploits; `rbx-release` before publish; `rbx-assets` meshes/sounds/images; `rbx-mobile` phone/console layout; `rbx-terrain` any Smooth Terrain build, revamp, smoothing or paint (roblox studio terrain).

**UI work of any kind (ScreenGui, Frame, button, list, popup, restyle): load the `ui` skill first** - house style, anatomy, motion defaults, `panel.lua` builder, `audit.lua` lint.

Roblox's `StudioMCP.exe` is a stdio proxy in front of a local websocket host. That host is reachable
directly, so the MCP tool layer can be skipped entirely. `rbx` is two front ends over one transport.

**1. The `mcp__rbx__studio` tool** (installed; it replaced the old `Roblox_Studio` server). One tool,
`op` + `args`, fronting all 28 Studio tools:

- 28 raw schemas cost **15,660 tokens in every request**. This one costs **773 - a 95.1% cut**,
  ~14,900 tokens saved per request, and nothing is lost: every raw tool is still an `op`.
- `op:"help"` with `{op:"<name>"}` returns that tool's full argument schema on demand. Call it
  instead of guessing arguments.

**2. The CLI**, for a burst of calls in one turn - ten Studio calls for one model turn:

```
R="node $HOME/.claude/skills/rbx/rbx.mjs"
```
Measured: **10 full round trips in 1.04s (~104ms each, including node startup).**

Both share `lib.mjs`, so the verified write paths are identical. The table below gives CLI syntax;
the tool takes the same names as `op`, with the flags as `args`.

## Preflight

```bash
$R health
```
Prints port, studio count, and the open place. `(NO PLACE OPEN)` means Studio is running but idle -
ask the user to open the place; nothing else will work. `StudioMCP.exe is not running` means Studio
is closed.

If more than one Studio is connected, every command needs `--studio <id>` (`$R studios` lists them).

## Commands

| Command | Notes |
|---|---|
| `$R lua '<code>'` / `$R lua file.lua` / `$R lua -` | Runs Luau, prints the return value. `--dm Edit\|Client\|Server`, default `Edit`. |
| `$R read game.Path [--from N --to M] [--out f]` | Script source. |
| `$R find <term> [--path P] [--word] [--i] [--comments] [--limit N]` | Literal search that **skips comments**. Line numbers match `read` exactly. `grep` is an alias. |
| `$R outline <game.Path>` | Every function definition with its line number, without reading the file. |
| `$R tree <path> [--type T] [--kw K] [--depth N] [--limit N]` | Filtered instance tree. |
| `$R write game.Path file.lua` | Full-file rewrite, hash-verified. |
| `$R edit game.Path --old <file\|string> --new <file\|string>` | Single anchored edit, uniqueness enforced. |
| `$R console` | Studio output log. |
| `$R capture [id] [--dir d] [--from '[x,y,z]'] [--at '[x,y,z]']` | Renders the viewport, saves the JPEG, prints the path. `Read` that path to look at it. |
| `$R call <tool> '<json>'` | Raw `tools/call` on any of the 28 tools. Escape hatch. |
| `$R tools` | Tool names. |

Output over 4000 chars is truncated to a temp file whose path is printed. `--out <file>` sends it
straight to a file and prints only a size line - use it for anything you are going to grep rather
than read.

## Luau helpers

Available inside `lua`, `write`, and `edit` code. Injected only when the code mentions `RBX.`.

| Helper | Purpose |
|---|---|
| `RBX.find(path)` | Resolve `"game.ServerScriptService.Foo"`, errors naming the missing segment. |
| `RBX.set(inst, prop, val)` | Property write wrapped in `ChangeHistoryService`, returns the readback. |
| `RBX.src(inst, new)` | `ScriptEditorService:UpdateSourceAsync`. |
| `RBX.req(path)` | Require a fresh clone - never a cached table. |
| `RBX.hash(s)` | djb2, for verifying a write landed. |

## Traps this removes

Each of these is a real, reproduced failure of the raw MCP tools. All verified on a live place by
`selftest.sh`.

1. **`script_grep` is replaced outright by `find`.** Three separate defects: its query is a Luau
   *pattern*, so `( ) [ ] . - % + * ?` are metacharacters and `game:GetService("Players")` returns
   `No matches found` in a place holding three of them; its line numbers are OFFSET from
   `script_read`; and it matches inside comments. `find` is a real Luau scanner run in Studio -
   literal by default, comment-blind, exact line numbers, scoped by `--path`. Never call
   `script_grep` directly.
2. **`script.Source = "..."` never syncs.** It writes a detached in-VM copy; `read` and Play keep
   seeing the old text. `$R write` uses `UpdateSourceAsync` and then compares a hash of the readback
   against one computed locally. Mismatch exits 2 - a silent bad write is impossible.
3. **`multi_edit` matches raw substrings, first match wins, no uniqueness check.** A short anchor has
   spliced a whole block into the middle of an unrelated one-liner - valid Lua that only failed at
   runtime. `$R edit` counts occurrences first and refuses when the anchor is not unique.
4. **`multi_edit`'s `replace_all: true` is a silent no-op** and still reports edits applied. Do not
   use it. `$R edit` one anchor at a time; after the first rewrite the second occurrence is usually
   unique on its own.
5. **`require` inside `execute_luau` caches for the whole Edit session,** so a module you just
   rewrote hands back its old table. `RBX.req` clones first, so the cache key is always fresh.
6. **Plain property writes can revert** between calls. `RBX.set` commits through
   `ChangeHistoryService`.
7. **`execute_luau`/`lua` cannot create a Script, LocalScript, or ModuleScript ANYWHERE** -
   `Instance.new("Script").Parent = <any container>` fails with `The current thread cannot reparent
   '<name>' to '<path>' since '<path>' has additional values for the Capabilities property:
   LoadUnownedAsset (and 3 more)`. Reproduced in ServerScriptService, ReplicatedStorage, StarterGui,
   StarterPlayerScripts, and plain Workspace - it is the sandboxed Luau thread that lacks
   script-injection capability, not a per-service restriction, and no amount of retrying, cloning an
   already-valid script, or using the two-arg `Instance.new(class, parent)` form gets around it.
   **This is not a dead end - `multi_edit` creates scripts fine**, because it goes through Studio's
   own `ScriptEditorService` path instead of the sandboxed thread: pass `className` and a first edit
   with `old_string: ""` to seed the source. See "Creating new scripts" below. Do not conclude a
   script can't be created and ask the user to insert it by hand - it can, just not via `lua`.

8. **Concurrent sessions used to lose responses.** Every CLI process numbered requests from 1, so two sessions
   calling Studio at once shared a JSON-RPC id: one got a 300 s timeout (or the other caller's result). `lib.mjs`
   now starts ids at a random base (2026-09-27; proven with overlapping 6 s + short calls). A timed-out call still
   ran in Studio: ping first, never blindly re-fire a heavy write. Sessions started before the fix keep the old
   ids in their MCP server until restarted.

## Creating new scripts

`write` and `edit` both require the target to already exist (`write` on a missing path fails with
`no such instance`). The only creation path is the raw `multi_edit` tool, via the CLI escape hatch
or the MCP tool directly:

```bash
$R call multi_edit '{"file_path":"game.ServerScriptService.Foo.Bar","className":"Script","datamodel_type":"Edit","edits":[{"old_string":"","new_string":"-- initial source"}]}'
```

`className` is `Script` / `LocalScript` / `ModuleScript`; the first edit's `old_string` must be `""`
to seed the content, and any further edits in the same call apply on top of it. Works in every
service, including ServerScriptService and StarterPlayerScripts, in one call - no manual Studio step
needed. After creation, `write`/`edit` work on it normally like any other script.

## Working rules

- **Batch.** One `lua` call with ten asserts returning one table beats ten calls. The round trip is
  cheap now, but a model turn is not.
- **Filter before printing.** `--out` then `grep`, rather than paging a script into context.
  `$R tree` unfiltered on a real place is thousands of wasted tokens.
- **Verify writes by reading back,** not by trusting a success message. `write` and `edit` already
  do; if you use `call multi_edit` for any reason, re-read and count.
- **Never trust a returned edit tally.**
- Errors come back as `ERROR: <text>`; `write`/`edit` exit 2 when unverified.

## Searching code

`find` blanks comments before matching but preserves newlines, so **line numbers stay identical to
`read`** - verified in `selftest.sh` by searching for a line and reading that exact number back.

- Line comments, `--[[ ]]` and `--[==[ ]==]` are all removed. String literals are kept, so
  `FindFirstChild("Humanoid")` still matches.
- `--comments` opts them back in when you actually want to search prose.
- `--word` requires non-identifier characters on both sides, so `ZEBRAWORD` will not match
  `ZEBRAWORDINSIDE`.
- `--path Workspace.Foo` scopes the scan; the path may name a container or a single script.
- Scripts not containing the raw term are rejected before the comment scan, so a whole-place search
  only pays for candidates.

`outline` is the cheap way to learn a file: `StarterPlayer.StarterPlayerScripts.GrassLOD` is 883
lines, and its outline is 30 definitions in ~360 tokens against ~10,600 to read it whole. Outline
first, then `read --from/--to` the one function you need.

## Setup and self-repair

```bash
node $HOME/.claude/skills/rbx/setup.mjs           # install or repair both hosts
node $HOME/.claude/skills/rbx/setup.mjs --check   # report only, changes nothing
node $HOME/.claude/skills/rbx/setup.mjs --uninstall
```

Idempotent - running install on a correct system rewrites nothing. It removes the stock
`Roblox_Studio` from Claude Code (both scopes) and Codex, registers `rbx`, backs up
`config.toml` before any edit, validates the result with `tomllib`, and **restores the backup if
the edit produced invalid TOML**. It warns when Codex is running, because Codex rewrites its own
config and will clobber the change.

## Studio restarts are handled automatically

Nothing to re-run when you close a place, open another, or restart Studio:

- The studio list is refreshed **before every call**, so a newly opened place is picked up and a
  closed one drops out on the next call.
- A dead websocket is detected by `readyState` and reconnected transparently.
- On a transport error the port cache is discarded and the proxy is rediscovered, then the call is
  retried once.
- When exactly one place is open, that one is used even if another Studio is connected with no
  place; `studio_id` is only required when genuinely ambiguous.

## Token budget - the reason this exists

Measured on this machine, on a real place:

| Cost | MCP tools | rbx |
|---|---|---|
| 28 tool schemas | **15,660 tokens, in every request** | 0 - there are no tool definitions |
| `script_read` of `Workspace.SkinnedGrass.Config` (126,739 chars) | **34,981 tokens, re-sent every turn after** | ~120 (`--out` to a file, then `grep`) |
| `screen_capture` | ~730 KB of base64 in a tool result | 0 - saved as a JPEG, `Read` the path |

The middle row is the one that actually kills a session: a tool result is permanent context, and
every later turn re-sends it. **Never pull a script into context to look for one thing.**
`--out` it, then `grep`. Read a window with `--from/--to` only once you know the line.

Binary content is never inlined: any image or audio a tool returns is written to disk (`--dir` to
choose where) and reported as a one-line path.

## Which front end

- **Tool** (`mcp__rbx__studio`): default. One or two calls, or anything inside a plan step.
- **CLI**: three or more calls in a row, or when piping output straight into `grep`. Also the only
  one a delegated worker can use.
- Neither has a capability gap - `op`/`call` reaches all 28 tools, and `help` gives you any schema.

## Installed in both hosts

The original `Roblox_Studio` server is removed from Claude Code (user and project scope) and from
Codex. Both launch this one instead:

- Claude Code: `claude mcp list` shows `rbx: node .../server.mjs`.
- Codex: `[mcp_servers.rbx]` in `~/.codex/config.toml`. The path must be a TOML **literal** string
  in single quotes - a basic double-quoted string breaks the entire file, because the backslash-U
  in `C:\Users` is parsed as a unicode escape. Validate any edit with
  `python -c "import tomllib;tomllib.load(open('config.toml','rb'))"`.
- Codex rewrites its own config while running, so make config edits with Codex closed.

## Restoring the old server

```bash
claude mcp remove rbx -s user
claude mcp add Roblox_Studio -s user -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
```
Takes effect on the next Claude Code restart, as does any change here.

## Play mode

Play auto-stops within seconds in a backgrounded Studio. Do setup, assert, and return in **one**
`lua --dm Server` call; do not split across calls. Client heartbeat and handshake systems will not
reach ready state without a real focused playtest by the user - say so rather than reporting a
system verified.

## Self-test

```bash
bash $HOME/.claude/skills/rbx/selftest.sh
```
Creates `ReplicatedStorage.RBXSelfTest`, exercises all nine behaviours above, destroys it. Touches
nothing else. Run it if a command misbehaves or after a Studio update.
