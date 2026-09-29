local c = LAB.site(17)
local BOX = LAB.box(17, "river", 900)
local CH = { { c.X - 450, c.X, c.Z - 450, c.Z }, { c.X, c.X + 450, c.Z - 450, c.Z }, { c.X - 450, c.X, c.Z, c.Z + 450 }, { c.X, c.X + 450, c.Z, c.Z + 450 } }
local M = K.MAT
local RIVER
local PTS = { { c.X - 380, c.Z - 120 }, { c.X - 120, c.Z - 60 }, { c.X + 120, c.Z + 40 }, { c.X + 380, c.Z + 90 } }
return K.run(BOX, { chunks = CH, buffer = 24, feather = 80, chunkMargin = 288 }, function(G)
	local river = K.path({ name = "river", mode = "lane", pts = PTS, halfW = 40, bank = 60, depth = 14, floorMat = M.Sand, calm = { 110, 200 } })
	K.water(G, "river water", river, { depth = 9 })
	RIVER = river
	return { K.rolling({ seed = 3 }), river }, {}
end, function(G)
	task.wait(1)
	local wet = RaycastParams.new()
	wet.FilterType = Enum.RaycastFilterType.Include
	wet.FilterDescendantsInstances = { workspace.Terrain }
	local dry = RaycastParams.new()
	dry.FilterType = Enum.RaycastFilterType.Include
	dry.FilterDescendantsInstances = { workspace.Terrain }
	dry.IgnoreWater = true
	local ref = K.path({ name = "probe", mode = "trough", pts = PTS, halfW = 1, bank = 4, depth = 0 })
	local dryN, badLevel, depthMin, n = 0, 0, 1e9, 0
	for k = 0, 40 do
		local t = k / 40
		local seg = math.min(3, math.floor(t * 3) + 1)
		local u = t * 3 - (seg - 1)
		local a, b = PTS[seg], PTS[seg + 1]
		local x, z = a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
		if math.abs(x - c.X) < 300 then
			n += 1
			local w = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), wet)
			local d = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), dry)
			if not w or w.Material ~= Enum.Material.Water then dryN += 1
			else
				local fy = RIVER and RIVER.floorAt and RIVER.floorAt(x, z)
				if fy and math.abs(w.Position.Y - 2 - (fy + 9)) > 2.5 then badLevel += 1 end
				if d then depthMin = math.min(depthMin, w.Position.Y - d.Position.Y) end
			end
		end
	end
	K.log(string.format("%s river water along the centre: %d/%d samples dry, %d off floor + 9 by > 2.5, min water depth %.1f (want 0 dry, 0 off, >= 6)", (dryN == 0 and badLevel == 0 and depthMin >= 6) and "PASS" or "FAIL", dryN, n, badLevel, depthMin))
	local spill = 0
	for x = -300, 300, 20 do
		for _, dz in ipairs({ -150, 150 }) do
			local w = workspace:Raycast(Vector3.new(c.X + x, 900, c.Z + dz + x * 0.25), Vector3.new(0, -1200, 0), wet)
			if w and w.Material == Enum.Material.Water then spill += 1 end
		end
	end
	K.log(string.format("%s no water outside the channel: %d of 62 bank-top samples wet (want 0)", spill == 0 and "PASS" or "FAIL", spill))
end)
