local SITE = 1
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "bowl", 900))
local M = K.MAT
LAB.build(G, {
	K.bowl({ name = "big", x = c.X - 40, z = c.Z - 40, r = 190, depth = 29, lip = 5, floorMat = M.Grass, rimMat = M.Limestone }),
	K.bowl({ name = "small", x = c.X + 190, z = c.Z + 190, r = 80, depth = 12, floorMat = M.Grass }),
})
return table.concat(K.out, "\n")
