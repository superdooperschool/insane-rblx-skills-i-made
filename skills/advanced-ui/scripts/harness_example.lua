local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local KEEP = __KEEP__
local real = SG.Frames.RebirthSkillTree
local out, errs, sounds = {}, {}, {}
local logConn = LogService.MessageOut:Connect(function(msg, kind)
	if kind == Enum.MessageType.MessageError and (msg:find("TreeHarness") or msg:find("Harness")) then errs[#errs + 1] = msg:sub(1, 300) end
end)

for _, n in { "_TreeHarness", "_GalaxyHarness" } do
	local o = SG:FindFirstChild(n)
	if o then o:Destroy() end
end
local holder = Instance.new("ScreenGui")
holder.Name = "_TreeHarness"
holder.Enabled = false
local panel = real:Clone()
for _, d in panel:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
panel.Visible = false
panel:SetAttribute("open", false)
panel.Parent = holder
holder.Parent = SG
local galaxy = SG.SkillGalaxy:Clone()
galaxy.Name = "_GalaxyHarness"
galaxy.Enabled = false
galaxy.Parent = SG

local fp = Instance.new("Folder")
fp.Name = "FakePlayer"
local gemsV = Instance.new("NumberValue") gemsV.Name = "Gems" gemsV.Parent = fp
local coinsV = Instance.new("NumberValue") coinsV.Name = "Coins" coinsV.Parent = fp
local data = Instance.new("Folder") data.Name = "Data" data.Parent = fp
local gnodes = Instance.new("Folder") gnodes.Name = "GemNodes" gnodes.Parent = data
fp.Parent = holder

local function fresh(mod)
	local c = mod:Clone()
	c.Parent = holder
	return require(c)
end
local GT = fresh(RS.GemTree)

local stats = { invokes = 0, batches = 0, tooFast = 0, bought = 0 }
local lastT = 0
local function ownedSet()
	local o = {}
	for _, b in gnodes:GetChildren() do if b.Value then o[b.Name] = true end end
	return o
end
local function serverBuy(id)
	local node = GT.get(id)
	if not node then return false end
	local r = GT.blockedReason(id, ownedSet(), gemsV.Value, coinsV.Value)
	if r ~= nil then return false end
	if GT.currencyOf(node) == "coins" then coinsV.Value -= node.price or 0 else gemsV.Value -= node.price or 0 end
	local b = Instance.new("BoolValue") b.Name = id b.Value = true b.Parent = gnodes
	stats.bought += 1
	return true
end
local fakePurchase, fakeBatch = {}, {}
function fakePurchase:InvokeServer(id)
	stats.invokes += 1
	if os.clock() - lastT < 0.15 then stats.tooFast += 1 return { success = false, message = "too fast" } end
	lastT = os.clock()
	task.wait(0.08)
	return { success = serverBuy(id) }
end
function fakeBatch:InvokeServer(ids)
	stats.batches += 1
	task.wait(0.15)
	local bought = {}
	for _, id in ids do if serverBuy(id) then bought[#bought + 1] = id end end
	return { success = #bought > 0, bought = bought }
end
local fakeRemotes = { WaitForChild = function(_, n) return n == "PurchaseNode" and fakePurchase or fakeBatch end }
local fakeRS = setmetatable({}, { __index = function(_, k)
	if k == "WaitForChild" or k == "FindFirstChild" then
		return function(_, name, ...)
			if name == "RebirthSkillTreeRemotes" then return fakeRemotes end
			return RS[k](RS, name, ...)
		end
	end
	return RS[k]
end })
local pgProxy = { WaitForChild = function(_, n) return n == "SkillGalaxy" and galaxy or nil end, GetGuiObjectsAtPosition = function() return {} end, GetChildren = function() return {} end }
local fakePlayer = setmetatable({}, { __index = function(_, k)
	if k == "WaitForChild" or k == "FindFirstChild" then
		return function(_, name, ...)
			if name == "PlayerGui" then return pgProxy end
			return fp[k](fp, name, ...)
		end
	end
	if k == "PlayerGui" then return pgProxy end
	if k == "FindFirstChildOfClass" then return function() return nil end end
	return fp[k]
end })
local fakeGuiService = { TouchControlsEnabled = true, GetGuiInset = function() return Vector2.new(0, 0) end }
local realGame = game
local fakeGame = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, name)
			if name == "Players" then return { LocalPlayer = fakePlayer } end
			if name == "ReplicatedStorage" then return fakeRS end
			if name == "GuiService" then return fakeGuiService end
			return realGame:GetService(name)
		end
	end
	local v = realGame[k]
	if type(v) == "function" then return function(_, ...) return v(realGame, ...) end end
	return v
end })
local stubSound = {
	play = function(voice) sounds[voice] = (sounds[voice] or 0) + 1 end,
	playFor = function() end, shake = function() end,
	transient = function(snd) sounds["x:" .. snd.Name] = (sounds["x:" .. snd.Name] or 0) + 1 snd:Destroy() end,
}
local stubPanels = { close = function() panel:SetAttribute("open", false) end }
local soundMod, panelsMod = RS.Modules.GUIS.UISound, RS.Modules.GUIS.Panels
local mods = {}
for _, n in { "Layout", "Cam", "Fx", "Space" } do mods[n] = real.TreeUI[n] end
local fakeScript = { Parent = panel, WaitForChild = function(_, n) return mods[n] end }
local env = setmetatable({
	game = fakeGame,
	script = fakeScript,
	require = function(m)
		if m == soundMod then return stubSound end
		if m == panelsMod then return stubPanels end
		if m == RS.GemTree then return GT end
		for _, mm in mods do
			if m == mm then return fresh(m) end
		end
		return require(m)
	end,
}, { __index = getfenv() })

local tail = "\nreturn { S = S, tryBuy = tryBuy, buyAll = buyAll, exitBoard = exitBoard, boardData = boardData, cam = cam, planAll = planAll, hoverIn = hoverIn, hoverOut = hoverOut }"
local chunk, cerr = loadstring(real.TreeUI.Source .. tail, "=TreeHarness")
if not chunk then logConn:Disconnect() holder:Destroy() galaxy:Destroy() return { compile = cerr } end
setfenv(chunk, env)

local function owns(id)
	local b = gnodes:FindFirstChild(id)
	return b ~= nil and b.Value
end
local function waitFor(fn, limit)
	local t0 = os.clock()
	while not fn() and os.clock() - t0 < limit do task.wait(0.05) end
	return fn()
end

local ok, perr = pcall(function()
	local X = chunk()
	local S = X.S
	local function visible()
		local n = 0
		for _, v in S.views do if v.root.Visible then n += 1 end end
		return n
	end
	gemsV.Value = 5
	coinsV.Value = 0
	local bgSnd = Instance.new("Sound")
	bgSnd.Name = "HarnessBg"
	bgSnd.Parent = workspace
	_G.__harnessBg = bgSnd
	panel.Visible = true
	panel:SetAttribute("open", true)
	task.wait(0.4)
	out.a_hyperStreaks = #galaxy.Screen:GetChildren()
	out.a_entryShown = galaxy.Hud.Entry.Visible
	task.wait(3.2)
	out.a_enabled = galaxy.Enabled
	out.a_touchOff = fakeGuiService.TouchControlsEnabled == false
	out.a_views = #S.views
	out.a_visible = visible()
	out.a_coreState = S.byId.core and S.byId.core.state
	out.a_zoom = math.floor(X.cam.z * 100) / 100
	out.a_introDone = S.intro == false
	out.a_twinkles = #galaxy.Bg.Twinkles:GetChildren()
	out.a_wallet = galaxy.Hud.Wallet.Gems.TextLabel.Text
	out.a_noTitle = galaxy.Hud:FindFirstChild("Title") == nil
	out.a_buyAllCount = galaxy.Hud.BuyAll.Count.Num.Text .. " plan=" .. #X.planAll()
	out.a_space = X.S.space ~= nil and #X.S.space.rings > 0
	local r0 = X.S.space and X.S.space.rings[1].frame.Rotation
	task.wait(0.3)
	out.a_spaceSpins = X.S.space ~= nil and X.S.space.rings[1].frame.Rotation ~= r0
	X.hoverIn(S.byId.core)
	task.wait(0.3)
	out.a_tipShown = galaxy.Hud.Tip.Visible and galaxy.Hud.Tip.GroupTransparency < 0.1
	out.a_tipName = galaxy.Hud.Tip.Card.NodeName.Text
	out.a_hoverZ = S.byId.core.root.ZIndex
	out.a_hoverScale = math.floor(S.byId.core.root.Pop.Scale * 1000) / 1000
	out.a_hoverNoOverlap = S.byId.core.root.Pop.Scale * 0.955 < 1
	out.a_tipChip = galaxy.Hud.Tip.Card:FindFirstChild("Chip") ~= nil and galaxy.Hud.Tip.Card.Chip.Amount.Text
	X.hoverOut(S.byId.core)
	task.wait(0.7)
	out.a_tipHidden = galaxy.Hud.Tip.Visible == false
	out.a_zBack = S.byId.core.root.ZIndex
	out.a_openSfx = (sounds.open or 0) > 0
	local grp = bgSnd.SoundGroup
	local mfx = grp and grp:FindFirstChild("TreeMuffle")
	local ref = RS:FindFirstChild("Muffler")
	out.a_muffled = grp ~= nil and grp.Name == "TreeDuck" and mfx ~= nil and ref ~= nil and math.abs(mfx.MidGain - ref.MidGain) < 1 and grp.Volume < 0.7
	local late = Instance.new("Sound")
	late.Name = "HarnessLate"
	late.Parent = workspace
	task.wait(0.1)
	out.a_lateDucked = late.SoundGroup ~= nil and late.SoundGroup.Name == "TreeDuck"
	late:Destroy()
	local lib = game.SoundService.Sounds:FindFirstChild("Dopamine")
	local libHit = false
	for _, d in (lib and lib:GetDescendants() or {}) do
		if d.Name == "TreeMuffle" then libHit = true end
	end
	out.a_libUntouched = not libHit

	X.tryBuy(S.byId.core)
	waitFor(function() return owns("core") and not S.byId.core.busy end, 3)
	task.wait(0.8)
	out.b_coreOwned = owns("core")
	out.b_coreState = S.byId.core.state
	out.b_gold1State = S.byId.gold1 and S.byId.gold1.state
	out.b_impactSfx = (sounds.impact or 0) > 0
	out.b_visibleAfter = visible()

	local g0 = gemsV.Value
	X.tryBuy(S.byId.gold1)
	X.tryBuy(S.byId.grass1)
	X.tryBuy(S.byId.spd1)
	waitFor(function() return owns("gold1") and owns("grass1") and owns("spd1") end, 4)
	task.wait(1)
	out.c_threeOwned = owns("gold1") and owns("grass1") and owns("spd1")
	out.c_gemsSpent = g0 - gemsV.Value
	out.c_tooFast = stats.tooFast
	out.c_statesOwned = S.byId.gold1.state == "owned" and S.byId.grass1.state == "owned" and S.byId.spd1.state == "owned"
	out.c_predClear = next(S.pred) == nil
	out.c_wallet = galaxy.Hud.Wallet.Gems.TextLabel.Text

	gemsV.Value = 0
	local inv0 = stats.invokes
	local target
	for _, v in S.views do if v.state == "short" then target = v break end end
	out.d_shortFound = target ~= nil
	if target then X.tryBuy(target) end
	task.wait(0.3)
	out.d_noInvoke = stats.invokes == inv0
	out.d_deniedSfx = (sounds.denied or 0) > 0

	for _, id in { "gold2", "gold3" } do
		local b = Instance.new("BoolValue") b.Name = id b.Value = true b.Parent = gnodes
	end
	task.wait(0.4)
	local portal = S.byId.portal_gold
	out.e_portalState = portal and portal.state
	if portal then X.tryBuy(portal) end
	waitFor(function() return S.board == "gold" and not S.switching and not S.intro end, 5)
	out.e_board = S.board
	out.e_views = #S.views
	local fillC = S.byId.gold_core.root.Fill.UIGradient.Color.Keypoints[1].Value
	out.e_coreYellow = fillC.R > 0.9 and fillC.G > 0.8 and fillC.B < 0.5
	out.e_rootState = S.byId.gold_core and S.byId.gold_core.state
	X.tryBuy(S.byId.gold_core)
	waitFor(function() return owns("gold_core") and not S.byId.gold_core.busy end, 3)
	task.wait(0.6)
	out.e_coreSub = S.byId.gold_core.root.Sub.Text
	X.tryBuy(S.byId.gold_core)
	waitFor(function() return S.board == "rebirth" and not S.switching end, 3)
	out.f_backBoard = S.board
	out.f_portalVisible = S.byId.portal_gold and S.byId.portal_gold.root.Visible

	gemsV.Value = 60
	coinsV.Value = 20000
	local plan = X.planAll()
	out.g_planSize = #plan
	local spendG, spendC = 0, 0
	for _, id in plan do
		local n = GT.get(id)
		if GT.currencyOf(n) == "coins" then spendC += n.price else spendG += n.price end
	end
	out.g_planGems = spendG
	out.g_planCoins = spendC
	local b0 = stats.bought
	task.spawn(X.buyAll)
	task.wait(0.2)
	out.g_running = S.buyAll
	waitFor(function() return not S.buyAll end, 30)
	out.g_done = not S.buyAll
	out.g_batches = stats.batches
	out.g_bought = stats.bought - b0
	local allOwned = true
	for _, id in plan do if not owns(id) then allOwned = false end end
	out.g_allOwned = allOwned
	out.g_gemsLeft = gemsV.Value
	out.g_banner = galaxy.Hud.Banner.Text
	out.g_label = galaxy.Hud.BuyAll.Face.Label.Text
	out.g_bannerSub = galaxy.Hud.BannerSub.Text
	out.g_maxPopAfter = 0
	for _, id in plan do
		local v = S.byId[id]
		if v then out.g_maxPopAfter = math.max(out.g_maxPopAfter, math.floor(v.root.Pop.Scale * 1000) / 1000) end
	end
	task.wait(0.6)
	local allPainted = true
	for _, id in plan do
		local v = S.byId[id]
		if v and v.state ~= "owned" then allPainted = false end
	end
	out.g_allPainted = allPainted
	out.g_predClear = next(S.pred) == nil
	out.g_progress = "n/a"

	if not KEEP then
		panel:SetAttribute("open", false)
		task.wait(0.5)
		out.h_collapsing = galaxy.Enabled
		task.wait(1.1)
		out.h_closed = galaxy.Enabled == false
		out.h_viewsCleared = #S.views == 0
		out.h_touchBack = fakeGuiService.TouchControlsEnabled == true
		out.h_unmuffled = bgSnd.SoundGroup == nil
	end
end)
out.zz_ok = ok
out.zz_err = perr and tostring(perr):sub(1, 300)
out.zz_errs = table.concat(errs, " || ")
local sv = {}
for k, v in sounds do sv[#sv + 1] = k .. "=" .. v end
table.sort(sv)
out.zz_sounds = table.concat(sv, " ")
logConn:Disconnect()
if _G.__harnessBg then _G.__harnessBg:Destroy() _G.__harnessBg = nil end
if not KEEP then
	holder:Destroy()
	galaxy:Destroy()
end
local keys = {}
for k in out do keys[#keys + 1] = k end
table.sort(keys)
local lines = {}
for _, k in keys do lines[#lines + 1] = k .. " = " .. tostring(out[k]) end
return table.concat(lines, "\n")
