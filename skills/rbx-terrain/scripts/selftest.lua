-- rbx-terrain selftest: builds a mound, a lane, a bored hill and an SDF skull-sized blob at a scratch spot
-- far off-map, reads everything back against the spec, then erases the spot. Touches nothing else.
local C = Vector3.new(20000, 100, 20000)
local T = workspace.Terrain
local SCR = Region3.new(C - Vector3.new(240, 60, 240), C + Vector3.new(240, 120, 240)):ExpandToGrid(4)
local function solidCount()
	local n = 0
	local m, o = T:ReadVoxels(SCR, 4)
	for x = 1, #m do for y = 1, #m[x] do for z = 1, #m[x][y] do if m[x][y][z] ~= Enum.Material.Air then n += 1 end end end end
	return n
end
assert(solidCount() == 0, "scratch spot not empty, aborting")
local t0 = os.clock()
local ok, err = pcall(function()
	T:FillBlock(CFrame.new(C.X, C.Y - 10, C.Z), Vector3.new(400, 20, 400), K.MAT.Grass)
	local G = K.grid({ center = Vector3.new(C.X, C.Y, C.Z), size = Vector3.new(400, 40, 400), name = "selftest" }, 60)
	K.backup(G, true)
	K.read(G)
	K.mask(G, { buffer = 12, feather = 12 })
	G.pads = {}
	local feats = {
		K.mound({ name = "moundA", x = C.X - 110, z = C.Z - 100, r = 45, h = 12, crest = K.MAT.Limestone, flank = K.MAT.LeafyGrass }),
		K.mound({ name = "hillB", x = C.X + 60, z = C.Z - 60, r = 95, h = 30, crest = K.MAT.Limestone, flank = K.MAT.LeafyGrass }),
		K.path({ name = "lane", mode = "lane", tag = "lane", pts = { { C.X - 170, C.Z + 110 }, { C.X, C.Z + 130 }, { C.X + 170, C.Z + 110 } }, halfW = 24, bank = 16, depth = 6, floorMat = K.DIRT, lipMat = K.MAT.Limestone }),
	}
	K.compose(G, feats, { noSmooth = true })
	local floorY = C.Y
	K.op3d(G, "bore", Vector3.new(C.X - 60, floorY - 4, C.Z - 60 - 26), Vector3.new(C.X + 180, floorY + 44, C.Z - 60 + 26), "cut",
		function(p) return K.sd.roundBox(p, Vector3.new(C.X + 60, floorY + 18, C.Z - 60), Vector3.new(130, 18, 18), 8) end,
		{ floor = { y = floorY, mat = K.MAT.Mud }, wall = K.MAT.Basalt })
	K.record("rbx-terrain selftest", function()
		K.write(G)
		for _, op in ipairs(G.ops) do K.voxels(op.bmin, op.bmax, op.mode, op.fn, op.opt) end
	end)
	G.skip3d = {}
	for gx = 1, G.NX do for gz = 1, G.NZ do
		local x, z = K.cellXZ(G, gx, gz)
		if x > C.X - 64 and x < C.X + 184 and math.abs(z - (C.Z - 60)) < 30 then G.skip3d[K.ix(G, gx, gz)] = true end
	end end
	local R = K.check(G)
	-- round trip: planned vs read-back height
	local worst = 0
	for i, hf in pairs(G.Hf) do if not G.skip3d[i] and R.H[i] then worst = math.max(worst, math.abs(R.H[i] - hf)) end end
	K.log(string.format("%s height round-trip worst %.3f stud", worst < 0.35 and "PASS" or "FAIL", worst))
	-- mound A slope: predicted atan(h*pi/(2r))
	local S = K.slope(G, R.H)
	local maxA = 0
	for gx = 1, G.NX do for gz = 1, G.NZ do
		local x, z = K.cellXZ(G, gx, gz)
		if (x - (C.X - 110)) ^ 2 + (z - (C.Z - 100)) ^ 2 < 45 ^ 2 then maxA = math.max(maxA, S[K.ix(G, gx, gz)] or 0) end
	end end
	local want = math.deg(math.atan(12 * math.pi / 90))
	K.log(string.format("%s mound slope max %.1f deg vs designed %.1f", math.abs(maxA - want) < 3 and "PASS" or "FAIL", maxA, want))
	local clear = K.clearance(C.X + 60, C.Z - 60, floorY - 12, floorY + 80)
	K.log(string.format("%s bore clear height %d (want >= 32)", clear >= 32 and "PASS" or "FAIL", clear))
	K.restore(G)
	local diff, total = K.compareBaseline(G)
	K.log(string.format("%s restore: %d/%d tiles differ from baseline", #diff == 0 and "PASS" or "FAIL", #diff, total))
end)
local bf = game.ServerStorage:FindFirstChild("TerrainBackups")
if bf and bf:FindFirstChild("selftest") then bf.selftest:Destroy() end
if bf and #bf:GetChildren() == 0 then bf:Destroy() end
T:FillBlock(CFrame.new(C.X, C.Y + 30, C.Z), Vector3.new(480, 180, 480), Enum.Material.Air)
local left = solidCount()
K.log(string.format("%s scratch erased (%d solid voxels left)  %.1fs", left == 0 and "PASS" or "FAIL", left, os.clock() - t0))
if not ok then K.log("ERROR " .. tostring(err)) end
return table.concat(K.out, "\n")
