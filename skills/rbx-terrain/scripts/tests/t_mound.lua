local SITE = 0
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "mound", 900))
local M = K.MAT
LAB.build(G, {
	K.mound({ name = "big", x = c.X - 110, z = c.Z - 110, r = 180, h = 40 }),
	K.mound({ name = "small", x = c.X + 180, z = c.Z + 150, r = 100, h = 20 }),
	K.mound({ name = "pairA", x = c.X - 170, z = c.Z + 150, r = 120, h = 26 }),
	K.mound({ name = "pairB", x = c.X - 60, z = c.Z + 170, r = 120, h = 26 }),
})
return table.concat(K.out, "\n")
