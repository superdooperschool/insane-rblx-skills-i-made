local SITE = 2
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "ring"))
local M = K.MAT
LAB.build(G, {
	K.ring({ name = "donut", x = c.X - 100, z = c.Z - 100, R = 70, w = 24, h = 6, dish = 3, rim = M.Limestone, dishMat = M.LeafyGrass }),
	K.ring({ name = "docmax", x = c.X + 150, z = c.Z + 150, R = 60, w = 16, h = 8, dish = 4, rim = M.Limestone, dishMat = M.LeafyGrass }),
})
return table.concat(K.out, "\n")
