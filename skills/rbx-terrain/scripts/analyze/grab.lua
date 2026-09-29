local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
rp.IgnoreWater = false
local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local codes = { Grass = "G", LeafyGrass = "L", Limestone = "S", Basalt = "B", Rock = "R", Water = "W", Pavement = "P", Mud = "M", Ground = "D", Sand = "A", Sandstone = "N", Cobblestone = "C", Slate = "T", Salt = "X", Asphalt = "Y", Concrete = "Z", Snow = "O", Glacier = "I", Ice = "E", Brick = "K", WoodPlanks = "H", SmoothPlastic = "Q", CrackedLava = "V" }
local function ch(n) return A:sub(n + 1, n + 1) end
local down, under = Vector3.new(0, -8200, 0), Vector3.new(0, -254, 0)
local buf = {}
for r = ROW_A, ROW_B do
	local z = Z0 + r * STEP
	local t = table.create(NX)
	for c = 0, NX - 1 do
		local hit = workspace:Raycast(Vector3.new(X0 + c * STEP, 4000, z), down, rp)
		if hit then
			local q = math.clamp(math.floor((hit.Position.Y + 2048) * 16 + 0.5), 0, 262143)
			local gap = 0
			if hit.Material ~= Enum.Material.Water then
				local h2 = workspace:Raycast(hit.Position - Vector3.new(0, 1, 0), under, rp)
				if h2 then gap = math.clamp(math.floor((hit.Position.Y - h2.Position.Y) / 2), 0, 63) end
			end
			t[c + 1] = ch(q // 4096) .. ch(q // 64 % 64) .. ch(q % 64) .. (codes[hit.Material.Name] or "?") .. ch(gap)
		else
			t[c + 1] = "AAA_A"
		end
	end
	buf[#buf + 1] = "|" .. table.concat(t)
end
return table.concat(buf, "\n")
