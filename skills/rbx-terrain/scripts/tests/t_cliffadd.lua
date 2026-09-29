local SITE = 15
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "cliffadd", 900))
local CZ = -120
local cliff = K.cliff({ name = "cliff", pts = { { c.X - 420, c.Z + CZ }, { c.X, c.Z + CZ }, { c.X + 420, c.Z + CZ } }, outside = { c.X, c.Z + 200 }, h = 70, w = 50, rel = 10, ends = 150 })
if VARIANT == "nosteep" then cliff.steep = nil end
LAB.build(G, {
	cliff,
	K.mound({ name = "top a", x = c.X - 120, z = c.Z + 40, r = 90, h = 18, on = cliff }),
	K.mound({ name = "top b", x = c.X + 140, z = c.Z + 60, r = 80, h = 16, on = cliff }),
}, {}, { buffer = 24, feather = 80 })
task.wait(1)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local ang = {}
for _, x in ipairs({ -200, -160, -120, -80, -40, 0, 40, 80, 120, 160 }) do
	local h = workspace:Raycast(Vector3.new(c.X + x, LAB.Y + 35, c.Z + CZ - 90), Vector3.new(0, 0, 200), rp)
	ang[#ang + 1] = h and math.deg(math.acos(math.clamp(math.abs(h.Normal.Y), 0, 1))) or 0
end
table.sort(ang)
local med = (ang[5] + ang[6]) / 2
K.log(string.format("%s additive cliff face 10-ray median %.1f deg (min %.1f max %.1f), want >= 60", med >= 60 and "PASS" or "FAIL", med, ang[1], ang[10]))
return table.concat(K.out, "\n")
