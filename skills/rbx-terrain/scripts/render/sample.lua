
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local codes = { Grass = "G", LeafyGrass = "L", Limestone = "S", Basalt = "B", Rock = "R", Water = "W", Pavement = "P", Mud = "M", Ground = "D", Sand = "A", Sandstone = "N", Cobblestone = "C", Slate = "T", Salt = "X", Asphalt = "Y", Concrete = "Z" }
local buf = {}
for row = ROW_A, ROW_B do
	local v = HALF - row * STEP
	local t = {}
	for u = HALF, -HALF, -STEP do
		local r = workspace:Raycast(Vector3.new(CX + u, 1000, CZ + v), Vector3.new(0, -1100, 0), rp)
		local q = r and math.clamp(math.floor(r.Position.Y * 4 + 0.5), 0, 4095) or 0
		t[#t + 1] = A:sub(q // 64 + 1, q // 64 + 1) .. A:sub(q % 64 + 1, q % 64 + 1) .. (r and (codes[r.Material.Name] or "?") or "_")
	end
	buf[#buf + 1] = table.concat(t)
end
return table.concat(buf, "\n")
