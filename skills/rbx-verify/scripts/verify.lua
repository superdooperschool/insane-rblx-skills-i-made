-- rbx-verify/scripts/verify.lua: static proof pass over the whole place, Edit datamodel, no side effects.
-- usage: $R lua verify.lua            (optionally sed "s|__SCOPE__|ServerStorage|" to scope compile to one service)
-- Returns a table of counts + first examples. Every count that should be 0 is prefixed "!".
local SCOPE = "__SCOPE__"
local roots = {}
if SCOPE ~= "__SCOPE__" and SCOPE ~= "" then table.insert(roots, game:GetService(SCOPE)) else
	for _, n in ipairs({ "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPlayer", "StarterPack", "Workspace" }) do table.insert(roots, game:GetService(n)) end
end
local HttpService = game:GetService("HttpService")
local R = { compiled = 0 }
local ex = {}
local function flag(k, path, detail)
	R[k] = (R[k] or 0) + 1
	ex[k] = ex[k] or {}
	if #ex[k] < 5 then table.insert(ex[k], path .. (detail and (" " .. detail) or "")) end
end
local function archived(p) return p:find("_Parked") or p:find("_Removed") or p:find("_Archive") or p:find("_Backup") end
local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end

local handled, fired, onClient, toClient = {}, {}, {}, {}
local scripts = {}
R.archived = 0
for _, root in ipairs(roots) do for _, d in ipairs(root:GetDescendants()) do if d:IsA("LuaSourceContainer") then if archived(d:GetFullName()) then R.archived += 1 else table.insert(scripts, d) end end end end

for _, s in ipairs(scripts) do
	local path = s:GetFullName()
	local raw = s.Source
	-- 1 compile
	local fn, err = loadstring(raw)
	if fn then R.compiled += 1 else flag("!syntax_error", path, (err or ""):sub(1, 80)) end
	local src = strip(raw)
	-- 2 net contract (channels registered through a variable, e.g. Net.handle(CH.order, ...), are invisible here: check by hand)
	for ch in src:gmatch('Net%.handle%("([^"]+)"') do handled[ch] = path end
	for ch in src:gmatch('Net%.fire%("([^"]+)"') do fired[ch] = path end
	for ch in src:gmatch('Net%.on%("([^"]+)"') do onClient[ch] = path end
	for ch in src:gmatch('Net%.reply%([^,]+,%s*"([^"]+)"') do toClient[ch] = path end
	for ch in src:gmatch('Net%.broadcast%("([^"]+)"') do toClient[ch] = path end
	-- 3 hygiene
	local _, prints = src:gsub("\n%s*print%(", "")
	if prints > 0 then flag("prints", path, tostring(prints)) end
	for name, val in src:gmatch("\nlocal%s+([%u_]+)%s*=%s*(true)") do
		if name:match("DEBUG") or name:match("FAKE") or name:match("AUTO") or name:match("TEST") or name:match("BYPASS") or name:match("SKIP") then flag("!debug_flag_true", path, name) end
	end
	if src:find("Enum%.Font%.") or src:find("Font%.new%(") then if not path:find("UIKit") and not path:find("UITheme") and not path:find("PlayerModule") then flag("font_literal_outside_kit", path) end end
	if src:find("%.Source%s*=") then flag("!source_assignment", path) end
	if s.ClassName == "LocalScript" and (src:find("SetAsync") or src:find("UpdateAsync") or src:find("GetAsync%(")) then flag("!datastore_on_client", path) end
	if s.ClassName == "Script" or (s:IsA("ModuleScript") and path:match("^ServerS")) then
		if src:find("LocalPlayer") then flag("!localplayer_on_server", path) end
	end
	if src:find("wait%(") and not src:find("task%.wait%(") then local _, n = src:gsub("[^%.%w]wait%(", "") if n > 0 then flag("legacy_wait", path, tostring(n)) end end
	if src:find("%f[%w_]spawn%(") then flag("legacy_spawn", path) end
	-- a and b or c with a boolean middle term
	for a, b in src:gmatch("([%w_%.]+)%s+and%s+(true)%s+or%s+") do flag("!and_or_boolean_middle", path, a) end
end
-- contract results
for ch, p in pairs(fired) do if not handled[ch] then flag("!client_fires_unhandled_channel", p, ch) end end
for ch, p in pairs(handled) do if not fired[ch] then flag("server_handles_never_fired", p, ch) end end
for ch, p in pairs(onClient) do if not toClient[ch] then flag("client_listens_never_sent", p, ch) end end
for ch, p in pairs(toClient) do if not onClient[ch] then flag("server_sends_never_listened", p, ch) end end
R.channels = 0
for _ in pairs(handled) do R.channels += 1 end
-- 4 attribute payload size (1024-byte cap per attribute value is silent-drop territory for strings)
for _, root in ipairs(roots) do
	for _, d in ipairs(root:GetDescendants()) do
		local attrs = d:GetAttributes()
		for k, v in pairs(attrs) do
			if type(v) == "string" and #v > 900 then flag("!attribute_near_1024_cap", d:GetFullName(), k .. "=" .. #v) end
		end
	end
end
-- 5 remote instances with no script reference
for _, d in ipairs(game:GetDescendants()) do
	if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
		local used = false
		for _, s in ipairs(scripts) do if s.Source:find(d.Name, 1, true) then used = true break end end
		if not used then flag("remote_unreferenced", d:GetFullName()) end
	end
end
local lines = { string.format("scripts=%d compiled=%d channels=%d archived_skipped=%d", #scripts, R.compiled, R.channels, R.archived) }
local keys = {} for k in pairs(R) do if k ~= "compiled" and k ~= "channels" and k ~= "archived" then table.insert(keys, k) end end
table.sort(keys)
for _, k in ipairs(keys) do table.insert(lines, string.format("%-34s %4d  %s", k, R[k], table.concat(ex[k] or {}, " | "):sub(1, 220))) end
return table.concat(lines, "\n")
