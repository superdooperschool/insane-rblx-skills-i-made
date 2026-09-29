---
name: luau
description: Use when writing, reading, reviewing or debugging any Luau - Roblox Studio Scripts, LocalScripts, ModuleScripts, plugins, command bar. Use when code targets the wrong runtime (Drawing, LocalPlayer, plugin, DataStore used where they do not exist), when Luau reads dense or hard to follow, and when an error like "attempt to index nil with", "attempt to call a nil value", "Infinite yield possible", "Requested module experienced an error" or a silent no-op needs root-causing.
---

# luau

The language and runtime half of Roblox work. `rbx` is the transport (how code moves in and out of
Studio). `studio` is the loop (preflight, lanes, probes, report). **This skill is what actually goes
in the file.**

Three failures this exists to kill, in order of damage:

1. Code written for the wrong runtime. `Drawing.new` in a LocalScript, `LocalPlayer` on the server,
   `plugin` at runtime, `DataStore` on the client. Compiles, then does nothing or errors at line 1.
2. Code that is correct and unreadable. Dense guard chains, 90-character lines, 200-line functions.
3. An error that gets theorised about instead of read.

| Load | When |
|---|---|
| `reference/runtimes.md` | ALWAYS, before the first line, unless the runtime is already proven. Holds the runtime matrix. |
| `reference/semantics.md` | Debugging anything, or writing code that touches modules, remotes, signals, CFrame, DataStore, attributes, streaming. Starts with the error-to-cause index. |
| `studio` skill | Instance edits, probes, MCP traps, the report format. |
| `rbx` skill | Three or more Studio calls in a row. |

## Rule 0. Name the runtime first

**Every Luau deliverable opens with one line, before the code:**

```
RUNTIME: <Server Script | LocalScript | ModuleScript (caller's context) | Plugin | Edit sandbox> @ <exact path or injection point>
```

Cannot fill it in? The task is not specified. Ask, do not guess. A ModuleScript has no runtime of its
own: it inherits the caller's, so it must not touch `LocalPlayer`, `Drawing`, or `DataStoreService`
unless the calling side is pinned and stated.

Wrong runtime is not a style issue, it is a total failure. `Drawing` is not a Roblox API at all: use a ScreenGui. `plugin` exists **only** in a plugin. Server has no `LocalPlayer`, no camera, no
`UserInputService`, no `RenderStepped`. Client has no DataStore, no `ServerStorage`, no
`.OnServerEvent`. Full matrix: `reference/runtimes.md`.

## Rule 1. Readability contract

Enforced on every script written or edited. No exceptions for "quick" scripts.

**File order:** services → requires → constants (`SCREAMING_SNAKE`) → module table / state → local
helpers → exported functions → connections → `return M`.

**Shape**
- Functions under ~40 lines, under 3 levels of nesting. Over that, extract a named `local function`.
- Early return over nested `if`. `if not humanoid then return end`.
- One statement per line. No `;` chaining. Lines under 100 characters.
- Blank line between logical blocks. Never a 30-line wall.
- Declare locals near first use, not in a 20-line block at the top.
- Table literal: one entry per line once it has more than three entries or any nesting.
- No `a and b or c` longer than one short expression, and never nested.

**Names**
- Functions are verb-first: `applyDamage`, `spawnWave`, not `damage`, `wave`.
- Booleans read as predicates: `isReady`, `hasKey`, `canFire`.
- No `t`, `v2`, `tmp`, `data2`. `i` is allowed only in a numeric `for`.
- Magic numbers become named constants: `local RESPAWN_DELAY = 3`.

**Always**
- `local function` for everything not exported. `M.foo` only for the public surface.
- `task.wait` / `task.spawn` / `task.delay`. Never `wait` / `spawn` / `delay`.
- `:GetService()`, never `game.Players`.
- Attributes and CollectionService over name matching.
- Server decides. The client sends intent, never values. Type-check every `OnServerEvent` argument.
- `--!strict` on new pure-logic ModuleScripts. It catches the nil bugs before Play does.

**Never**
- `print()` for status. `warn()` only for a genuine error.
- Comments of any kind (house rule: zero comments, see rbx skill). No headers, no why-notes, no
  banners. Good names carry it.

### Before / after

```lua
-- unreadable: one line, guard soup, no names, no validation boundary
local p=game:GetService("Players");local rs=game:GetService("ReplicatedStorage")
local function h(plr,d) if plr and plr.Character and plr.Character:FindFirstChild("Humanoid") and d and type(d)=="number" and d>0 then local hum=plr.Character.Humanoid if hum.Health-d<=0 then hum.Health=0 rs.Died:FireAllClients(plr.Name) else hum.Health=hum.Health-d end end end
```

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Died = ReplicatedStorage:WaitForChild("Died")

local function applyDamage(player: Player, amount: number)
	if typeof(amount) ~= "number" or amount <= 0 then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.Health = math.max(humanoid.Health - amount, 0)
	if humanoid.Health == 0 then
		Died:FireAllClients(player.Name)
	end
end
```

Same behaviour, zero comments, and the invalid-input and already-dead cases are now visible instead
of buried in a conjunction.

## Rule 2. Debug loop

Run it in order. Skipping a step is how a session turns into the user directing every move.

1. **Read the console before forming any theory.** `$R console` (or `get_console_output`). It is
   free and it names the script, the line and the stack. A bug reported without its error text is
   not yet a bug report: go get the text.
2. **Classify the message.** `reference/semantics.md` opens with the error-to-cause index. Most
   Roblox errors have one overwhelmingly likely cause; look it up rather than reasoning from first
   principles.
3. **Locate, do not read.** `$R find "<literal symbol>"` then `$R outline` then `read --from/--to`.
   Never pull a whole script into context to find one thing.
4. **Reproduce with one probe.** A single `lua` call in the Edit datamodel that evaluates the
   failing expression and returns a table of evidence. State what the probe would print if the
   theory is right, *before* running it.
5. **Root cause, not the reported path.** Grep every caller of the function about to be changed. One
   guard in the shared function beats a guard in the one caller that filed the ticket, and leaves
   the sibling callers fixed too.
6. **Fix, then re-probe and read back.** An edit that was not read back did not happen.
7. **Same error twice: stop.** Report the exact error and the last attempt. Never blind-retry.

**Ablate with a value, never by deleting.** Set a rate to 0 or flip a config flag to prove which
system owns the symptom. Reparenting or deleting instances to "measure without X" costs more than X
and produces a lie.

## Rule 3. Verify before claiming

- Static first: compile the script, check the container, check `Disabled`, check for duplicate
  sibling names. `studio` skill, Step 6.
- A LocalScript that cannot run in Edit is still syntax-checkable: wrap the whole body in
  `return function() ... end` in a temp ModuleScript and `require` it. Compilation proves syntax
  without executing a line.
- A ModuleScript's real exports need a **fresh** require. `RBX.req(path)` clones first; a plain
  `require` in Edit hands back the table from before the rewrite.
- Perf claims need a time series with p50 / p95 / p99 / max and a count of frames over 16 ms and
  33 ms, taken while moving in a straight line into new ground. A mean frame time and a standing
  screenshot prove nothing.

## Red flags - stop

| Thought | What it actually means |
|---|---|
| "It's a LocalScript so `Drawing` should work" | Drawing is not a Roblox API. Wrong runtime. Re-read Rule 0. |
| "I'll just add a `pcall` around it" | Silencing an error is not fixing it. Find why it throws. |
| "Probably a race, I'll add a `task.wait(1)`" | A sleep is not a fix. Wait on the actual condition or signal. |
| "The module looks right, so the require is fine" | Edit caches requires. Clone first, then look. |
| "I'll read the whole file to be safe" | find → outline → window. Whole reads burn the session. |
| "It printed the success message" | Returned tallies lie. Read the state back. |
| "Nothing in the console, so no error" | Silent no-op is its own class: wrong container, wrong class, `Disabled`, or a signal that never fires. |
| "This is a one-liner, style doesn't apply" | The contract has no size exemption. |
