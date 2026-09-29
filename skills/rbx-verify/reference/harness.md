# harness - running un-requirable modules in the Edit datamodel

Why: `DataService.start()` calls `game:BindToClose` (errors "can only be called on the server" in
Edit); `BazaarService` needs MemoryStore; `require` is cached per session and returns the pre-edit
module. All of these were solved with the same shape (2026-08-28 Bazaar, 2026-08-22 mutations).

## 1. Fresh require (any module)

```lua
local M = RBX.req("ReplicatedStorage.Ladder")   -- clone -> require -> destroy; never the cached table
```

## 2. Compile-only (no execution)

```lua
local ok, err = loadstring("local __f = function(...)\n" .. src .. "\nend\nreturn true")
```
`verify.lua` does this for every script.

## 3. Exports without require (catches a function nested inside another)

```lua
local f = loadstring(mod.Source, mod.Name)
setfenv(f, setmetatable({ script = mod, game = game }, { __index = getfenv() }))
local ok, exports = pcall(f)
```

## 4. Service harness (stubbed world)

```lua
local src = game.ServerScriptService.BazaarService.Source
src = src:gsub("return BazaarService%.start%(%)%s*$", "return { svc = BazaarService, recordTrade = recordTrade }")

local clock = 1700000000
local function deep(t) if type(t) ~= "table" then return t end local r = {} for k, v in pairs(t) do r[k] = deep(v) end return r end
local stores = {}
local function fakeStore(name)
	stores[name] = stores[name] or {}
	local d = stores[name]
	return {
		GetAsync = function(_, k) return deep(d[k]) end,
		SetAsync = function(_, k, v) d[k] = deep(v) end,
		UpdateAsync = function(_, k, fn) local nv = fn(deep(d[k])) if nv ~= nil then d[k] = deep(nv) end return deep(d[k]) end,
		GetRangeAsync = function(_, dir, n) local keys = {} for k in pairs(d) do table.insert(keys, k) end table.sort(keys) local r = {} for i = 1, math.min(n, #keys) do r[i] = { key = keys[i], value = deep(d[keys[i]]) } end return r end,
		RemoveAsync = function(_, k) d[k] = nil end,
	}
end
local fakeGame = setmetatable({
	GetService = function(_, n)
		if n == "DataStoreService" then return { GetDataStore = function(_, name) return fakeStore("ds:" .. name) end, GetOrderedDataStore = function(_, name) return fakeStore("ods:" .. name) end } end
		if n == "MemoryStoreService" then return { GetSortedMap = function(_, name) return fakeStore("ms:" .. name) end } end
		if n == "Players" then return { PlayerAdded = { Connect = function() end }, PlayerRemoving = { Connect = function() end }, GetPlayers = function() return {} end } end
		return game:GetService(n)
	end,
	BindToClose = function() end,
}, { __index = game })
local stubs = {
	DataService = { touch = function() end, addCoins = function() end, get = function(p) return p._prof end },
	Net = { handle = function() end, reply = function() end, broadcast = function() end },
}
local function fakeRequire(m)
	local name = typeof(m) == "Instance" and m.Name or tostring(m)
	if stubs[name] then return stubs[name] end
	return require(m)
end
local env = setmetatable({ game = fakeGame, require = fakeRequire, script = game.ServerScriptService.BazaarService,
	os = setmetatable({ time = function() return clock end, clock = os.clock }, { __index = os }) }, { __index = getfenv() })
local f = assert(loadstring(src, "harness"))
setfenv(f, env)
local H = f()

-- scenario
local alice = { Name = "Alice", UserId = 1, _prof = { Coins = 1000, Bazaar = {} } }
local r = {}
r.rest = H.svc.order(alice, "sell", "GreenGrass", 100, 50)
clock += 60
r.cross = H.svc.order({ Name = "Bob", UserId = 2, _prof = { Coins = 5000, Bazaar = {} } }, "buy", "GreenGrass", 40, 60)
return r
```

Rules: deep-copy on every store boundary; step `clock` explicitly across hour/day edges; run against
scratch keys only; never point the harness at a live store. A harness proves the math, not the
replication - say which.

## 5. GUI script harness (drive a panel script without Play)

Clone the panel into StarterGui (so AbsoluteSize is real), `loadstring` its source with `script =
{ Parent = clone }` and a `game` proxy whose `Players.LocalPlayer` is a fake; stub `Panels`, `Net`,
`UISound`, `NotificationSystem` through the `require` shim; override `task.spawn` to CAPTURE loop
bodies; then `clone:SetAttribute("open", true)` and pump each captured loop with a `task.wait` that
errors on its 4th call (exactly 3 iterations). Caught a use-before-declare nil-global crash across 6
call sites. Destroy the clone at the end.

## 6. Use-before-declare scanner

Per line `string.match` (not anchored `gmatch`), after stripping method calls
`code:gsub("[%w_]+%.([%w_]+)%s*%(", " ")` so `math.abs` is not read as a local `abs`.
