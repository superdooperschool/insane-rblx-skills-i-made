-- rbx-release/scripts/release.lua: pre-publish audit, Edit datamodel, read-only. Every "!" line must be explained or fixed.
local L = game:GetService("Lighting")
local out = {}
local function say(f, ...) table.insert(out, string.format(f, ...)) end
local function archived(p) return p:find("_Parked") or p:find("_Removed") or p:find("_Archive") or p:find("_Backup") end
local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end

-- lighting / post effects
local okT, tech = pcall(function() return L.Technology.Name end)
say("GlobalShadows=%s (user wants false)  Technology=%s  Brightness=%g  ClockTime=%g", tostring(L.GlobalShadows), okT and tech or "?", L.Brightness, L.ClockTime)
for _, e in ipairs(L:GetChildren()) do
	if e:IsA("PostEffect") then
		local extra = ""
		if e:IsA("DepthOfFieldEffect") then extra = string.format(" far=%g near=%g dist=%g", e.FarIntensity, e.NearIntensity, e.FocusDistance) end
		if e:IsA("BlurEffect") then extra = string.format(" size=%g", e.Size) end
		local bad = e.Enabled and ((e:IsA("DepthOfFieldEffect") and (e.FarIntensity > 0 or e.NearIntensity > 0)) or (e:IsA("BlurEffect") and e.Size > 0))
		say("%sPostEffect %s Enabled=%s%s", bad and "! " or "  ", e.Name, tostring(e.Enabled), extra)
	end
end
-- scripts
local scripts = {}
for _, n in ipairs({ "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPlayer", "Workspace" }) do
	for _, d in ipairs(game:GetService(n):GetDescendants()) do if d:IsA("LuaSourceContainer") and not archived(d:GetFullName()) then table.insert(scripts, d) end end
end
local prints, flags, admin, disabled, testy, http = 0, {}, {}, {}, {}, {}
for _, s in ipairs(scripts) do
	local src = strip(s.Source)
	local p = s:GetFullName()
	local _, n = src:gsub("\n%s*print%(", "") prints += n
	for name in src:gmatch("\nlocal%s+([%u_]+)%s*=%s*true") do if name:match("DEBUG") or name:match("FAKE") or name:match("AUTO_OPEN") or name:match("TEST") or name:match("BYPASS") or name:match("GOD") or name:match("SKIP") then table.insert(flags, p .. ":" .. name) end end
	if src:find("%.Chatted") or src:find("TextChatService") and src:find("Command") or p:lower():find("admin") then table.insert(admin, p) end
	if (s.ClassName == "Script" or s.ClassName == "LocalScript") and s.Disabled then table.insert(disabled, p) end
	if p:lower():find("test") or p:lower():find("probe") or p:find("__") or p:lower():find("scratch") or p:lower():find("debug") then table.insert(testy, p) end
	if src:find("HttpService") and (src:find("GetAsync") or src:find("PostAsync") or src:find("RequestAsync")) then table.insert(http, p) end
end
say("scripts=%d  print() calls=%d %s", #scripts, prints, prints > 0 and "(strip)" or "")
say("%sdebug flags true: %d %s", #flags > 0 and "! " or "  ", #flags, table.concat(flags, " "):sub(1, 300))
say("  admin/chat-command scripts: %d %s", #admin, table.concat(admin, " "):sub(1, 300))
say("%sdisabled scripts: %d %s", #disabled > 0 and "! " or "  ", #disabled, table.concat(disabled, " "):sub(1, 300))
say("%stest/probe/debug-named instances: %d %s", #testy > 0 and "! " or "  ", #testy, table.concat(testy, " "):sub(1, 300))
say("  http calls: %d %s", #http, table.concat(http, " "):sub(1, 200))
-- gui
local hiddenGuis, dimFrames = {}, {}
for _, g in ipairs(game.StarterGui:GetChildren()) do if g:IsA("ScreenGui") and not g.Enabled then table.insert(hiddenGuis, g.Name) end end
for _, d in ipairs(game.StarterGui:GetDescendants()) do if d:IsA("Frame") and d.Visible and d.Size.X.Scale >= 1 and d.Size.Y.Scale >= 1 and d.BackgroundTransparency < 0.9 and d.Parent:IsA("ScreenGui") and d.Parent.Enabled then table.insert(dimFrames, d:GetFullName()) end end
say("  ScreenGuis disabled: %s", table.concat(hiddenGuis, ", "))
say("%sfull-screen opaque frames visible on spawn: %d %s", #dimFrames > 0 and "! " or "  ", #dimFrames, table.concat(dimFrames, " "):sub(1, 200))
-- world
local unanchored, tools, badMesh = 0, 0, 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and not d.Anchored and not d:FindFirstAncestorOfClass("Model") then unanchored += 1 end
	if d:IsA("MeshPart") then local ok, v = pcall(function() return d.CollisionFidelity end) if ok and v == Enum.CollisionFidelity.PreciseConvexDecomposition then badMesh += 1 end end
end
for _, d in ipairs(game.StarterPack:GetChildren()) do if d:IsA("Tool") then tools += 1 end end
say("%sloose unanchored parts (no model): %d", unanchored > 0 and "! " or "  ", unanchored)
say("  MeshParts with PreciseConvexDecomposition: %d", badMesh)
say("  StarterPack tools: %d", tools)
-- sound
local loud = {}
for _, d in ipairs(game:GetDescendants()) do if d:IsA("Sound") and d.Volume > 3 then table.insert(loud, d.Name .. "=" .. d.Volume) end end
say("%ssounds with Volume>3: %d %s", #loud > 0 and "! " or "  ", #loud, table.concat(loud, " "):sub(1, 150))
-- settings
local ok, workspaceProps = pcall(function() return string.format("StreamingEnabled=%s  Gravity=%g", tostring(workspace.StreamingEnabled), workspace.Gravity) end)
say("  %s", ok and workspaceProps or "")
say("  Players.RespawnTime=%g  CharacterAutoLoads=%s", game.Players.RespawnTime, tostring(game.Players.CharacterAutoLoads))
return table.concat(out, "\n")
