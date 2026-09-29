# probes

Static verification, run through `execute_luau` with `datamodel_type: "Edit"`. Nothing here
enters Play. Nothing here executes game logic unless the probe says it does.

Rule: **an edit you did not verify did not happen.**

---

## PREFLIGHT — one call, seven checks

Run this first on any non-trivial task, and again after a batch of edits. It walks the tree once
and returns a compact table. Everything in it used to be a separate round trip.

```lua
local SGui = game:GetService("StarterGui")
local SPlayer = game:GetService("StarterPlayer")
local RFirst = game:GetService("ReplicatedFirst")
local RStore = game:GetService("ReplicatedStorage")
local SStore = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")

local ROOTS = { workspace, RStore, RFirst, SStore, SSS, SGui, SPlayer, game:GetService("Lighting"), game:GetService("SoundService"), game:GetService("Players") }
local CAP = 15

local out = {
    scripts = 0, instances = 0, parts = 0, unanchored = 0, decals = 0, transparent = 0,
    badSyntax = {}, wontRun = {}, disabled = {}, dupNames = {}, attrHot = {},
}
local function push(t, v) if #t < CAP then table.insert(t, v) end end

-- does this script's container let it ever run?
local function runs(s)
    if s:IsA("ModuleScript") then return true end
    local rc = nil
    pcall(function() rc = s.RunContext end)
    if rc == Enum.RunContext.Server or rc == Enum.RunContext.Client then return true end
    if s:IsA("LocalScript") then
        return s:IsDescendantOf(SGui) or s:IsDescendantOf(SPlayer) or s:IsDescendantOf(RFirst)
    end
    return s:IsDescendantOf(SSS) or s:IsDescendantOf(workspace)
end

local function attrBytes(inst)
    local n = 0
    for k, v in pairs(inst:GetAttributes()) do
        local t = typeof(v)
        n += #k + (t == "string" and #v or t == "boolean" and 1 or t == "number" and 8 or 16)
    end
    return n
end

local seen, sibs = {}, {}
for _, root in ipairs(ROOTS) do
    for _, inst in ipairs(root:GetDescendants()) do
        if not seen[inst] then
            seen[inst] = true
            out.instances += 1

            if inst:IsA("LuaSourceContainer") then
                out.scripts += 1
                local f, err = loadstring("local __f = function(...)\n" .. inst.Source .. "\nend\nreturn true", inst.Name)
                if not f then push(out.badSyntax, inst:GetFullName() .. " :: " .. tostring(err)) end
                if not inst:IsA("ModuleScript") then
                    local off = false
                    pcall(function() off = inst.Disabled end)
                    if off then push(out.disabled, inst:GetFullName()) end
                    -- template stores hold scripts that are cloned elsewhere: not a defect
                    if not runs(inst) and not inst:IsDescendantOf(RStore) and not inst:IsDescendantOf(SStore) then
                        push(out.wontRun, inst:GetFullName() .. " :: " .. inst.ClassName)
                    end
                end
            elseif inst:IsA("BasePart") then
                out.parts += 1
                if not inst.Anchored then out.unanchored += 1 end
                if inst.Transparency > 0 then out.transparent += 1 end
            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                out.decals += 1
            end

            -- duplicate siblings only matter where FindFirstChild is used by name
            if inst:IsA("LuaSourceContainer") or inst:IsA("GuiObject") then
                local key = inst.Parent:GetFullName() .. "|" .. inst.Name
                if sibs[key] then push(out.dupNames, inst:GetFullName()) else sibs[key] = true end
            end

            if next(inst:GetAttributes()) then
                local b = attrBytes(inst)
                if b > 500 then push(out.attrHot, inst:GetFullName() .. " = " .. b .. "B") end
            end
        end
    end
end
return out
```

Reading the result:

- `badSyntax` — hard defect, fix before anything else.
- `wontRun` — a `LocalScript` on the server side or a legacy `Script` under a replicated
  container. It will never execute and will never error. Set `RunContext` or move it.
- `disabled` — `Disabled = true`. Silent no-run. Often left over from someone debugging.
- `dupNames` — two siblings share a name, so `FindFirstChild` picks one non-deterministically.
- `attrHot` — an ESTIMATE of attribute bytes, flagged over 500 of the 1024 budget. The engine's
  real serialized size differs, so treat a hit as "move this to a child `Configuration` before
  the cap silently eats a write", not as a measurement. The only exact test is write-then-read-back
  (Probe 9).
- `dupNames` keys on `Parent:GetFullName()`, not `tostring(Parent)`. Parent names repeat across a
  place, so the short form reports duplicates that do not exist.
- `decals` — each Decal/Texture is its own draw call. Hundreds of strays is a real frame cost.
- Roots are named on purpose. `game:GetDescendants()` drags in Studio's own `StylingService`,
  which carries multi-kilobyte attribute sets and floods every list here.

---

## Probe 1. Compile check only

Covered by the preflight, but standalone when you only changed scripts:

```lua
local bad, n = {}, 0
for _, s in ipairs(game:GetDescendants()) do
    if s:IsA("LuaSourceContainer") then
        n += 1
        local f, err = loadstring("local __f = function(...)\n" .. s.Source .. "\nend\nreturn true", s.Name)
        if not f then table.insert(bad, s:GetFullName() .. " :: " .. tostring(err)) end
    end
end
return { scanned = n, bad = bad }
```

Wrapping the source in a function body means nothing executes, so there are no side effects.
Hundreds of scripts in a few seconds.

## Probe 2. Real exports of a ModuleScript, without `require`

`require` is not exposed inside the `execute_luau` sandbox: it errors "attempt to call a nil
value". Execute the module body directly instead.

```lua
local function exportsOf(mod)
    local f, err = loadstring(mod.Source, mod.Name)
    if not f then return nil, err end
    setfenv(f, setmetatable({ script = mod, game = game }, { __index = getfenv() }))
    local ok, t = pcall(f)
    if not ok then return nil, t end
    return t
end

local M = exportsOf(game.ReplicatedStorage.Modules.Shop)
return { starterSword = typeof(M.starterSword), price = M.ballPrice("TrashBag") }
```

`script` is bound to the real instance, so `script:FindFirstChild(...)` resolves against the real
tree. **This is the probe that catches a function accidentally nested inside another one**, which
a plain syntax check passes happily.

## Probe 3. Fresh module state

`require` caches per ModuleScript INSTANCE in the Edit datamodel, so after you edit a module the
OLD source keeps running. Clone, require the clone, destroy it.

```lua
local clone = mod:Clone()
clone.Parent = mod.Parent
local fresh = require(clone)
clone:Destroy()
return fresh.someValue
```

## Probe 4. Attribute byte audit (the 1024 cap)

The preflight covers the world. Run it on the **Player** instance while a player exists too, since
the Player is where the cap actually bites.

```lua
local function attrBytes(inst)
    local n = 0
    for k, v in pairs(inst:GetAttributes()) do
        local t = typeof(v)
        n += #k + (t == "string" and #v or t == "boolean" and 1 or t == "number" and 8 or 16)
    end
    return n
end
local plr = game.Players:GetPlayers()[1]
return plr and { name = plr.Name, bytes = attrBytes(plr), attrs = plr:GetAttributes() } or "no player"
```

Past the cap, `SetAttribute` silently refuses. The symptom is that the LAST attribute written
vanishes while every earlier one is fine. A child `Configuration` gets its own 1024 bytes.

## Probe 5. Dead require scan

```lua
local function resolve(path)
    local node = game
    for part in string.gmatch(path, "[%w_]+") do
        if part ~= "game" and part ~= "GetService" then
            node = node:FindFirstChild(part)
            if not node then return nil end
        end
    end
    return node
end

local dead = {}
for _, s in ipairs(game:GetDescendants()) do
    if s:IsA("LuaSourceContainer") then
        for expr in string.gmatch(s.Source, "require%s*%(([^%)]+)%)") do
            if expr:find("%.") and not expr:find("script") and not resolve(expr) then
                table.insert(dead, s:GetFullName() .. " -> " .. expr)
            end
        end
    end
end
return dead
```

A folder of orphaned reference scripts with hundreds of dead requires is a real thing that ships.
Move it to ServerStorage, do not leave it replicating to every client.

## Probe 6. Live instance counters (perf smells)

```lua
return {
    sounds = #game:GetService("SoundService"):GetDescendants(),
    starterGui = #game:GetService("StarterGui"):GetDescendants(),
    biggestGui = (function()
        local worst, n = nil, 0
        for _, g in ipairs(game:GetService("StarterGui"):GetChildren()) do
            local c = #g:GetDescendants()
            if c > n then worst, n = g:GetFullName(), c end
        end
        return { worst, n }
    end)(),
}
```

Watch for a panel that builds its entire tree on the join frame; build per board or per tab on
first view instead. Also watch cloned Sounds on fixed `Debris:AddItem` timers: at a few per second
they pile into dozens of live Sounds and become a client killer. Destroy on `Ended` with a hard
cap, and keep the ambient pool separate from the UI voice pool so ambience cannot evict a
purchase sound.

## Probe 7. UI scale audit

```lua
local out = {}
for _, g in ipairs(game:GetService("StarterGui"):GetDescendants()) do
    if g:IsA("ScreenGui") then
        local root = g:FindFirstChildWhichIsA("GuiObject")
        local scale = root and root:FindFirstChildWhichIsA("UIScale")
        if not scale then
            table.insert(out, g:GetFullName() .. " :: no UIScale on root")
        elseif scale.Name ~= "Fit" then
            table.insert(out, g:GetFullName() .. " :: UIScale named " .. scale.Name)
        end
    end
end
return out
```

This is a list to EYEBALL, not a defect list. A place can run a different device solver (a Device
module plus a layout solver driving scale at runtime) and legitimately report every ScreenGui.
Confirm which scheme the place uses before calling anything broken.

## Probe 8. Anchor uniqueness before `multi_edit`

```lua
local src = game.ReplicatedStorage.Modules.Target.Source
local anchor = "return GameConfig"
local esc = anchor:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
local _, n = src:gsub(esc, "")
return n
```

`n ~= 1` means pick a longer anchor. `n == 0` means your anchor is wrong about the file.

## Probe 9. Post-write read-back

After any property or attribute write, read it back in a **separate** `execute_luau` call.
Same-call reads can show a value that reverts the moment the call ends.

## Probe 10. Container and class sanity

Covered by the preflight (`wontRun`, `disabled`). Run standalone after moving scripts around.

## Probe 11. Deprecated and hot-path API scan

```lua
local BAD = {
    ["wait%s*%("] = "wait() -> task.wait()",
    ["spawn%s*%("] = "spawn() -> task.spawn()",
    ["delay%s*%("] = "delay() -> task.delay()",
    [":remove%s*%("] = ":remove() -> :Destroy()",
    ["BodyVelocity"] = "BodyVelocity -> LinearVelocity",
    ["BodyPosition"] = "BodyPosition -> AlignPosition",
    ["BodyGyro"] = "BodyGyro -> AlignOrientation",
    ["FindPartOnRay"] = "legacy ray -> workspace:Raycast",
    ["while%s+true%s+do"] = "unbounded loop, confirm it yields",
}
local hits = {}
for _, s in ipairs(game:GetDescendants()) do
    if s:IsA("LuaSourceContainer") then
        for pat, msg in pairs(BAD) do
            if s.Source:find(pat) then table.insert(hits, s:GetFullName() .. " :: " .. msg) end
        end
    end
end
return hits
```

Report these, do not mass-fix them. A drive-by rewrite of every `wait()` in a place is exactly the
scope creep the hard rules ban. Fix only inside scripts this task already touches.

## Probe 12. Remote surface audit

Every RemoteEvent is attack surface. Before shipping a new one, know the whole set.

```lua
local remotes, handlers = {}, {}
for _, inst in ipairs(game:GetDescendants()) do
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
        table.insert(remotes, inst:GetFullName() .. " :: " .. inst.ClassName)
    elseif inst:IsA("LuaSourceContainer") then
        for name in string.gmatch(inst.Source, "OnServerEvent") do
            handlers[inst:GetFullName()] = (handlers[inst:GetFullName()] or 0) + 1
        end
        for name in string.gmatch(inst.Source, "OnServerInvoke") do
            handlers[inst:GetFullName()] = (handlers[inst:GetFullName()] or 0) + 1
        end
    end
end
return { remotes = remotes, serverHandlers = handlers }
```

For each new remote, answer three questions in the report: who validates, what a spammed call
costs, and whether the client can reach the reward without doing the work. Rate limit and cap the
payload on anything a client can call in a loop.

## Probe 13. Duplicate sibling names

Covered by the preflight. Duplicates make `FindFirstChild` non-deterministic, which reads as an
intermittent bug that only reproduces on some machines.

## Probe 14. Render budget

```lua
local n = { parts = 0, unanchored = 0, decals = 0, transparent = 0, meshes = 0, particles = 0, lights = 0, welds = 0 }
for _, i in ipairs(workspace:GetDescendants()) do
    if i:IsA("BasePart") then
        n.parts += 1
        if not i.Anchored then n.unanchored += 1 end
        if i.Transparency > 0 then n.transparent += 1 end
        if i:IsA("MeshPart") then n.meshes += 1 end
    elseif i:IsA("Decal") or i:IsA("Texture") then n.decals += 1
    elseif i:IsA("ParticleEmitter") then n.particles += 1
    elseif i:IsA("Light") then n.lights += 1
    elseif i:IsA("JointInstance") then n.welds += 1 end
end
n.streaming = workspace.StreamingEnabled
return n
```

A Decal and a Texture are each their own draw call, so a mesh carrying two strays doubles its
cost. Unanchored parts that never move are pure physics budget. When these numbers are ugly,
escalate to `skill(rbx-scene-analysis)` rather than guessing.

**Studio FPS lies.** The viewport is vsync-locked, so a place that reads 60 in Studio can be
anything in a real client. Judge with the profiler (`skill(rbx-perf-profiling)`), not the corner
counter.

## Probe 15. Visual verification

`screen_capture` is not optional for visual work. Two modes:

- No camera args: captures the current viewport. Good for UI, since ScreenGuis render in Edit.
- `camera_position` + `look_at_position`: temporarily flies the camera. Good for world geometry,
  and it does not disturb what the user is looking at afterwards.

Give each call a distinct `capture_id` (`ScreenCapture_1`, `_2`, ...) so before/after pairs stay
straight. For UI across device sizes, use `skill(rbx-device-simulator-lua)` and capture per form
factor rather than eyeballing one window.
