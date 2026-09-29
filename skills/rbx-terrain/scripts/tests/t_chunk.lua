local c = LAB.site(7)
local BOX = LAB.box(7, "chunk", 900)
local CH = { { c.X - 450, c.X, c.Z - 450, c.Z }, { c.X, c.X + 450, c.Z - 450, c.Z }, { c.X - 450, c.X, c.Z, c.Z + 450 }, { c.X, c.X + 450, c.Z, c.Z + 450 } }
local M = K.MAT
return K.run(BOX, { chunks = CH, buffer = 24, feather = 80 }, function(G)
	return {
		K.rolling({ seed = 5 }),
		K.hillField({ rect = { c.X - 320, c.X + 320, c.Z - 320, c.Z + 320 }, grid = 150, h = { 24, 40 }, seed = 9, union = "max", skip = function(u, v, r) return (u - c.X - 30) ^ 2 + (v - c.Z + 20) ^ 2 < (150 + r * 0.6) ^ 2 end }),
		K.bowl({ name = "bowl", x = c.X + 30, z = c.Z - 20, r = 150, depth = 23, lip = 4, floorMat = M.Grass, rimMat = M.Limestone }),
		K.path({ name = "lane", mode = "lane", tag = "lane", pts = { { c.X - 320, c.Z + 230 }, { c.X, c.Z + 200 }, { c.X + 320, c.Z + 240 } }, halfW = 30, bank = 16, depth = 6, floorMat = K.DIRT }),
	}, {}
end)
