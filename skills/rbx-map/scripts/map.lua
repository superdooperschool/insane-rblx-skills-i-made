-- rbx-map/scripts/map.lua: index every script under one service as markdown. Run per service and concatenate.
-- usage: sed "s|__SERVICE__|ServerStorage|" map.lua | $R lua - --out map_ServerStorage.md
-- One line per script: path [class lines] header | fn: names | req: modules | net: channels | attr: names | remotes
local SERVICE = "__SERVICE__"
local root = game:GetService(SERVICE)
local out = {}
local function uniq(t) local s, r = {}, {} for _, v in ipairs(t) do if not s[v] then s[v] = true table.insert(r, v) end end return r end
local function strip(src)
	src = src:gsub("%-%-%[(=*)%[.-%]%1%]", "") -- block comments
	src = src:gsub("%-%-[^\n]*", "")            -- line comments
	return src
end
local function header(src)
	local b = src:match("^%s*%-%-%[%[(.-)%]%]")
	if b then return (b:gsub("%s+", " "):sub(1, 160)) end
	local lines = {}
	for l in src:gmatch("[^\n]+") do
		local c = l:match("^%s*%-%-%s*(.+)")
		if not c then break end
		table.insert(lines, c)
		if #lines >= 3 then break end
	end
	return (table.concat(lines, " "):sub(1, 160))
end
local function collect(src, pat)
	local r = {}
	for m in src:gmatch(pat) do table.insert(r, m) end
	return uniq(r)
end
local function fns(src)
	local r = {}
	for name in src:gmatch("\nfunction%s+([%w_%.:]+)%s*%(") do table.insert(r, name) end
	for name in src:gmatch("\nlocal%s+function%s+([%w_]+)%s*%(") do table.insert(r, name) end
	for name in src:gmatch("\n([%w_%.]+)%s*=%s*function%s*%(") do table.insert(r, name) end
	return r
end
local scripts = {}
for _, d in ipairs(root:GetDescendants()) do if d:IsA("LuaSourceContainer") then table.insert(scripts, d) end end
table.sort(scripts, function(a, b) return a:GetFullName() < b:GetFullName() end)
table.insert(out, string.format("## %s (%d scripts)\n", SERVICE, #scripts))
for _, s in ipairs(scripts) do
	local raw = s.Source
	local src = strip(raw)
	local _, lines = raw:gsub("\n", "")
	local parts = { string.format("- `%s` [%s %d]", s:GetFullName(), s.ClassName:sub(1, 1) == "L" and "Local" or s.ClassName:sub(1, 6), lines + 1) }
	local h = header(raw)
	if h ~= "" then table.insert(parts, h) end
	local f = fns(src)
	if #f > 0 then table.insert(parts, "fn: " .. table.concat(f, " ", 1, math.min(#f, 25)) .. (#f > 25 and (" +" .. (#f - 25)) or "")) end
	local req = collect(src, "require%(([^\n]-)%)")
	if #req > 0 then
		for i, r in ipairs(req) do req[i] = r:gsub('WaitForChild%("([^"]+)"%)', "%1"):gsub('%s', ''):gsub('game:GetService%("(%w+)"%)', "%1"):gsub("script%.Parent", "^"):sub(1, 60) end
		table.insert(parts, "req: " .. table.concat(req, " "))
	end
	local net = {}
	for kind, ch in src:gmatch('Net%.(%a+)%("([^"]+)"') do table.insert(net, kind:sub(1, 1) .. ":" .. ch) end
	net = uniq(net)
	if #net > 0 then table.insert(parts, "net: " .. table.concat(net, " ")) end
	local rem = {}
	for name in src:gmatch('([%w_]+)[%.:]Fire[SC]%w*%(') do table.insert(rem, "fire:" .. name) end
	for name in src:gmatch('([%w_]+)%.On[SC]%w*[Ee]vent') do table.insert(rem, "on:" .. name) end
	for name in src:gmatch('([%w_]+)%.OnServerInvoke') do table.insert(rem, "invoke:" .. name) end
	for name in src:gmatch('([%w_]+):InvokeServer') do table.insert(rem, "invoke:" .. name) end
	rem = uniq(rem)
	if #rem > 0 then table.insert(parts, "remotes: " .. table.concat(rem, " ")) end
	local attr = collect(src, '[GS]etAttribute%("([%w_]+)"')
	if #attr > 0 then table.insert(parts, "attr: " .. table.concat(attr, " ", 1, math.min(#attr, 20))) end
	local ds = collect(src, '(%u%w+Async)%(')
	if #ds > 0 then table.insert(parts, "async: " .. table.concat(ds, " ")) end
	table.insert(out, table.concat(parts, " | "))
end
return table.concat(out, "\n")
