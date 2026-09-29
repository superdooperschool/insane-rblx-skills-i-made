-- rbx-map/scripts/summary.lua: one-screen place summary for the top of MAP.md
local out = {}
local total, archived = 0, 0
local svc = { "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPlayer", "StarterPack", "Workspace" }
for _, n in ipairs(svc) do
	local s = game:GetService(n); local c = { Script = 0, LocalScript = 0, ModuleScript = 0 }; local inst = 0
	for _, d in ipairs(s:GetDescendants()) do
		inst += 1
		if d:IsA("LuaSourceContainer") then
			local p = d:GetFullName()
			if p:find("_Parked") or p:find("_Removed") or p:find("_Archive") or p:find("_Backup") then archived += 1 else c[d.ClassName] += 1 total += 1 end
		end
	end
	table.insert(out, string.format("- %-18s scripts S=%d L=%d M=%d, %d instances", n, c.Script, c.LocalScript, c.ModuleScript, inst))
end
table.insert(out, string.format("- live scripts %d, archived %d, placeId %d", total, archived, game.PlaceId))
local rem = {}
for _, d in ipairs(game:GetDescendants()) do if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then table.insert(rem, d.Name) end end
table.insert(out, "- remotes: " .. table.concat(rem, ", "))
local big = {}
for _, n in ipairs(svc) do for _, d in ipairs(game:GetService(n):GetDescendants()) do if d:IsA("LuaSourceContainer") and #d.Source > 20000 then local p = d:GetFullName() if not (p:find("_Parked") or p:find("_Removed")) then table.insert(big, string.format("%s %dk", p, #d.Source // 1000)) end end end end
table.insert(out, "- big scripts (>20k chars, outline before read): " .. table.concat(big, "; "))
local guis = {}
for _, g in ipairs(game.StarterGui:GetChildren()) do if g:IsA("ScreenGui") then table.insert(guis, g.Name .. "@" .. g.DisplayOrder) end end
table.insert(out, "- ScreenGuis (name@DisplayOrder): " .. table.concat(guis, " "))
local frames = {}
local f = game.StarterGui:FindFirstChild("Frames")
if f then for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then table.insert(frames, c.Name) end end end
table.insert(out, "- Frames panels: " .. table.concat(frames, " "))
return table.concat(out, "\n")
