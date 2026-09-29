local BOX = { name = "my_area", center = Vector3.new(0, 100, 0), size = Vector3.new(960, 80, 960) }
local c = BOX.center
local CH = { { c.X - 480, c.X, c.Z - 480, c.Z }, { c.X, c.X + 480, c.Z - 480, c.Z }, { c.X - 480, c.X, c.Z, c.Z + 480 }, { c.X, c.X + 480, c.Z, c.Z + 480 } }
local M = K.MAT
local function P(t) local o = {} for _, p in ipairs(t) do o[#o + 1] = { c.X + p[1], c.Z + p[2] } end return o end
local BOWLS = { { -200, 180, 150, 23 }, { 220, -250, 110, 17 } }
local LANE = P({ { -360, -330 }, { -120, -250 }, { 100, -60 }, { 330, 60 } })
local WALLP = P({ { 60, 150 }, { 200, 230 }, { 330, 330 } })
return K.run(BOX, { chunks = CH, buffer = 24, feather = 80, chunkMargin = 288 }, function(G)
	local wall = K.path({ name = "wall", mode = "wall", pts = WALLP, halfW = 0, bank = 240, inner = 40, R = 24, ang = 74, h = 34, backDeg = 20, crestR = 12, taper = 120, outside = { c.X + 120, c.Z + 330 }, base = c.Y, face = M.LeafyGrass })
	local lane = K.path({ name = "lane", mode = "lane", tag = "lane", pts = LANE, halfW = 50, bank = 16, depth = 6, floorMat = K.DIRT })
	local pieces = { lane, wall }
	for k, b in ipairs(BOWLS) do pieces[#pieces + 1] = K.bowl({ name = "bowl " .. k, x = c.X + b[1], z = c.Z + b[2], r = b[3], depth = b[4], lip = 4, floorMat = M.Grass, rimMat = M.Limestone }) end
	local f = {
		K.rolling({ seed = 31 }),
		K.hillField({ rect = { c.X - 330, c.X + 330, c.Z - 330, c.Z + 330 }, seed = 5, skip = K.clearOf(pieces, 0.4), grid = 130 }),
	}
	for _, p in ipairs(pieces) do f[#f + 1] = p end
	return f, {}
end)
