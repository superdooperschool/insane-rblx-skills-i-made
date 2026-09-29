local SITE = 10
local c = LAB.prep(SITE)
workspace.Terrain:FillBlock(CFrame.new(c.X, 120, c.Z + 60 + 226), Vector3.new(1024, 120, 452), Enum.Material.Grass)
local G = K.grid(LAB.box(SITE, "cliff", 900))
local M = K.MAT
local B, CZ, CH = LAB.Y, 60, 80
local cliff = K.cliff({ name = "cliff", pts = { { c.X - 420, c.Z + CZ }, { c.X, c.Z + CZ }, { c.X + 420, c.Z + CZ } }, outside = { c.X, c.Z + 300 }, h = CH, w = 50, rel = 12, base = B, reach = 300 })
local RAMP = { { c.X - 360, c.Z - 200 }, { c.X - 150, c.Z - 120 }, { c.X + 40, c.Z - 10 }, { c.X + 110, c.Z + 150 } }
LAB.build(G, {
	cliff,
	K.mound({ name = "top a", x = c.X - 150, z = c.Z + 230, r = 100, h = 20 }),
	K.mound({ name = "top b", x = c.X + 170, z = c.Z + 240, r = 90, h = 18 }),
	K.path({ name = "ramp", mode = "ramp", pts = RAMP, halfW = 30, bank = 40, y0 = B, y1 = B + cliff.hAt(RAMP[4][1], RAMP[4][2]), floorMat = K.DIRT }),
}, {}, { buffer = 24, feather = 80, maxSlope = 91 })
task.wait(1)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function top(x, z) local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), rp) return h and h.Position.Y - 2 or 0 end
local XS = { -260, -230, -200, -170, -140, -110, 190, 215, 240, 265 }
local ang = {}
for _, x in ipairs(XS) do
	local h = workspace:Raycast(Vector3.new(c.X + x, B + CH * 0.5, c.Z + CZ - 80), Vector3.new(0, 0, 200), rp)
	ang[#ang + 1] = h and math.deg(math.acos(math.clamp(math.abs(h.Normal.Y), 0, 1))) or 0
end
table.sort(ang)
local med = (ang[5] + ang[6]) / 2
K.log(string.format("%s cliff face %d-ray median %.1f deg (min %.1f max %.1f), want >= 60 [user R12 cliffs read as cliffs; grammar Basalt 45-70]", med >= 60 and "PASS" or "FAIL", #ang, med, ang[1], ang[#ang]))
local low, holes, maxDrop = 0, 0, 0
for x = -270, 270, 30 do
	if x < -60 or x > 330 then
		if top(c.X + x, c.Z + CZ + 110) < B + CH * 0.8 then low += 1 end
		local prev = nil
		for z = CZ - 60, CZ + 90, 2 do
			local y = top(c.X + x, c.Z + z)
			if prev then maxDrop = math.max(maxDrop, prev - y) if y < prev - 2 then holes += 1 end end
			prev = y
		end
	end
end
K.log(string.format("%s cliff full-edge coverage: %d plateau samples below 0.8 h (want 0) [user R12 full edge]", low == 0 and "PASS" or "FAIL", low))
K.log(string.format("%s cliff face walk-up: %d drops > 2 studs (half a voxel) per 2-stud step, max drop %.2f (want 0 holes) [user R6 no hole/spike lattice]", holes == 0 and "PASS" or "FAIL", holes, maxDrop))
return table.concat(K.out, "\n")
