# Semantics

Part 1 is the lookup for an error you already have. Part 2 is what to know before writing code that
produces one.

---

# Part 1. Error to cause

Read the console first. Almost every Roblox error has one overwhelmingly likely cause.

| Message | Almost always |
|---|---|
| `attempt to index nil with 'X'` | The lookup before it returned nil. Instance not replicated yet, wrong runtime, child name typo, or `FindFirstChild` result used without a guard. Read the line, not the error. |
| `attempt to call a nil value` | The function is not on the table. Either a module export is missing (an edit spliced a `function M.foo` inside another function, so it only gets assigned when *that* one runs) or a method was called with `.` instead of `:`. |
| `Argument 1 missing or nil` | `.` used where `:` was needed. `part.Destroy()` instead of `part:Destroy()`. |
| `Infinite yield possible on 'X:WaitForChild("Y")'` | A warning, not an error, and the thread is stuck forever. Name mismatch, wrong parent, or Y only exists on the other side of the client/server boundary. |
| `X is not a valid member of Y "path"` | Genuinely absent. Check spelling **and** whether it is a runtime-only child that does not exist in Edit. |
| `Unable to cast value to Object` | A nil or a string was passed where an Instance was expected. |
| `Unable to cast Dictionary to X` | A table was passed where a `Vector3` / `UDim2` / `Color3` was expected, usually from a remote round trip. |
| `attempt to perform arithmetic (add) on nil` | An attribute or config field read back nil. Never set, wrong name, or dropped by the 1024-byte attribute cap. |
| `attempt to compare nil with number` | Missing default in a config table. |
| `Requested module experienced an error while loading` | The real error is **inside** the module, one line up the stack. Do not debug the require. |
| `Requested module was required recursively` | Circular require. Break it with a lazy accessor (`local function Other() return require(path) end`) or move the shared data to a third module. |
| `Maximum event re-entrancy depth exceeded` | A handler fires the signal it is handling. |
| `Script timeout: exhausted allowed execution time` | A `while true do` with no `task.wait()` on any path. |
| `Attempt to teleport ... / Http requests are not enabled` | A Studio setting, not code. Game Settings → Security. |
| `The current identity (2) cannot <X>` | Command-bar / plugin identity. Needs a real script context. |
| `Players.X.PlayerGui ... is not a valid member` | Server touching PlayerGui before it exists, or a client-only instance. |
| `attempt to index a number with 'X'` | A shadowed variable, or a function returned a different arity than assumed. |
| `Cannot statically determine the type` (strict) | Add the annotation. It is telling you a real nil path exists. |
| **No error at all, nothing happens** | Its own class. Check in this order: script `Disabled`; wrong container (a `LocalScript` in `ServerScriptService` never runs, a `Script` in `StarterGui` never runs unless `RunContext = Client`); duplicate sibling name so `FindFirstChild` hit the wrong twin; `:Connect` on a signal that never fires; an early `return` above the code. |

---

# Part 2. Language and engine traps

## Tables

- `#t` on a table with holes is **undefined**, not "the biggest index". Track counts explicitly.
- `ipairs` stops at the first nil. `pairs` order is unspecified and varies between runs.
- Emptiness of a dictionary is `next(t) == nil`, never `#t == 0`.
- `table.remove` inside a forward loop skips the next element. Iterate backwards:
  `for i = #t, 1, -1 do`.
- `table.find` only works on arrays.
- `table.clear` reuses the allocation; `t = {}` does not and drops any other reference's view.
- Table copy is shallow by default. Nested config tables need a recursive clone or they alias.

## Numbers and strings

- Luau patterns are **not regex**. `%` escapes, `-` is the lazy quantifier, there is no `\d` (use
  `%d`), and `( ) [ ] . % + - * ? ^ $` are all magic. This is exactly why a literal search for
  `game:GetService("Players")` finds nothing when passed as a pattern.
- `/` always produces a float. `10 / 2 == 5.0`. Use `//` for floor division.
- `%` takes the sign of the divisor. `-1 % 5 == 4`.
- `string.format("%s", nil)` errors. Wrap with `tostring`.
- String indices are 1-based and inclusive on both ends: `s:sub(1, 3)` is three characters.

## Time and scheduling

- `wait`, `spawn`, `delay`, `tick` are deprecated. `task.wait`, `task.spawn`, `task.delay`,
  `os.clock`.
- `task.spawn` runs the body **immediately** up to its first yield. `task.defer` runs it at the next
  resumption point. Choosing wrong is a whole class of ordering bug.
- `task.wait(0)` is roughly one frame, not zero, and not guaranteed to be 1/60.
- `os.time()` is Unix seconds, `os.clock()` is monotonic CPU time and the only correct choice for
  measuring durations, `workspace:GetServerTimeNow()` is the synced clock for anything the client
  and server must agree on.
- `RunService`: `Heartbeat`/`PostSimulation` after physics (both sides), `PreSimulation`/`Stepped`
  before physics, `RenderStepped`/`PreRender` client only and before the frame draws.
  `BindToRenderStep` with a priority when order against the camera matters.
- **Deferred signal behaviour is the default.** A handler does not run at `:Fire()`, it runs at the
  next resumption point. Reading state on the line after `:Fire()` gives the value from before.

## Instances

- `:Connect` returns a connection that lives until disconnected. Connections made per respawn leak.
  Keep them in a table and disconnect on `Instance.Destroying` or character removal.
- `Destroy()` does not nil your variable. Set it to `nil` or the instance is kept alive by the
  reference.
- `WaitForChild(name)` with no timeout warns at 5 s and then waits forever. Pass a timeout and
  handle nil on any path that must not hang.
- `FindFirstChild(name, true)` is recursive. `FindFirstChildOfClass` is usually what "the Humanoid"
  actually means, since a child called `Humanoid` may not be one.
- `:Clone()` returns nil for `Archivable = false`.
- `workspace.CurrentCamera` is nil on the server.
- `player.Character` is nil until it spawns. `player.CharacterAdded:Wait()`, then
  `character:WaitForChild("Humanoid")` - the Humanoid is not present at the same instant as the
  model.
- `Model:MoveTo` vs `Model:PivotTo`: `MoveTo` shoves the model up to avoid collisions.
  `SetPrimaryPartCFrame` is deprecated; use `PivotTo`.
- `Humanoid:Move(dir)` needs re-issuing every frame and dies silently if anything else writes
  MoveDirection. `Humanoid:MoveTo(pos)` is the reliable one for a scripted walk.
- `Part.Position = p` ignores rotation; `Part.CFrame = cf` sets both. Setting Position on a welded
  part fights the weld.
- `:SetNetworkOwner(nil)` forces server physics authority. A client-owned part is a client-authored
  position.
- `Debris:AddItem(inst, t)` over a `task.delay` that captures the instance.

## CFrame and Vector3

- `CFrame.Angles` takes **radians**. `math.rad(90)`, never `90`.
- `cf * CFrame.new(0, 0, -5)` moves 5 studs along the CFrame's own forward. The reversed order is a
  different (usually wrong) transform.
- `CFrame.lookAt(from, to)` beats hand-built rotations. `:ToWorldSpace` / `:ToObjectSpace` beat
  manual algebra.
- `Vector3` is immutable. `v.X = 1` errors; construct a new one.
- Comparing floats for equality fails on anything derived. Use a tolerance.

## Remotes and replication

- **Every `OnServerEvent` argument is attacker-controlled.** Type-check, range-check and re-derive
  anything that matters from server state. The client sends intent, never values.
- A `RemoteFunction` invoked *on the client* lets a malicious client yield forever and hold the
  server thread. Prefer two RemoteEvents.
- Table payloads are deep-copied. Metatables and functions do not survive. Mixed array/dictionary
  keys break. A nil in the middle of varargs truncates the rest.
- `:FireAllClients` in a per-frame loop is a bandwidth bug, not a style one. Batch and throttle.
- Instances created on the client stay on the client. `ReplicatedStorage` replicates,
  `ServerStorage` does not exist client-side at all.
- With `StreamingEnabled`, a far-away part may genuinely not exist on the client yet.
  `player:RequestStreamAroundAsync`, `Model.ModelStreamingMode`, and never a bare `WaitForChild` on
  distant geometry.

## Modules

- A ModuleScript body runs **once per DataModel** and every later `require` gets the same table.
  State in a module is shared state.
- In the Edit sandbox the require cache persists for the whole session, so a module rewritten a
  second ago still returns its old table. Clone the instance and require the clone.
- Circular requires: break with a lazy accessor or a third module.
- `require(assetId)` is server-only.

## Data and attributes

- Attributes accept a limited type set: no Instance, no table, no function.
- There is a size cap (~1024 bytes) on an instance's attribute data. Past it the newest write is
  dropped **silently** - the symptom is one attribute that never appears while its siblings are fine.
- Every `DataStore`, `HttpService` and `MarketplaceService` call must be inside a `pcall` with a
  retry and backoff. They fail for reasons that have nothing to do with the code.
- `UpdateAsync` over `GetAsync` + `SetAsync`: the pair races against another server and loses data.
- Check `GetRequestBudgetForRequestType` before a loop of calls.
- `game:BindToClose` is the only chance to flush on shutdown, and it needs a real wait in Studio.

## Errors

- `pcall(f)` returns `ok, resultOrError`. `xpcall(f, debug.traceback)` when the stack matters.
- A `pcall` around something that keeps failing is a silencer, not a fix. Log once with `warn`, then
  find out why.
- `assert(cond, msg)` at a trust boundary is worth the line. `assert` on something recoverable is not.

## Strict mode

- `--!strict` at the top of a new pure-logic module catches the nil paths that otherwise surface in
  Play.
- `local part: Part? = ...` then `if not part then return end` narrows the type for the rest of the
  scope - the early-return style in the SKILL contract is also what makes strict mode pleasant.
- `::` casts (`x :: any`) exist for the cases where the engine types are wrong. Use sparingly; a
  cast that is lying is worse than no annotation.
