local SITE = 8
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "bore", 900))
local M = K.MAT
local B = LAB.Y
local PTS = { { c.X - 330, c.Z }, { c.X - 150, c.Z + 10 }, { c.X, c.Z }, { c.X + 150, c.Z - 10 }, { c.X + 330, c.Z } }
local CLEAR, HALF = 50, 30
local route = K.path({ name = "route", mode = "dive", tag = "lane", pts = PTS, halfW = 40, bank = 200, base = B, depth = 4, grade = 14, bankDeg = 22, endEase = 120, coverFade = 60, floorMat = M.Limestone, covers = { { c.X, c.Z, len = 170 } }, dips = { { c.X, c.Z, depth = 14, flat = 200 } }, portalKeep = VARIANT == "keep" })
LAB.build(G, { K.mound({ name = "host", x = c.X, z = c.Z, r = 260, h = 56 }), route }, {}, { buffer = 24, feather = 80 }, function(G)
	K.slot(G, "bore", PTS, { halfW = HALF, arch = true, yMin = B - 40, yMax = B + 120, prof = function(s, L, g, x, z)
		local yf = route.floorAt(x, z) or g
		if g >= yf + CLEAR + 8 then return yf, yf + CLEAR, M.Limestone end
		return yf, g + 60, M.Limestone
	end })
end)
task.wait(1)
local yf = route.floorAt(c.X, c.Z)
local clear, floorY = K.clearance(c.X, c.Z, yf - 12, yf + 110)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local topHit = workspace:Raycast(Vector3.new(c.X, 900, c.Z), Vector3.new(0, -1200, 0), rp)
local roof = topHit and (topHit.Position.Y - 2) - ((floorY or 0) + clear) or -1
K.log(string.format("%s bore clear %d studs at the centre (want >= 48) [movement.md ball collider ~25 + user lab rule]", clear >= 48 and "PASS" or "FAIL", clear))
K.log(string.format("%s bore roof %.1f studs of ground over the bore (want >= 8) [SKILL rule]", roof >= 8 and "PASS" or "FAIL", roof))
local function width(y, x)
	local a = workspace:Raycast(Vector3.new(x, y, c.Z), Vector3.new(0, 0, 80), rp)
	local b = workspace:Raycast(Vector3.new(x, y, c.Z), Vector3.new(0, 0, -80), rp)
	return (a and (a.Position.Z - c.Z) or 80) + (b and (c.Z - b.Position.Z) or 80)
end
local bad, rows = 0, {}
for _, dy in ipairs({ 6, 14, 20, 30, 38, 44 }) do
	local y = yf + dy
	local ys = yf + CLEAR - HALF
	local want = y <= ys and 2 * HALF or 2 * math.sqrt(math.max(0, HALF * HALF - (y - ys) ^ 2))
	local w = (width(y, c.X - 40) + width(y, c.X + 40)) / 2
	if math.abs(w - want) > 8 then bad += 1 end
	rows[#rows + 1] = string.format("%d:%.0f/%.0f", dy, w, want)
end
K.log(string.format("%s bore arch profile (height:measured/true-arch width) %s, %d off by > 8 [user R7: true arches]", bad == 0 and "PASS" or "FAIL", table.concat(rows, " "), bad))
local mats, occs = workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(c.X - 60, yf - 4, c.Z - 44), Vector3.new(c.X + 60, yf + CLEAR + 12, c.Z + 44)):ExpandToGrid(4), 4)
local cnt, tot = {}, 0
for x = 1, #mats do
	for y = 2, #mats[x] - 1 do
		for z = 2, #mats[x][y] - 1 do
			local m = mats[x][y][z]
			if m ~= Enum.Material.Air and (mats[x][y][z - 1] == Enum.Material.Air or mats[x][y][z + 1] == Enum.Material.Air or mats[x][y - 1][z] == Enum.Material.Air) and y > 2 then
				cnt[m.Name] = (cnt[m.Name] or 0) + 1
				tot += 1
			end
		end
	end
end
local parts, ok = {}, (cnt.Rock or 0) / math.max(tot, 1) >= 0.1 and (cnt.Mud or 0) / math.max(tot, 1) >= 0.1 and (cnt.Ground or 0) / math.max(tot, 1) >= 0.1
for k, v in pairs(cnt) do parts[#parts + 1] = string.format("%s %.0f%%", k, v / tot * 100) end
table.sort(parts)
K.log(string.format("%s bore lining mix (wall/roof voxels next to air): %s; want Rock, Mud, Ground each >= 10%% [user R7]", ok and "PASS" or "FAIL", table.concat(parts, ", ")))
local function top(x, z) local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), rp) return h and h.Position.Y - 2 or 0 end
local wallMax, mouthAt, trench = 0, nil, 0
for x = -330, 0, 4 do
	local open = workspace:Raycast(Vector3.new(c.X + x, 900, c.Z), Vector3.new(0, -1200, 0), rp)
	local fy = route.floorAt(c.X + x, c.Z) or yf
	if open and math.abs((open.Position.Y - 2) - fy) < 3 then
		local w = math.max(top(c.X + x, c.Z + 34) - fy, top(c.X + x, c.Z - 34) - fy)
		wallMax = math.max(wallMax, w)
		if w > 8 then trench += 4 end
	elseif not mouthAt then
		mouthAt = x
	end
end
K.log(string.format("INFO portal approach: open trench %d studs long with side walls > 8 (max %.1f) before the roof starts at x=%s", trench, wallMax, tostring(mouthAt)))
return table.concat(K.out, "\n")
