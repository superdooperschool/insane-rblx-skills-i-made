local SITE = 11
local c = LAB.prep(SITE)
local G = K.grid(LAB.box(SITE, "paint", 900))
local M = K.MAT
LAB.build(G, {
	K.rolling({ seed = 11 }),
	K.hillField({ rect = { c.X - 340, c.X + 340, c.Z - 340, c.Z + 340 }, grid = 150, h = { 24, 40 }, seed = 21, union = "max" }),
}, {}, { buffer = 24, feather = 80 })
return table.concat(K.out, "\n")
