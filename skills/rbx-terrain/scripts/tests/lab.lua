local LAB = {}
local TT = workspace.Terrain
LAB.Y, LAB.HALF, LAB.YLO, LAB.YHI = 100, 512, -64, 448
function LAB.site(k)
	return Vector3.new(-30000 + (k % 8) * 1500, LAB.Y, -30000 + (k // 8) * 1500)
end
local function quads(c)
	local out = {}
	for _, dx in ipairs({ -256, 256 }) do
		for _, dz in ipairs({ -256, 256 }) do
			out[#out + 1] = { cf = CFrame.new(c.X + dx, (LAB.YLO + LAB.YHI) / 2, c.Z + dz), size = Vector3.new(512, LAB.YHI - LAB.YLO, 512), r = Region3.new(Vector3.new(c.X + dx - 256, LAB.YLO, c.Z + dz - 256), Vector3.new(c.X + dx + 256, LAB.YHI, c.Z + dz + 256)) }
		end
	end
	return out
end
function LAB.solid(k)
	local n = 0
	for _, q in ipairs(quads(LAB.site(k))) do
		local m = TT:ReadVoxels(q.r, 4)
		for x = 1, #m do
			local mx = m[x]
			for y = 1, #mx do
				local my = mx[y]
				for z = 1, #my do if my[z] ~= Enum.Material.Air then n += 1 end end
			end
		end
		task.wait()
	end
	return n
end
function LAB.parts(k, margin)
	local c = LAB.site(k)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { TT }
	return #workspace:GetPartBoundsInBox(CFrame.new(c.X, 0, c.Z), Vector3.new(1024 + 2 * margin, 8000, 1024 + 2 * margin), op)
end
function LAB.prep(k, mat)
	local c = LAB.site(k)
	local s, p = LAB.solid(k), LAB.parts(k, 3000)
	assert(s == 0 and p == 0, string.format("site %d not empty: %d solid voxels, %d parts within 3000", k, s, p))
	TT:FillBlock(CFrame.new(c.X, 60, c.Z), Vector3.new(1024, 80, 1024), mat or Enum.Material.Grass)
	return c
end
function LAB.box(k, name, size)
	local c = LAB.site(k)
	return { center = Vector3.new(c.X, LAB.Y, c.Z), size = Vector3.new(size or 800, 80, size or 800), name = "lab_" .. name }
end
function LAB.erase(k)
	for _, q in ipairs(quads(LAB.site(k))) do
		TT:FillBlock(q.cf, q.size, Enum.Material.Air)
		task.wait()
	end
	local bf = game:GetService("ServerStorage"):FindFirstChild("TerrainBackups")
	local dropped = 0
	if bf then
		for _, ch in ipairs(bf:GetChildren()) do
			if ch.Name:sub(1, 4) == "lab_" then ch:Destroy() dropped += 1 end
		end
		if #bf:GetChildren() == 0 then bf:Destroy() end
	end
	local n = LAB.solid(k)
	return string.format("%s site %d erased: %d solid voxels left, %d lab backups dropped", n == 0 and "PASS" or "FAIL", k, n, dropped), n
end
function LAB.build(G, features, copt, maskOpts, after)
	K.read(G)
	K.mask(G, maskOpts or { buffer = 24, feather = 80 })
	G.pads = G.pads or {}
	local t0 = os.clock()
	K.compose(G, features, copt or {})
	if after then after(G) end
	local tc = os.clock() - t0
	K.record("rbx-terrain lab " .. G.name, function()
		K.log("columns rewritten: " .. K.write(G))
		for _, op in ipairs(G.ops or {}) do
			K.log(string.format("3d %s %s voxels %d", op.name, op.mode, K.voxels(op.bmin, op.bmax, op.mode, op.fn, op.opt)))
			task.wait()
		end
	end)
	K.log(string.format("timing compose %.2fs write+3d %.2fs", tc, os.clock() - t0 - tc))
	return G
end
