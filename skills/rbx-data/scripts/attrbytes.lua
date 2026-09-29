-- rbx-data/scripts/attrbytes.lua: estimated attribute bytes per instance (cap 1024, silent drop past it).
-- usage: $R lua attrbytes.lua            -> top 25 instances by estimated bytes under Players/Workspace/StarterGui/ReplicatedStorage
--        sed "s|__ROOT__|game.Players|" -> scope. Estimate: #key + (string #value | bool 1 | number 8 | other 16). Exact test = write, read back in a separate call.
local ROOT = "__ROOT__"
local roots = {}
if ROOT ~= "__ROOT__" then table.insert(roots, RBX.find(ROOT)) else
	for _, n in ipairs({ "Players", "Workspace", "StarterGui", "ReplicatedStorage", "ServerStorage" }) do table.insert(roots, game:GetService(n)) end
end
local rows = {}
local function est(inst)
	local b, n = 0, 0
	for k, v in pairs(inst:GetAttributes()) do
		n += 1
		local t = type(v)
		b += #k + (t == "string" and #v or t == "boolean" and 1 or t == "number" and 8 or 16)
	end
	return b, n
end
for _, r in ipairs(roots) do
	local b, n = est(r)
	if n > 0 then table.insert(rows, { r:GetFullName(), b, n }) end
	for _, d in ipairs(r:GetDescendants()) do
		local b2, n2 = est(d)
		if n2 > 0 then table.insert(rows, { d:GetFullName(), b2, n2 }) end
	end
end
table.sort(rows, function(a, b) return a[2] > b[2] end)
local out = {}
for i = 1, math.min(25, #rows) do
	local r = rows[i]
	table.insert(out, string.format("%s%5d B %3d attrs  %s", r[2] > 900 and "!" or r[2] > 500 and "~" or " ", r[2], r[3], r[1]))
end
return string.format("instances with attributes: %d  (! >900 B, ~ >500 B)\n", #rows) .. table.concat(out, "\n")
