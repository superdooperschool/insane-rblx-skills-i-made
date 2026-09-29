local c = LAB.site(9)
local BOX = LAB.box(9, "bridge", 900)
local CH = { { c.X - 450, c.X, c.Z - 450, c.Z }, { c.X, c.X + 450, c.Z - 450, c.Z }, { c.X - 450, c.X, c.Z, c.Z + 450 }, { c.X, c.X + 450, c.Z, c.Z + 450 } }
local M = K.MAT
local FLOOR, CLEAR = LAB.Y - 34, 50
local function stone(p) return math.noise(p.X / 18, p.Y / 18, p.Z / 18) > 0 and M.Rock or M.Basalt end
return K.run(BOX, { chunks = CH, buffer = 24, feather = 80 }, function(G)
	local gully = K.path({ name = "gully", mode = "dive", pts = { { c.X - 330, c.Z + 20 }, { c.X, c.Z }, { c.X + 330, c.Z - 20 } }, halfW = 40, bank = 200, base = LAB.Y, depth = 34, grade = 14, bankDeg = 22, endEase = 120, floorMat = M.Limestone })
	K.archBridge(G, "bridge", { a = { c.X + 10, c.Z - 190 }, b = { c.X - 10, c.Z + 190 }, ya = LAB.Y, yb = LAB.Y, width = 28, floor = FLOOR, clear = CLEAR, thick = 10, open = 70, top = M.Grass, body = stone })
	return { gully }, {}
end, function(G)
	task.wait(1)
	local clear, floorY = K.clearance(c.X, c.Z, FLOOR - 12, FLOOR + 90)
	K.log(string.format("%s bridge underpass clear %d at the centre, floor %s (want >= 48) [movement.md]", clear >= 48 and "PASS" or "FAIL", clear, tostring(floorY)))
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local prev, jump, steep, hs = nil, 0, 0, {}
	for z = -186, 186, 4 do
		local x = c.X + 10 - (z + 190) / 380 * 20
		local h = workspace:Raycast(Vector3.new(x, 900, c.Z + z), Vector3.new(0, -1200, 0), rp)
		local y = h and h.Position.Y or 0
		if prev then jump = math.max(jump, math.abs(y - prev)) end
		hs[#hs + 1] = y
		prev = y
	end
	for k = 1, #hs - 4 do steep = math.max(steep, math.deg(math.atan(math.abs(hs[k + 4] - hs[k]) / 16))) end
	K.log(string.format("%s bridge deck along its length: max 4-stud step %.2f (want <= 1.5), max 16-stud slope %.1f deg (want <= 25), crosses the chunk line at z=%d [user R7, chunk rule 4]", (jump <= 1.5 and steep <= 25) and "PASS" or "FAIL", jump, steep, c.Z))
end)
