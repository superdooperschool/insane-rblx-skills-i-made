local SITE = 13
local c = LAB.prep(SITE)
workspace.Terrain:FillBlock(CFrame.new(c.X, 125, c.Z + 120 + 196), Vector3.new(1024, 130, 392), Enum.Material.Grass)
local G = K.grid(LAB.box(SITE, "caves", 900))
local M = K.MAT
local B, FZ, CH, CLEAR = LAB.Y, 120, 90, 50
local function P(t) local o = {} for _, p in ipairs(t) do o[#o + 1] = { c.X + p[1], c.Z + p[2] } end return o end
local cliff = K.cliff({ name = "cliff", pts = P({ { -440, FZ }, { 0, FZ }, { 440, FZ } }), outside = { c.X, c.Z + 330 }, h = CH, w = 50, rel = 8, base = B, reach = 300 })
local LINK = P({ { -250, FZ - 10 }, { -250, FZ + 90 }, { -170, FZ + 190 }, { -40, FZ + 220 }, { 90, FZ + 190 }, { 150, FZ + 90 }, { 150, FZ - 10 } })
local RAV = P({ { -340, -180 }, { -150, -190 }, { 0, -180 }, { 150, -170 }, { 340, -180 } })
local ravine = K.path({ name = "ravine", mode = "dive", tag = "lane", pts = RAV, halfW = 36, bank = 180, base = B, grade = 12, bankDeg = 22, notchDeg = 42, coverFade = 40, floorMat = M.Limestone,
	floor = function(s, L) return B - 26 * math.sin(math.pi * s / L) ^ 2 end, covers = { { fFrom = 0.36, fTo = 0.62 } } })
LAB.build(G, {
	cliff,
	K.mound({ name = "ravine host", x = c.X - 20, z = c.Z - 170, r = 190, h = 42 }),
	ravine,
}, {}, { buffer = 24, feather = 80, maxSlope = 91 }, function(G)
	K.slot(G, "link", LINK, { halfW = 30, arch = true, yMin = B - 60, yMax = B + 200, prof = function(s, L, g)
		local yf = B - 40 * (0.5 - 0.5 * math.cos(2 * math.pi * s / L))
		if g >= yf + CLEAR + 8 then return yf, yf + CLEAR, K.lining end
		return yf, g + 60, K.lining
	end })
	K.slot(G, "ravine bore", RAV, { halfW = 30, arch = true, yMin = B - 60, yMax = B + 120, prof = function(s, L, g, x, z)
		local yf = ravine.floorAt(x, z) or g
		if g >= yf + CLEAR + 8 then return yf, yf + CLEAR, M.Limestone end
		return yf, g + 60, M.Limestone
	end })
end)
task.wait(1)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function top(x, z) local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), rp) return h and h.Position.Y - 2 or 0 end
local rows, minClear, minRoof, floors = {}, 1e9, 1e9, {}
for _, p in ipairs({ { -250, FZ + 60 }, { -200, FZ + 160 }, { -40, FZ + 220 }, { 120, FZ + 150 }, { 150, FZ + 60 } }) do
	local x, z = c.X + p[1], c.Z + p[2]
	local cl, fy = K.clearance(x, z, B - 60, B + 120)
	local roof = top(x, z) - ((fy or 0) + cl)
	minClear, minRoof = math.min(minClear, cl), math.min(minRoof, roof)
	floors[#floors + 1] = fy or 0
	rows[#rows + 1] = string.format("(%d,%d) clear %d floor %s roof %.0f", p[1], p[2], cl, tostring(fy), roof)
end
K.log(string.format("%s cave link clear >= 48 at 5 points (min %d) [movement.md]; %s", minClear >= 48 and "PASS" or "FAIL", minClear, table.concat(rows, "; ")))
K.log(string.format("%s cave link roof >= 8 (min %.0f) [SKILL rule]", minRoof >= 8 and "PASS" or "FAIL", minRoof))
local dip = math.max(floors[1], floors[5]) - floors[3]
K.log(string.format("%s cave link dips %.0f studs below its portals (want >= 30) [user R13 caves join through deep underground dips]", dip >= 30 and "PASS" or "FAIL", dip))
local rc, rfy = K.clearance(c.X - 20, c.Z - 180, B - 50, B + 110)
local rroof = top(c.X - 20, c.Z - 180) - ((rfy or 0) + rc)
K.log(string.format("%s ravine dives under the hill: clear %d (want >= 48), roof %.0f (want >= 8) [user R13 ravine under a hill]", (rc >= 48 and rroof >= 8) and "PASS" or "FAIL", rc, rroof))
return table.concat(K.out, "\n")
