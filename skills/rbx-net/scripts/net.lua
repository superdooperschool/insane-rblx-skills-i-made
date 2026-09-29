-- rbx-net/scripts/net.lua: every client->server entry point, who fires it, who handles it, and whether the
-- handler shows validation / rate-limit / ownership checks. Heuristic (string presence in the handler body),
-- so a row with all "-" is a lead to test by hand, not a verdict. Read-only.
local function archived(p) return p:find("_Parked") or p:find("_Removed") or p:find("_Archive") or p:find("_Backup") end
local scripts = {}
for _, n in ipairs({ "ServerScriptService", "ServerStorage", "ReplicatedStorage", "StarterGui", "StarterPlayer", "Workspace" }) do
	for _, d in ipairs(game:GetService(n):GetDescendants()) do if d:IsA("LuaSourceContainer") and not archived(d:GetFullName()) then table.insert(scripts, d) end end
end
local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end
local function short(p) return (p:gsub("^ServerScriptService%.", "SSS."):gsub("^ServerStorage%.", "SS."):gsub("^ReplicatedStorage%.", "RS."):gsub("^StarterPlayer%.StarterPlayerScripts%.", "SPS."):gsub("^StarterGui%.", "SG.")) end
-- handler body: from the handle/OnServerEvent line to the matching "end)" is hard; take 40 lines after the match.
local function bodyAfter(src, pat)
	local i = src:find(pat)
	if not i then return "" end
	local j = i
	for _ = 1, 40 do local nl = src:find("\n", j + 1) if not nl then break end j = nl end
	return src:sub(i, j)
end
local function marks(body)
	local m = {}
	m.typ = (body:find("typeof%(") or body:find("type%(") or body:find("tonumber%(") or body:find("math%.clamp") or body:find("math%.floor")) and "type" or "-"
	m.rate = (body:find("tick%(") or body:find("os%.clock") or body:find("cooldown") or body:find("Cooldown") or body:find("lastFire") or body:find("last%[") or body:find("RateLimit") or body:find("debounce")) and "rate" or "-"
	m.own = (body:find("User") or body:find("UserId") or body:find("player%.") or body:find("plr%.")) and "user" or "-"
	m.dist = (body:find("Magnitude") or body:find("Distance") or body:find("magnitude")) and "dist" or "-"
	m.reply = (body:find("Net%.reply") or body:find("FireClient")) and "reply" or "-"
	return m.typ .. " " .. m.rate .. " " .. m.own .. " " .. m.dist .. " " .. m.reply
end
local rows = {}
-- Net channels
local handled, firedBy = {}, {}
for _, s in ipairs(scripts) do
	local src = strip(s.Source)
	for ch in src:gmatch('Net%.handle%("([^"]+)"') do handled[ch] = { path = s:GetFullName(), body = bodyAfter(src, 'Net%.handle%("' .. ch:gsub("%p", "%%%0") .. '"') } end
	for ch in src:gmatch('Net%.fire%("([^"]+)"') do firedBy[ch] = firedBy[ch] or {} table.insert(firedBy[ch], short(s:GetFullName())) end
end
for ch, h in pairs(handled) do
	table.insert(rows, string.format("net:%-14s %-38s <- %-40s %s", ch, short(h.path), table.concat(firedBy[ch] or { "(nobody)" }, ","):sub(1, 40), marks(h.body)))
end
for ch, f in pairs(firedBy) do if not handled[ch] then table.insert(rows, string.format("net:%-14s %-38s <- %-40s NO HANDLER", ch, "(none)", table.concat(f, ","):sub(1, 40))) end end
-- raw remotes
for _, d in ipairs(game:GetDescendants()) do
	if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
		local handlers, firers = {}, {}
		local body = ""
		for _, s in ipairs(scripts) do
			local src = strip(s.Source)
			if src:find(d.Name, 1, true) then
				if (src:find("OnServerEvent") or src:find("OnServerInvoke")) and not s:IsA("LocalScript") then table.insert(handlers, short(s:GetFullName())) local at = src:find("OnServer") body = body .. (at and src:sub(at, at + 1500) or "") end
				if (src:find(":FireServer%(") or src:find(":InvokeServer%(")) and (s:IsA("LocalScript") or s:GetFullName():find("Starter") or s:GetFullName():find("^ReplicatedStorage")) then table.insert(firers, short(s:GetFullName())) end
			end
		end
		table.insert(rows, string.format("%-18s %-38s <- %-40s %s", d.Name .. ":" .. d.ClassName:sub(1, 1), table.concat(handlers, ","):sub(1, 38) ~= "" and table.concat(handlers, ","):sub(1, 38) or "(no handler found)", table.concat(firers, ","):sub(1, 40), marks(body)))
	end
end
table.sort(rows)
return string.format("%-18s %-38s <- %-40s type rate user dist reply\n", "ENTRY", "HANDLER", "FIRED BY") .. table.concat(rows, "\n")
