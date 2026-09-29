local SITE = 6
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "paths", 900))
local M = K.MAT
local function P(t) local o = {} for _, p in ipairs(t) do o[#o + 1] = { c.X + p[1], c.Z + p[2] } end return o end
local WZ = 40
LAB.build(G, {
	K.path({ name = "lane", mode = "lane", tag = "lane", pts = P({ { -320, -230 }, { -100, -250 }, { 100, -220 }, { 320, -240 } }), halfW = 52, bank = 16, depth = 8, floorMat = K.DIRT, lipMat = M.Limestone }),
	K.path({ name = "berm", mode = "berm", pts = P({ { -250, -90 }, { 0, -60 }, { 250, -90 } }), halfW = 40, h = 15, crest = M.Limestone, flank = M.LeafyGrass }),
	K.path({ name = "wall", mode = "wall", pts = P({ { -280, WZ }, { 280, WZ } }), halfW = 0, bank = 240, inner = 40, R = 24, ang = 74, h = 34, backDeg = 20, crestR = 12, taper = 140, outside = { c.X, c.Z + WZ + 150 }, base = LAB.Y, face = M.LeafyGrass }),
}, {}, { buffer = 24, feather = 80 })
task.wait(1)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local ang = {}
for k = 1, 12 do
	local x = c.X - 150 + (k - 1) * 27
	local h = workspace:Raycast(Vector3.new(x, LAB.Y + 26, c.Z + WZ), Vector3.new(0, 0, 150), rp)
	ang[#ang + 1] = h and math.deg(math.acos(math.clamp(math.abs(h.Normal.Y), 0, 1))) or 0
end
table.sort(ang)
local med = (ang[6] + ang[7]) / 2
K.log(string.format("%s wall face 12-ray median %.1f deg (min %.1f max %.1f), want >= 66 [movement.md wall = |normal.Y| <= 0.4]", med >= 66 and "PASS" or "FAIL", med, ang[1], ang[12]))
local function top(x, z)
	local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), rp)
	return h and h.Position.Y or 0
end
local back, spikes = 0, 0
for k = -2, 2 do
	local x = c.X + k * 60
	local zc, hc = 0, -1
	for z = WZ + 60, WZ + 140, 2 do local h = top(x, c.Z + z) if h > hc then hc, zc = h, z end end
	for z = zc + 8, WZ + 280, 4 do back = math.max(back, math.deg(math.atan((top(x, c.Z + z) - top(x, c.Z + z + 16)) / 16))) end
end
local crest = {}
for x = -120, 120, 8 do
	local hc = -1
	for z = WZ + 60, WZ + 140, 2 do hc = math.max(hc, top(c.X + x, c.Z + z)) end
	crest[#crest + 1] = hc
end
for k = 2, #crest - 1 do spikes = math.max(spikes, math.abs(crest[k - 1] - 2 * crest[k] + crest[k + 1])) end
K.log(string.format("%s wall back slope max %.1f deg (16-stud), want <= 20 + 0.75 mesh noise [user R5/kit backDeg]", back <= 20.75 and "PASS" or "FAIL", back))
K.log(string.format("%s wall crest spikes: max 2nd difference %.2f stud along crest (8-stud steps), want <= 1 [user R6]", spikes <= 1 and "PASS" or "FAIL", spikes))
return table.concat(K.out, "\n")
